defmodule Stex.Socket.Handler do
  @behaviour :cowboy_websocket

  alias Stex.Socket

  def init(request, _state) do
    IO.inspect(request)

    {:cowboy_websocket, request, %{session: Nanoid.generate(), pid: request.pid}}
  end

  def websocket_init(_type, req, _opts) do
    {:ok, req, %{status: "inactive"}}
  end

  def terminate(_reason, _req, %{session: session}) do
    Stex.Registry.lookup(session)
    |> Enum.each(fn {store, _} ->
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

  def websocket_info({:send, []}, state) do
    # IO.inspect(info)
    IO.inspect(state)

    # {:reply, {:text, "Hehe"}, state}
    {:ok, state}
  end

  def websocket_info(_info, state) do
    {:ok, state}
  end
end
