defmodule Storex.Supervisor do
  @moduledoc false

  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(initial_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [initial_arg]
    )
  end

  @doc false
  # The name a store process registers under. It is deliberately a `:via` tuple
  # and not an atom: session ids are unique per connection, so naming processes
  # `:"#{session}_#{store}"` created one permanent atom per session-store pair
  # and eventually exhausted the atom table on a long-running node.
  #
  # Nothing looks a store up by this name — `Storex.Registry` maps to the pid
  # for that. It exists so that starting the same `{session, store}` twice
  # fails with `{:error, {:already_started, pid}}` instead of silently
  # producing a second process.
  def name(session, store) do
    {:via, Registry, {Storex.StoreRegistry, {session, store}}}
  end

  def add_store(store, session, session_pid, params \\ %{}) do
    Storex.Registry.get_store(store, session)
    |> case do
      :undefined ->
        store_server = Module.concat([store, "Server"])

        spec = %{
          id: store_server,
          start: {store_server, :start_link, [[session: session, store: store, params: params]]},
          restart: :transient
        }

        DynamicSupervisor.start_child(__MODULE__, spec)
        |> case do
          {:ok, store_pid, %{key: key}} ->
            Storex.Registry.register_store(store, store_pid, session, session_pid, key)
            {:ok, key}

          {:error, error} ->
            {:error, error}
        end

      {_, _, _, _, key} ->
        {:ok, key}
    end
  end

  def get_store_state(session, store) do
    Storex.Registry.get_store_pid(store, session)
    |> :sys.get_state()
    |> Map.get(:state)
  end

  def mutate_store(session, store, name, data) do
    Storex.Registry.get_store_pid(store, session)
    |> case do
      :undefined ->
        {:error, "Store '#{store}' is not joined in this session."}

      pid ->
        GenServer.call(pid, {name, data})
    end
  end

  def remove_store(session, store) do
    Storex.Registry.get_store_pid(store, session)
    |> GenServer.cast(:session_ended)

    Storex.Registry.unregister_store(store, session)
  end
end
