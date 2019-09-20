defmodule Storex.Registries.Sessions do
  use GenServer

  @registry :storex_sessions_registry

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: @registry)
  end

  def init(nil) do
    :ets.new(@registry, [:set, :protected, :named_table])

    {:ok, %{}}
  end

  def register_name(session, pid) do
    GenServer.call(@registry, {:register_name, session, pid})
  end

  def unregister_name(session) do
    GenServer.call(@registry, {:unregister_name, session})
  end

  def whereis_name(session) do
    GenServer.call(@registry, {:whereis_name, session})
  end

  def lookup(session) do
    GenServer.call(@registry, {:lookup, session})
  end

  def handle_call({:register_name, session, pid}, _from, state) do
    :ets.insert(@registry, {session, pid})
    {:reply, :yes, state}
  end

  def handle_call({:unregister_name, session}, _from, state) do
    result = :ets.delete(@registry, session)
    {:reply, result, state}
  end

  def handle_call({:whereis_name, session}, _from, state) do
    :ets.match(@registry, {session, :"$1"})
    |> case do
      [] -> {:reply, :undefined, state}
      [[pid] | _tail] -> {:reply, pid, state}
    end
  end

  def handle_call({:lookup, session}, _from, state) do
    stores = :ets.lookup(@registry, session)

    {:reply, stores, state}
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
