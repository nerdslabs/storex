defmodule Stex.Supervisor do
  use DynamicSupervisor

  def start_link() do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(initial_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [initial_arg]
    )
  end

  def via_tuple(session, store) do
    {:via, Stex.Registries.Stores, {session, store}}
  end

  def has_store(session, store) do
    Stex.Registries.Stores.whereis_name({session, store})
    |> case do
      :undefined -> false
      _ -> true
    end
  end

  def add_store(session, store, params \\ %{}) do
    store_server = Module.concat([store, "Server"])
    spec = {store_server, [session: session, store: store, params: params]}
    # TODO: If server not start error is not raised!
    DynamicSupervisor.start_child(__MODULE__, spec)
    |> case do
      {:error, error} -> IO.warn(error)
      result -> result
    end
  end

  def get_store(session, store) do
    Stex.Registries.Stores.whereis_name({session, store})
    |> :sys.get_state()
  end

  def mutate_store(session, store, name, data) do
    GenServer.call(via_tuple(session, store), {name, data})
  end

  def remove_store(session, store) do
    GenServer.cast(via_tuple(session, store), :session_ended)
  end
end
