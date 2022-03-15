defmodule Storex.Registry.ETS do
  @behaviour Storex.Registry

  use GenServer

  @registry :storex_registry

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: @registry)
  end

  def init(nil) do
    :ets.new(@registry, [:bag, :protected, :named_table])

    {:ok, %{}}
  end

  def register_session(session, pid) do
    GenServer.call(@registry, {:register_session, session, pid})
  end

  def unregister_session(session) do
    GenServer.call(@registry, {:unregister_session, session})
  end

  def session_pid(session) do
    GenServer.call(@registry, {:session_pid, session})
  end

  def register_store(session, store, pid) do
    GenServer.call(@registry, {:register_store, session, store, pid})
  end

  def unregister_store(session, store) do
    GenServer.call(@registry, {:unregister_store, session, store})
  end

  def get_store_pid(session, store) do
    GenServer.call(@registry, {:get_store_pid, session, store})
  end

  def session_stores(session) do
    GenServer.call(@registry, {:session_stores, session})
  end

  def handle_call({:register_session, session, pid}, _from, state) do
    :ets.insert(@registry, {session, nil, pid})
    {:reply, {:ok, pid}, state}
  end

  def handle_call({:unregister_session, session}, _from, state) do
    result = :ets.delete(@registry, session)
    {:reply, result, state}
  end

  def handle_call({:session_pid, session}, _from, state) do
    :ets.match(@registry, {session, nil, :"$1"})
    |> case do
      [] -> {:reply, :undefined, state}
      [[pid] | _tail] -> {:reply, pid, state}
    end
  end

  def handle_call({:register_store, session, store, pid}, _from, state) do
    :ets.insert(@registry, {session, store, pid})
    Process.monitor(pid)
    {:reply, {:ok, pid}, state}
  end

  def handle_call({:unregister_store, session, store}, _from, state) do
    result = :ets.match_delete(@registry, {session, store, :_})
    {:reply, result, state}
  end

  def handle_call({:get_store_pid, session, store}, _from, state) do
    :ets.match(@registry, {session, store, :"$1"})
    |> case do
      [] -> {:reply, :undefined, state}
      [[pid] | _tail] -> {:reply, pid, state}
    end
  end

  def handle_call({:session_stores, session}, _from, state) do
    stores = :ets.lookup(@registry, session)

    {:reply, stores, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, _state) do
    :ets.match_delete(@registry, {:_, :_, pid})

    {:noreply, :ok}
  end
end
