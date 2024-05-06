defmodule Storex.Handler.Cowboy do
  @moduledoc false

  alias Storex.Socket

  def init(request, _state) do
    session = Application.get_env(:storex, :session_id_library, Nanoid).generate()

    {:cowboy_websocket, request, %{session: session, pid: request.pid}}
  end

  def websocket_init(_type, req, _opts) do
    {:ok, req, %{status: "inactive"}}
  end

  def terminate(_reason, _req, %{session: session}) do
    Storex.Registry.session_stores(session)
    |> Enum.each(fn {store, _, session, _, _} ->
      Storex.Supervisor.remove_store(session, store)
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
      |> map_response()
    rescue
      ArgumentError -> {:reply, {:close, 1007, "Payload is malformed."}, state}
    end
  end

  def websocket_handle({:text, frame}, state) do
    Jason.decode(frame, keys: :atoms)
    |> case do
      {:ok, message} ->
        Socket.message_handle(message, state)
        |> map_response()

      {:error, _} ->
        {:reply, {:close, 1007, "Payload is malformed."}, state}
    end
  end

  def websocket_info({:mutate, store, mutation, data}, %{session: session} = state) do
    %{
      type: "mutation",
      session: session,
      store: store,
      data: %{
        data: data,
        name: mutation
      }
    }
    |> Socket.message_handle(state)
    |> map_response()
  end

  def websocket_info(_info, state) do
    {:ok, state}
  end

  defp map_response({:text, message, state}) do
    {:reply, {:text, message}, state}
  end

  defp map_response({:close, code, message, state}) do
    {:reply, {:close, code, message}, state}
  end
end
