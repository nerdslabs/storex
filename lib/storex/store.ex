defmodule Storex.Store do
  @moduledoc """
  Behaviour for a Storex store.

  ## Scope

  A store's *scope* decides how many processes — and therefore how many
  independent states — exist for a given store module. It is set on `use`:

  ```elixir
  use Storex.Store                          # same as scope: :session
  use Storex.Store, scope: :session         # one process per connected session
  use Storex.Store, scope: :global          # one process for the whole node
  use Storex.Store, scope: {:key, "room"}   # one process per params["room"] value
  ```

  With the default `:session` scope every connection gets its own store process
  and its own state, which is the behaviour Storex has always had.

  With `:global` or `{:key, _}` several sessions share one process and one
  state. A mutation is applied once, the diff is computed once, and it is sent
  to every session attached to that process — the one that issued the mutation
  gets it as the reply to its own request, the rest receive it as a push.

  Shared scopes change what the callbacks are handed:

  - `init/2` runs **once**, when the first session attaches. It receives that
    session's id and params; the params of every session that attaches later are
    ignored.
  - `mutation/5` receives the id of the session that *issued* the mutation, so a
    shared store can tell its clients apart. The `params` argument is always the
    ones `init/2` ran with.
  - `terminate/3` runs when the **last** session detaches, with the session id
    `init/2` was given.

  `:global` is per node, not per cluster. `Storex.mutate/3` and `Storex.mutate/4`
  broadcast to every node, so a `:global` store still receives a mutation once
  per node, against that node's own copy of the state.
  """

  @doc """
  Called when store session starts.
  """
  @callback init(session_id :: binary(), params :: %{binary() => any()}) ::
              {:ok, state :: any()}
              | {:ok, state :: any(), key :: binary()}
              | {:error, reason :: binary()}

  @callback mutation(
              name :: binary(),
              data :: any(),
              session_id :: binary(),
              params :: %{binary() => any()},
              state :: any()
            ) ::
              {:reply, message :: any(), state :: any()}
              | {:noreply, state :: any()}
              | {:error, state :: any()}
  @doc """
  Called when store session ends.
  """
  @callback terminate(session_id :: binary(), params :: %{binary() => any()}, state :: any()) ::
              any()
  @optional_callbacks terminate: 3

  @doc false
  # Resolves the store module from the name a client sent. All three checks
  # belong together: `Module.safe_concat/1` refuses to create new atoms,
  # `Code.ensure_compiled/1` refuses names that do not resolve to a real module,
  # and the behaviour check refuses modules that are not stores. Dropping any of
  # them lets client input reach arbitrary modules, which is what the SSR path
  # did for as long as it carried its own copy of only the first check.
  def resolve(store) do
    with {:ok, module} <- safe_concat(store),
         {:module, module} <- Code.ensure_compiled(module),
         true <- storex_store?(module) do
      {:ok, module}
    else
      false -> {:error, :not_store}
      _ -> {:error, :not_exists}
    end
  end

  defp safe_concat(store) do
    {:ok, Module.safe_concat([store])}
  rescue
    ArgumentError -> {:error, :not_exists}
  end

  defp storex_store?(module) do
    __MODULE__ in (module.module_info(:attributes)
                   |> Keyword.get_values(:behaviour)
                   |> List.flatten())
  end

  @doc false
  # The identity a store process is registered under. Everything that shares a
  # scope id shares a process, and therefore a state. For the default `:session`
  # scope the id is the session itself, which is why nothing changes for stores
  # that do not opt in.
  def scope_id(module, session, params) do
    scope_id(scope(module), module, session, params)
  end

  defp scope_id(:session, _module, session, _params), do: {:ok, session}

  defp scope_id(:global, _module, _session, _params), do: {:ok, :global}

  defp scope_id({:key, key}, _module, _session, params) when is_map_key(params, key) do
    {:ok, {key, Map.fetch!(params, key)}}
  end

  defp scope_id({:key, key}, module, _session, _params) do
    {:error, "Store #{inspect(module)} is scoped by param #{inspect(key)}, which was not given."}
  end

  @doc false
  # `function_exported?/3` answers `false` for a module that is not loaded yet,
  # so asking it alone silently degrades every store to `:session` scope
  # depending on what the code server happens to hold — the same trap
  # `__terminate__/4` fell into. The fallback is for a module that declares the
  # behaviour by hand instead of through `use Storex.Store`, and so has no
  # `__storex_scope__/0` at all.
  def scope(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__storex_scope__, 0) do
      module.__storex_scope__()
    else
      :session
    end
  end

  @doc false
  def __validate_scope__(:session), do: :session
  def __validate_scope__(:global), do: :global
  def __validate_scope__({:key, key} = scope) when is_binary(key), do: scope

  def __validate_scope__(other) do
    raise ArgumentError,
          "invalid :scope for use Storex.Store — expected :session, :global or {:key, binary}, got: #{inspect(other)}"
  end

  @doc false
  def __init__(store, session, params) do
    apply(store, :init, [session, params])
    |> case do
      {:ok, state} ->
        {:ok, state, nil}

      {:ok, state, key} ->
        {:ok, state, key}

      {:error, reason} ->
        {:error, reason}

      _ ->
        raise "Return value of store init should be {:ok, state}, {:ok, state, key} or {:error, reason}"
    end
  end

  @doc false
  def __mutation__(store, name, data, session, params, state) do
    try do
      apply(store, :mutation, [name, data, session, params, state])
      |> case do
        {:reply, message, result} ->
          {:reply, message, result}

        {:noreply, result} ->
          {:noreply, result}

        {:error, error} ->
          {:error, error}

        _ ->
          {:error,
           "Return value of mutation should be {:reply, message, state}, {:noreply, state} or {:error, error}"}
      end
    rescue
      error in FunctionClauseError ->
        if unmatched_mutation?(error, store) do
          {:error,
           "No mutation matching #{inspect(name)} with data #{inspect(data)} in store #{inspect(store)}"}
        else
          reraise error, __STACKTRACE__
        end
    end
  end

  # Only the store's own `mutation/5` failing to match means "no such mutation".
  # Any other `FunctionClauseError` was raised deeper inside a mutation that did
  # match, and has to keep its original stacktrace.
  defp unmatched_mutation?(%FunctionClauseError{} = error, store) do
    error.module == store and error.function == :mutation and error.arity == 5
  end

  @doc false
  # `function_exported?/3` answers `false` for a module that is not loaded yet,
  # so the callback would be skipped silently. `ensure_loaded?/1` first makes the
  # answer depend on the store, not on what the code server happens to hold.
  def __terminate__(store, session, params, state) do
    if Code.ensure_loaded?(store) and function_exported?(store, :terminate, 3) do
      apply(store, :terminate, [session, params, state])
    end
  end

  defmacro __using__(opts) do
    scope = opts |> Keyword.get(:scope, :session) |> Storex.Store.__validate_scope__()

    quote do
      @behaviour Storex.Store

      @storex_scope unquote(Macro.escape(scope))

      @doc false
      def __storex_scope__, do: @storex_scope

      @before_compile Storex.Store
    end
  end

  defmacro __before_compile__(env) do
    scope = Module.get_attribute(env.module, :storex_scope) || :session

    quote do
      defmodule Server do
        use GenServer

        @store unquote(env.module)

        def init({session, store, init_state, params, key}) do
          {:ok,
           %{
             state: init_state,
             session: session,
             store: store,
             params: params,
             key: key
           }}
        end

        def start_link([], opts) do
          session = Keyword.fetch!(opts, :session)
          store = Keyword.fetch!(opts, :store)
          params = Keyword.fetch!(opts, :params)
          name = Keyword.get(opts, :name) || Storex.Supervisor.name(session, store)

          with {:ok, state, key} <- init_store(session, params),
               {:ok, pid} <-
                 GenServer.start_link(Server, {session, store, state, params, key}, name: name) do
            {:ok, pid, %{session: session, key: key}}
          else
            {:error, reason} -> {:error, reason}
          end
        end

        def handle_cast(:session_ended, state) do
          Storex.Store.__terminate__(@store, state.session, state.params, state.state)

          {:stop, :normal, state}
        end

        def handle_call(:get_state, _, state) do
          {:reply, state.state, state}
        end

        # Asked by `Storex.Supervisor` when a session attaches to a store process
        # that is already running. The key belongs to the `init/2` that started
        # it, and the process is the only place that is guaranteed to hold it —
        # the registry row of the session that started it may not be written yet.
        def handle_call(:get_key, _, state) do
          {:reply, state.key, state}
        end

        # `from_session` is the session that issued the mutation, which is not
        # necessarily the one `init/2` ran with: under a shared scope many
        # sessions call into the same process. It is what `mutation/5` is given,
        # so a shared store can tell its clients apart.
        def handle_call({:mutation, name, data, from_session}, _, state) do
          Storex.Store.__mutation__(@store, name, data, from_session, state.params, state.state)
          |> case do
            {:reply, message, result} ->
              diff = Storex.Diff.check(state.state, result)
              broadcast_diff(diff, from_session, state)
              {:reply, {:ok, message, diff}, Map.put(state, :state, result)}

            {:noreply, result} ->
              diff = Storex.Diff.check(state.state, result)
              broadcast_diff(diff, from_session, state)
              {:reply, {:ok, diff}, Map.put(state, :state, result)}

            {:error, error} ->
              {:reply, {:error, error}, state}
          end
        end

        def handle_call(call, _, _state) do
          raise "Not handled call: #{inspect(call)}"
        end

        unquote(broadcast_diff(scope))

        defp init_store(session, params) do
          Storex.Store.__init__(@store, session, params)
        end
      end
    end
  end

  # Under `:session` scope a store process has exactly one session, so the
  # session that issued the mutation is the only one there is and the reply
  # carries the diff already. Generating the fan-out away rather than branching
  # on the scope at runtime keeps the existing path at zero added cost.
  defp broadcast_diff(:session) do
    quote do
      defp broadcast_diff(_diff, _from_session, _state), do: :ok
    end
  end

  defp broadcast_diff(_shared) do
    quote do
      defp broadcast_diff([], _from_session, _state), do: :ok

      defp broadcast_diff(diff, from_session, state) do
        Storex.Registry.store_sessions(self())
        |> Enum.each(fn
          {^from_session, _session_pid} -> :ok
          {_session, session_pid} -> send(session_pid, {:storex_diff, state.store, diff})
        end)
      end
    end
  end
end
