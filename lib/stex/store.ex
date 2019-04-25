defmodule Stex.Store do
  @doc """
  Called when store session starts.
  """
  @callback init(session_id :: binary(), params :: any()) :: any()
  @callback mutation(name :: binary(), data :: any(), state :: any()) :: any()
  @doc """
  Called when store session ends.
  """
  @callback terminate(session_id :: binary(), state :: any()) :: any()
  @optional_callbacks terminate: 2

  defmacro __using__(_opts) do
    quote do
      @behaviour Stex.Store

      @before_compile Stex.Store
    end
  end

  defmacro __before_compile__(env) do
    quote do
      defmodule Server do
        use GenServer

        @store unquote(env.module)

        def init({params, session}) do
          {:ok, @store.init(session, params)}
        end

        def start_link([], session: session, store: store, params: params) do
          GenServer.start_link(Server, {params, session}, name: Stex.Supervisor.via_tuple(session, store))
        end

        def handle_cast({:session_ended, session}, state) do
          if :erlang.function_exported(@store, :terminate, 2) do
            Kernel.apply(@store, :terminate, [session, state])
          end

          {:stop, :normal, state}
        end

        def handle_call({name, data}, _, state) do
          try do
            result = Kernel.apply(@store, :mutation, [name, data, state])
            {:reply, {:ok, result}, result}
          rescue
            e ->
              {:reply, {:error, "No mutation matching #{inspect name} with data #{inspect data} in store #{inspect @store}"}, state}
          end
        end

        def handle_call(call, _, state) do
          raise "Not handled call: #{inspect call}"
        end

        def child_spec(opts) do
          %{
            id: Server,
            start: {Server, :start_link, [opts]},
            restart: :transient
          }
        end
      end
    end
  end
end
