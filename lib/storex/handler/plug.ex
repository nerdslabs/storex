defmodule Storex.Handler.Plug do
  @moduledoc false

  alias Storex.Socket

  def init(_) do
    session = Application.get_env(:storex, :session_id_library, Nanoid).generate()
    pid = self()

    {:ok, %{session: session, pid: pid}}
  end

  def terminate(_reason, %{session: session}) do
    Storex.Registry.session_stores(session)
    |> Enum.each(fn {store, _, session, _, _} ->
      Storex.Supervisor.remove_store(session, store)
    end)

    :ok
  end

  def terminate(_, _) do
    :ok
  end

  def handle_in({message, [opcode: :text]}, state) do
    with {:ok, decoded_message} <- Jason.decode(message),
         {:ok, cast_message} <- Storex.Message.cast(decoded_message) do
      Socket.message_handle(cast_message, state)
      |> map_response()
    else
      {:error, _} ->
        {:stop, "Payload is malformed.", 1007, state}
    end
  end

  def handle_info({:mutate, store, mutation, data}, %{session: session} = state) do
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

  def handle_info(_info, state) do
    {:ok, state}
  end

  defp map_response({:text, message, state}) do
    {:push, {:text, message}, state}
  end

  defp map_response({:close, code, message, state}) do
    {:stop, :normal, {code, message}, state}
  end
end
