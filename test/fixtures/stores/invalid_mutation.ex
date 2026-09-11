defmodule StorexTest.Store.InvalidMutation do
  use Storex.Store

  def init(_session, _params) do
    {:ok, %{counter: 0}}
  end

  def mutation("invalid", _data, _session_id, _params, _state) do
    :not_a_valid_return
  end

  def mutation("error", _data, _session_id, _params, _state) do
    {:error, "Not allowed"}
  end

  # Matches, then raises a FunctionClauseError of its own from further down.
  def mutation("raise", data, _session_id, _params, _state) do
    {:noreply, %{counter: only_zero(data)}}
  end

  defp only_zero(0), do: 0
end
