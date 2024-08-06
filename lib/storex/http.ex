defmodule Storex.HTTP do
  def get_module(module) do
    module
    |> (&Module.concat([&1])).()
    |> Code.ensure_loaded()
    |> case do
      {:module, module} -> {:ok, module}
      {:error, error} -> {:error, error}
    end
  end

  def get_params(encoded_params) do
    encoded_params
    |> URI.decode()
    |> Jason.decode(keys: :atoms)
  end

  def get_state(module, params) do
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
