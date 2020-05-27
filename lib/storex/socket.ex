defmodule Storex.Socket do
  @moduledoc """
    Socket connection handler.

    Error codes:
    - 4000: Store is not set.
    - 4001: Store is not defined or can't be compiled.
  """

  @doc false
  def message_handle(%{type: "ping"} = message, state) do
    message =
      Map.put(message, :type, "pong")
      |> Jason.encode!()

    {:reply, {:text, message}, state}
  end

  def message_handle(%{store: nil}, state) do
    {:reply, {:close, 4000, "Store is not set."}, state}
  end

  def message_handle(%{type: "join"} = message, state) do
    Module.concat([message.store])
    |> Code.ensure_compiled()
    |> case do
      {:module, _} ->
        if Storex.Supervisor.has_store(state.session, message.store) == false do
          Storex.Supervisor.add_store(state.session, message.store, message.data)
        end

        store_state = Storex.Supervisor.get_store_state(state.session, message.store)

        message =
          Map.put(message, :data, store_state)
          |> Map.put(:session, state.session)
          |> Jason.encode!()

        {:reply, {:text, message}, state}

      _ ->
        {:reply, {:close, 4001, "Store '#{message.store}' is not defined or can't be compiled."},
         state}
    end
  end

  def message_handle(%{type: "mutation", session: session, store: store} = message, state) do
    Storex.Supervisor.mutate_store(message.session, message.store, message.data.name, message.data.data)
    |> case do
      {:ok, diff} ->
        %{
          type: "mutation",
          session: session,
          store: store,
          diff: diff,
          request: Map.get(message, :request, nil)
        }
      {:ok, reply_message, diff} ->
        %{
          type: "mutation",
          session: session,
          store: store,
          diff: diff,
          message: reply_message,
          request: Map.get(message, :request, nil)
        }
      {:error, error} ->
        %{
          type: "error",
          session: session,
          store: store,
          error: error,
          request: Map.get(message, :request, nil)
        }
    end
    |> Jason.encode!()
    |> (&{:reply, {:text, &1}, state}).()
  end
end
