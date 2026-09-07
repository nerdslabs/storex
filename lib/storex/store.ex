defmodule Storex.Store do
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

  defmacro __using__(_opts) do
    quote do
      @behaviour Storex.Store

      @before_compile Storex.Store
    end
  end

  defmacro __before_compile__(env) do
    quote do
      defmodule Server do
        use GenServer

        @store unquote(env.module)

        def init({session, init_state, params}) do
          {:ok,
           %{
             state: init_state,
             session: session,
             params: params
           }}
        end

        def start_link([], session: session, store: store, params: params) do
          opts = [name: Storex.Supervisor.name(session, store)]

          with {:ok, state, key} <- init_store(session, params),
               {:ok, pid} <- GenServer.start_link(Server, {session, state, params}, opts) do
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

        def handle_call({name, data}, _, state) do
          Storex.Store.__mutation__(@store, name, data, state.session, state.params, state.state)
          |> case do
            {:reply, message, result} ->
              diff = Storex.Diff.check(state.state, result)
              state = Map.put(state, :state, result)
              {:reply, {:ok, message, diff}, state}

            {:noreply, result} ->
              diff = Storex.Diff.check(state.state, result)
              state = Map.put(state, :state, result)
              {:reply, {:ok, diff}, state}

            {:error, error} ->
              {:reply, {:error, error}, state}
          end
        end

        def handle_call(call, _, _state) do
          raise "Not handled call: #{inspect(call)}"
        end

        defp init_store(session, params) do
          Storex.Store.__init__(@store, session, params)
        end
      end
    end
  end
end
