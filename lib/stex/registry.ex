defmodule Stex.Registry do
  use GenServer

  @registry :stores_registry

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: :registry)
  end

  def init(nil) do
    :ets.new(@registry, [:bag, :protected, :named_table])

    {:ok, %{}}
  end

  def register_name({session, store}, pid) do
    GenServer.call(:registry, {:register_name, session, store, pid})
  end

  def unregister_name({session, store}) do
    GenServer.call(:registry, {:unregister_name, session, store})
  end

  def whereis_name({session, store}) do
    GenServer.call(:registry, {:whereis_name, session, store})
  end

  def lookup(session) do
    GenServer.call(:registry, {:lookup, session})
  end

  def handle_call({:register_name, session, store, pid}, _from, state) do
    :ets.insert(@registry, {session, store, pid})
    Process.monitor(pid)
    {:reply, :yes, state}
  end

  def handle_call({:unregister_name, session, store}, _from, state) do
    result = :ets.match_delete(@registry, {session, store, :_})
    {:reply, result, state}
  end

  def handle_call({:whereis_name, session, store}, _from, state) do
    :ets.match(@registry, {session, store, :"$1"})
    |> case do
      [] -> {:reply, :undefined, state}
      [[pid] | _tail] -> {:reply, pid, state}
    end
  end

  def handle_call({:lookup, session}, _from, state) do
    stores = :ets.lookup(@registry, session)

    {:reply, stores, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, _state) do
    :ets.match_delete(@registry, {:_, :_, pid})

    {:noreply, :ok}
  end

  def send(tuple, message) do
    case whereis_name(tuple) do
      :undefined ->
        {:badarg, {tuple, message}}

      pid ->
        Kernel.send(pid, message)
        pid
    end
  end
end
