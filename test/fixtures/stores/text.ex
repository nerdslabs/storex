defmodule StorexTest.Store.Text do
  use Storex.Store

  def init(_session, _params) do
    "abc"
  end

  def mutation("change", [value], _session_id, _params, _state) do
    {:noreply, value}
  end
end
