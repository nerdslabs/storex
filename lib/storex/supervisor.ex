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
  # The first element is the store's *scope id* (`Storex.Store.scope_id/3`), not
  # the session — for the default `:session` scope the two are the same value,
  # which is why nothing changes for stores that do not opt into a shared scope.
  # Sessions sharing a scope id resolve to the same name, and therefore to one
  # process and one state.
  def name(scope, store) do
    {:via, Registry, {Storex.StoreRegistry, {scope, store}}}
  end

  def add_store(store, session, session_pid, params \\ %{}) do
    Storex.Registry.get_store(store, session)
    |> case do
      {_, _, _, _, key} ->
        {:ok, key}

      :undefined ->
        with {:ok, module} <- resolve(store),
             {:ok, scope} <- Storex.Store.scope_id(module, session, params),
             {:ok, store_pid, key} <- start_or_attach(module, store, scope, session, params) do
          Storex.Registry.register_store(store, store_pid, session, session_pid, key)
          {:ok, key}
        end
    end
  end

  defp resolve(store) do
    Storex.Store.resolve(store)
    |> case do
      {:ok, module} -> {:ok, module}
      {:error, _} -> {:error, "Store '#{store}' is not defined or can't be compiled."}
    end
  end

  # A store process that is already running under this scope is attached to
  # rather than started again. Looking the name up before starting matters for
  # shared scopes: relying on `{:error, {:already_started, _}}` alone would run
  # the user's `init/2`, side effects included, and then throw the result away.
  # The lookup narrows that to a genuine race between two sessions attaching at
  # the same moment, which the `:already_started` branch still covers.
  defp start_or_attach(module, store, scope, session, params) do
    Registry.lookup(Storex.StoreRegistry, {scope, store})
    |> case do
      [{store_pid, _}] -> attach(store_pid)
      [] -> start(module, store, scope, session, params)
    end
  end

  defp start(module, store, scope, session, params) do
    server = Module.concat(module, Server)

    spec = %{
      id: server,
      start:
        {server, :start_link,
         [[session: session, store: store, params: params, name: name(scope, store)]]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
    |> case do
      {:ok, store_pid, %{key: key}} -> {:ok, store_pid, key}
      {:error, {:already_started, store_pid}} -> attach(store_pid)
      {:error, error} -> {:error, error}
    end
  end

  defp attach(store_pid) do
    {:ok, store_pid, GenServer.call(store_pid, :get_key)}
  end

  # `:sys.get_state/1` is a debug function, and using it here meant reading the
  # generated `Server`'s internal state shape from the outside, on the join path.
  # The process answers for its own state instead.
  def get_store_state(session, store) do
    Storex.Registry.get_store_pid(store, session)
    |> case do
      :undefined ->
        {:error, "Store '#{store}' is not joined in this session."}

      pid ->
        {:ok, GenServer.call(pid, :get_state)}
    end
  end

  def mutate_store(session, store, name, data) do
    Storex.Registry.get_store_pid(store, session)
    |> case do
      :undefined ->
        {:error, "Store '#{store}' is not joined in this session."}

      pid ->
        GenServer.call(pid, {:mutation, name, data, session})
    end
  end

  # Under a shared scope the store process outlives the session that leaves, so
  # it is stopped only once the registry holds no session for it any more. The
  # row goes first: counting before the delete would always find this session.
  def remove_store(session, store) do
    store_pid = Storex.Registry.get_store_pid(store, session)
    Storex.Registry.unregister_store(store, session)

    case store_pid do
      :undefined ->
        :ok

      pid ->
        if Storex.Registry.store_sessions(pid) == [] do
          GenServer.cast(pid, :session_ended)
        else
          :ok
        end
    end
  end
end
