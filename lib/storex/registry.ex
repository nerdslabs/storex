defmodule Storex.Registry do
  @moduledoc false

  use GenServer

  @registry :storex_registry

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: @registry)
  end

  def init(nil) do
    :ets.new(@registry, [:bag, :protected, :named_table])

    {:ok, %{}}
  end

  def session_pid(session) do
    GenServer.call(@registry, {:session_pid, session})
  end

  def register_store(store, store_pid, session, session_pid, key) do
    GenServer.call(@registry, {:register_store, store, store_pid, session, session_pid, key})
  end

  def unregister_store(store, session) do
    GenServer.call(@registry, {:unregister_store, store, session})
  end

  def get_store(store, session) do
    GenServer.call(@registry, {:get_store, store, session})
  end

  def get_store_pid(store, session) do
    GenServer.call(@registry, {:get_store_pid, store, session})
  end

  def get_store_instances(query) do
    GenServer.call(@registry, {:get_store_instances, query})
  end

  def session_stores(session) do
    GenServer.call(@registry, {:session_stores, session})
  end

  def handle_call({:session_pid, session}, _from, state) do
    :ets.match(@registry, {:_, session, :_, :"$1"})
    |> case do
      [] -> {:reply, :undefined, state}
      [[pid] | _tail] -> {:reply, pid, state}
    end
  end

  def handle_call({:register_store, store, store_pid, session, session_pid, key}, _from, state) do
    :ets.insert(@registry, {store, store_pid, session, session_pid, key})
    Process.monitor(store_pid)
    {:reply, {:ok, store_pid}, state}
  end

  def handle_call({:unregister_store, store, session}, _from, state) do
    result = :ets.match_delete(@registry, {store, :_, session, :_, :_})
    {:reply, result, state}
  end

  def handle_call({:get_store, store, session}, _from, state) do
    :ets.match_object(@registry, {store, :"$1", session, :_, :_})
    |> case do
      [] -> {:reply, :undefined, state}
      [object | _tail] -> {:reply, object, state}
    end
  end

  def handle_call({:get_store_pid, store, session}, _from, state) do
    :ets.match(@registry, {store, :"$1", session, :_, :_})
    |> case do
      [] -> {:reply, :undefined, state}
      [[pid] | _tail] -> {:reply, pid, state}
    end
  end

  def handle_call({:get_store_instances, query}, _from, state) do
    instances = :ets.match_object(@registry, query)

    {:reply, instances, state}
  end

  def handle_call({:session_stores, session}, _from, state) do
    stores = :ets.match_object(@registry, {:_, :_, session, :_, :_})

    {:reply, stores, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, _state) do
    :ets.match_delete(@registry, {:_, :_, pid})

    {:noreply, :ok}
  end
end
