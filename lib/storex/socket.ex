defmodule Storex.Socket do
  @moduledoc """
    Socket connection handler.

    Error codes:
    - `4000`: Store is not set.
    - `4001`: Store is not defined or can't be compiled.
  """

  @doc false
  def message_handle(%{type: "ping"} = message, state) do
    message =
      Map.put(message, :type, "pong")
      |> Jason.encode!()

    {:text, message, state}
  end

  def message_handle(%{store: nil}, state) do
    {:close, 4000, "Store is not set.", state}
  end

  def message_handle(%{type: "join"} = message, state) do
    with {:get_module, {:ok, _}} <- {:get_module, get_store_module(message.store)},
         {:add_store, {:ok, _}} <-
           {:add_store,
            Storex.Supervisor.add_store(message.store, state.session, state.pid, message.data)} do
      store_state = Storex.Supervisor.get_store_state(state.session, message.store)

      message =
        Map.put(message, :data, store_state)
        |> Map.put(:session, state.session)
        |> Jason.encode!()

      {:text, message, state}
    else
      {:add_store, {:error, error_message}} ->
        %{
          type: "error",
          session: state.session,
          store: message.store,
          error: error_message,
          request: Map.get(message, :request, nil)
        }
        |> Jason.encode!()
        |> (&{:text, &1, state}).()

      _ ->
        {:close, 4001, "Store '#{message.store}' is not defined or can't be compiled.", state}
    end
  end

  def message_handle(%{type: "mutation", session: session, store: store} = message, state) do
    Storex.Supervisor.mutate_store(
      message.session,
      message.store,
      message.data.name,
      message.data.data
    )
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
    |> (&{:text, &1, state}).()
  end

  defp safe_concat(store) do
    try do
      module = Module.safe_concat([store])
      {:ok, module}
    rescue
      ArgumentError -> {:error, :not_exists}
    end
  end

  defp get_store_module(store) do
    with {:ok, module} <- safe_concat(store),
         {:module, module} <- Code.ensure_compiled(module),
         true <-
           Storex.Store in (module.module_info(:attributes)
                            |> Keyword.get_values(:behaviour)
                            |> List.flatten()) do
      {:ok, module}
    else
      false -> {:error, :not_store}
      _ -> {:error, :not_exists}
    end
  end
end
