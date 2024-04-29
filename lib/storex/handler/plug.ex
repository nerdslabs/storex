defmodule Storex.Handler.Plug do
  @moduledoc false

  alias Storex.Socket

  def init(_) do
    session = Application.get_env(:storex, :session_id_library, Nanoid).generate()
    pid = self()

    Storex.Registry.register_session(session, pid)

    {:ok, %{session: session, pid: pid}}
  end

  def terminate(_reason, %{session: session}) do
    Storex.Registry.session_stores(session)
    |> Enum.each(fn {session, store, _} ->
      Storex.Supervisor.remove_store(session, store)
    end)

    Storex.Registry.unregister_session(session)

    :ok
  end

  def terminate(_, _) do
    :ok
  end

  def handle_in({message, [opcode: :text]}, state) do
    Jason.decode(message, keys: :atoms)
    |> case do
      {:ok, message} ->
        Socket.message_handle(message, state)
        |> map_response()

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
