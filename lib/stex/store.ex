defmodule Stex.Store do
  @callback init(binary(), any()) :: any()
  @callback mutation(binary(), any()) :: any()

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

        def handle_cast(:session_ended, state) do
          {:stop, :normal, state}
        end

        def handle_call(request, _, state) do
          try do
            result = Kernel.apply(@store, :mutation, [request, state])
            {:reply, result, result}
          rescue
            e -> IO.inspect(e)
          end
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
