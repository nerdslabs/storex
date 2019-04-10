defmodule Stex.Registry do
  use GenServer

  @registry :stores_registry

  def start_link do
    Registry.start_link(keys: :duplicate, name: @registry)
    GenServer.start_link(__MODULE__, nil, name: :registry)
  end

  def init(nil) do
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
    Registry.register(@registry, session, {store, pid})
    Process.monitor(pid)
    {:reply, :yes, state}
  end

  def handle_call({:unregister_name, session, store}, _from, state) do
    result = Registry.unregister_match(@registry, session, {store, :_})
    {:reply, result, state}
  end

  def handle_call({:whereis_name, session, store}, _from, state) do
    Registry.match(@registry, session, {store, :_})
    |> case do
      [] -> {:reply, :undefined, state}
      [{_, {_, pid}} | _tail] -> {:reply, pid, state}
    end
  end

  def handle_call({:lookup, session}, _from, state) do
    stores = Registry.lookup(@registry, session)
    |> Enum.map(&elem(&1, 1))

    {:reply, stores, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, _state) do
    IO.inspect("reason: #{inspect reason}")
    # Registry.unregister_match(@registry, "store", {:_, :_, pid})

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
