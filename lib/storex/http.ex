defmodule Storex.HTTP do
  def init_store(store, params) do
    with {:store, {:ok, store_module}} <- {:store, Storex.Store.resolve(store)},
         {:params, {:ok, params}} <- {:params, params |> get_params()},
         {:state, {:ok, result}} <- {:state, get_state(store_module, params)} do
      {:ok,
       %{
         type: "join",
         session: "SSR",
         store: store,
         data: result
       }}
    else
      {:store, {:error, _}} ->
        {:error,
         %{
           type: "error",
           session: "SSR",
           store: store,
           error: "Store '#{store}' is not defined or can't be compiled."
         }}

      {:state, {:error, message}} ->
        {:error,
         %{
           type: "error",
           session: "SSR",
           store: store,
           error: message
         }}

      _ ->
        {:error,
         %{
           type: "error",
           session: "SSR",
           store: store,
           error: "Unknown error"
         }}
    end
  end

  defp get_params(params) do
    params
    |> Jason.decode()
  end

  # The SSR path is init-only, so the key a store may return is dropped. Using
  # the shared dispatcher keeps the accepted return values, and the error raised
  # for anything else, identical to the websocket path.
  defp get_state(module, params) do
    module
    |> Storex.Store.__init__("SSR", params)
    |> case do
      {:ok, state, _key} -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end
end
