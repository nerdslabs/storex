defmodule StorexTest.Store.InvalidInit do
  use Storex.Store

  def init(_session, _params) do
    :not_a_valid_return
  end

  def mutation(_mutation, _data, _session_id, _params, state) do
    {:noreply, state}
  end
end
