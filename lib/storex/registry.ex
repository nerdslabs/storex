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

  def register_store(store, store_pid, session, session_pid, key) do
    GenServer.call(@registry, {:register_store, store, store_pid, session, session_pid, key})
  end

  def unregister_store(store, session) do
    GenServer.call(@registry, {:unregister_store, store, session})
  end

  # The table is `:protected`: only the owning process writes, but every process
  # reads. So reads run in the caller. Routing them through this GenServer made
  # it a global serialisation point for the whole library — every mutation does
  # at least one lookup — and the cost scales with the number of connections.
  # Measured, 500 lookups per reader: with 64 concurrent readers, 98.3ms through
  # the GenServer against 16.2ms reading directly; with 256, 335.8ms against
  # 56.2ms. Writes and the `:DOWN` cleanup stay in the process.
  def get_store(store, session) do
    :ets.match_object(@registry, {store, :"$1", session, :_, :_})
    |> case do
      [] -> :undefined
      [object | _tail] -> object
    end
  end

  def get_store_pid(store, session) do
    :ets.match(@registry, {store, :"$1", session, :_, :_})
    |> case do
      [] -> :undefined
      [[pid] | _tail] -> pid
    end
  end

  def get_store_instances(query) do
    :ets.match_object(@registry, query)
  end

  def session_stores(session) do
    :ets.match_object(@registry, {:_, :_, session, :_, :_})
  end

  # Every session attached to one store process, as `{session, session_pid}`.
  # Under the default `:session` scope that is always a single row; under a
  # shared scope it is the fan-out list for a diff, and the reference count that
  # decides when the process stops.
  def store_sessions(store_pid) do
    :ets.match(@registry, {:_, store_pid, :"$1", :"$2", :_})
    |> Enum.map(fn [session, session_pid] -> {session, session_pid} end)
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

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    :ets.match_delete(@registry, {:_, pid, :_, :_, :_})

    {:noreply, state}
  end
end
