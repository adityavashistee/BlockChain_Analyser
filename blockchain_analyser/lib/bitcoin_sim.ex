defmodule BitcoinSim do
  @token_amount 1
  use GenServer

  def populate_wallet(wallets, i, limit) when i > limit do
    wallets
  end

  def populate_wallet(wallets, i, limit) when i <= limit do
    wallets = Map.put(wallets, Peer.get_node_name(i), Wallet.new_wallet(%Wallet{}))
    populate_wallet(wallets, i + 1, limit)
  end

  def get_from_and_to(n) do
    from = Enum.random(1..n)
    to = Enum.random(1..n)

    if from == to do
      get_from_and_to(n)
    else
      {from, to}
    end
  end

  def balance_map_populator(bal_map, i, limit) when i > limit do
    bal_map
  end

  def balance_map_populator(bal_map, i, limit) when i <= limit do
    bal_map =
      Map.put(
        bal_map,
        Peer.get_node_name_string(i),
        GenServer.call(Peer.get_node_name(i), {:balance})
      )

    balance_map_populator(bal_map, i + 1, limit)
  end

  def handle_call({:get_balances}, _from, [num_nodes, num_transactions, times]) do
    {:reply, balance_map_populator(%{}, 1, num_nodes), [num_nodes, num_transactions, times]}
  end

  def handle_cast({:initiate}, [num_nodes, num_transactions, times]) do
    for i <- 1..num_nodes do
      GenServer.cast(Peer.get_node_name(i), {:initial_buy})
    end

    # IO.puts("Going to sleep")
    Process.sleep(5000)
    # IO.puts("Waking Up from sleep")
    for i <- 1..num_transactions do
      {from, to} = get_from_and_to(num_nodes)
      IO.puts("Transacting from = #{Peer.get_node_name(from)} to = #{Peer.get_node_name(to)}")
      GenServer.cast(Peer.get_node_name(from), {:send, to, @token_amount})
      # Process.sleep(1000)
    end

    # Process.sleep(5000)
    {:noreply, [num_nodes, num_transactions, times]}
  end

  def handle_cast({:transact}, [num_nodes, num_transactions, times]) do
    for i <- 1..Enum.random(10..30) do
      {from, to} = get_from_and_to(num_nodes)
      IO.puts("Transacting from = #{Peer.get_node_name(from)} to = #{Peer.get_node_name(to)}")
      GenServer.cast(Peer.get_node_name(from), {:send, to, @token_amount})
      # Process.sleep(1000)
    end

    # Process.sleep(5000)
    {:noreply, [num_nodes, num_transactions, times]}
  end

  def handle_call({:get_trans_time}, _from, [num_nodes, num_transactions, times]) do
    {:reply, times, [num_nodes, num_transactions, times]}
  end

  def handle_cast({:trans_time, ts}, [num_nodes, num_transactions, times]) do
    {:noreply, [num_nodes, num_transactions, times ++ [ts]]}
  end

  def init([num_nodes, num_transactions]) do
    wallets = populate_wallet(%{}, 1, num_nodes)
    wallets = Map.put(wallets, :coinbase, Wallet.new_wallet(%Wallet{}))
    coinbase = Map.get(Map.get(wallets, :coinbase), :public_key)

    genesis =
      Block.create_block(
        [Transaction.new_coinbase_tx(%Transaction{}, coinbase, @genesisCoinbaseData)],
        "Genesis"
      )

    for i <- 1..num_nodes do
      GenServer.start_link(Peer, [i, genesis, wallets, num_nodes], name: Peer.get_node_name(i))
    end

    {:ok, [num_nodes, num_transactions, []]}
    # for i <- 1..num_nodes do
    #   GenServer.cast(Peer.get_node_name(i), {:initial_buy})
    # end
  end
end
