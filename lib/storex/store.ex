defmodule Storex.Store do
  @doc """
  Called when store session starts.
  """
  @callback init(session_id :: binary(), params :: any()) :: any()
  @callback mutation(
              name :: binary(),
              data :: any(),
              session_id :: binary(),
              params :: any(),
              state :: any()
            ) ::
              {:reply, message :: any(), state :: any()}
              | {:noreply, state :: any()}
              | {:error, state :: any()}
  @doc """
  Called when store session ends.
  """
  @callback terminate(session_id :: binary(), params :: any(), state :: any()) :: any()
  @optional_callbacks terminate: 3

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

        def init({params, session}) do
          init_state = @store.init(session, params)

          {:ok,
           %{
             state: init_state,
             session: session,
             params: params
           }}
        end

        def start_link([], session: session, store: store, params: params) do
          GenServer.start_link(Server, {params, session},
            name: Storex.Supervisor.name(session, store)
          )
        end

        def handle_cast(:session_ended, state) do
          if :erlang.function_exported(@store, :terminate, 3) do
            Kernel.apply(@store, :terminate, [state.session, state.params, state.state])
          end

          {:stop, :normal, state}
        end

        def handle_call({name, data}, _, state) do
          try do
            Kernel.apply(@store, :mutation, [name, data, state.session, state.params, state.state])
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

              _ ->
                {:reply,
                 {:error,
                  "Return value of mutation should be {:reply, message, state}, {:noreply, state} or {:error, error}"},
                 state}
            end
          rescue
            e in FunctionClauseError ->
              {:reply,
               {:error,
                "No mutation matching #{inspect(name)} with data #{inspect(data)} in store #{inspect(@store)}"},
               state}
          end
        end

        def handle_call(call, _, _state) do
          raise "Not handled call: #{inspect(call)}"
        end
      end
    end
  end
end
