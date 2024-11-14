defmodule StorexTest.Store.Text do
  use Storex.Store

  def init(_session, params) do
    initial_value = Map.get(params, "initial_value", "abc")

    {:ok, initial_value}
  end

  def mutation("change", [value], _session_id, _params, _state) do
    {:noreply, value}
  end
end
