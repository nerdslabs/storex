defmodule Storex.HTTP do
  def init_store(store, params) do
    with {:store, {:ok, store_module}} <- {:store, store |> get_module()},
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
           error: "Store '#{inspect(store)}' is not defined or can't be compiled."
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

  defp get_module(store) do
    try do
      module = Module.safe_concat([store])
      {:ok, module}
    rescue
      ArgumentError -> {:error, :not_exists}
    end
  end

  defp get_params(params) do
    params
    |> Jason.decode()
  end

  defp get_state(module, params) do
    module
    |> apply(:init, ["SSR", params])
    |> result()
  end

  defp result({:ok, state}) do
    {:ok, state}
  end

  defp result({:ok, state, _}) do
    {:ok, state}
  end

  defp result({:error, error_message}) do
    {:error, error_message}
  end
end
