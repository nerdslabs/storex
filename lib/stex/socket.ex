defmodule Stex.Socket do
  @moduledoc """
    Response codes:
    - 4000: Store is not set.
    - 4001: Store is not defined or can't be compiled.
  """

  def message_handle(%{type: "ping"} = message, state) do
    message = Map.put(message, :type, "pong")
    |> Jason.encode!()
    # |> :erlang.term_to_binary

    # {:reply, {:binary, message}, state}
    {:reply, {:text, message}, state}
  end

  def message_handle(%{store: nil}, state) do
    {:reply, {:close, 4000, "Store is not set."}, state}
  end

  def message_handle(%{type: "join"} = message, state) do
    Module.concat([message.store])
    |> Code.ensure_compiled?()
    |> case do
      true ->
        if Stex.Supervisor.has_store(state.session, message.store) == false do
          Stex.Supervisor.add_store(state.session, message.store, message.data)
        end

        store_state = Stex.Supervisor.get_store(state.session, message.store)

        message =
          Map.put(message, :data, store_state)
          |> Map.put(:session, state.session)
          |> Jason.encode!()
          # |> :erlang.term_to_binary

        # {:reply, {:binary, message}, state}
        {:reply, {:text, message}, state}

      false ->
        {:reply, {:close, 4001, "Store '#{message.store}' is not defined or can't be compiled."},
         state}
    end
  end

  def message_handle(%{type: "mutation", session: session, store: store} = message, state) do
    Stex.Supervisor.mutate_store(message.session, message.store, message.data.name, message.data.data)
    |> case do
      {:ok, store_state} ->
        Map.put(message, :data, store_state)
      {:error, error} ->
        %{
          type: "error",
          session: session,
          store: store,
          error: error,
          request: message.request
        }
    end
    |> Jason.encode!()
    |> (&{:reply, {:text, &1}, state}).()
  end
end
