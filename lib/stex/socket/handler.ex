defmodule Stex.Socket.Handler do
  @behaviour :cowboy_websocket

  alias Stex.Socket

  def init(request, _state) do
    IO.inspect(request)

    session = Nanoid.generate()

    Stex.Registries.Sessions.register_name(session, request.pid)

    {:cowboy_websocket, request, %{session: session, pid: request.pid}}
  end

  def websocket_init(_type, req, _opts) do
    {:ok, req, %{status: "inactive"}}
  end

  def terminate(_reason, _req, %{session: session}) do
    Stex.Registries.Sessions.unregister_name(session)

    Stex.Registries.Stores.lookup(session)
    |> Enum.each(fn {session, store, _} ->
      Stex.Supervisor.remove_store(session, store)
    end)

    :ok
  end

  def terminate(_, _, _) do
    :ok
  end

  def websocket_handle({:binary, frame}, state) do
    try do
      :erlang.binary_to_term(frame)
      |> Socket.message_handle(state)
    rescue
      ArgumentError -> {:reply, {:close, 1007, "Payload is malformed."}, state}
    end
  end

  def websocket_handle({:text, frame}, state) do
    Jason.decode(frame, keys: :atoms)
    |> case do
      {:ok, message} ->
        Socket.message_handle(message, state)

      {:error, _} ->
        {:reply, {:close, 1007, "Payload is malformed."}, state}
    end
  end

  def websocket_info({:mutate, store, mutation, payload}, %{session: session} = state) do
    store_state = Stex.Supervisor.mutate_store(session, store, mutation, payload)

    message = %{
      type: "mutation",
      session: session,
      store: store,
      data: store_state
    } |> Jason.encode!()

    {:reply, {:text, message}, state}
  end

  def websocket_info(_info, state) do
    {:ok, state}
  end
end
