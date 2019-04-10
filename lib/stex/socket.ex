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

        Stex.Supervisor.get_store(state.session, message.store)

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

  def message_handle(%{type: "mutation"} = message, state) do
    store_state =
      Stex.Supervisor.mutate_store(
        message.session,
        message.store,
        message.data.type,
        message.data.data
      )

    message = Map.put(message, :data, store_state)
    |> Jason.encode!()
    # |> :erlang.term_to_binary

    # {:reply, {:binary, message}, state}
    {:reply, {:text, message}, state}
  end
end
