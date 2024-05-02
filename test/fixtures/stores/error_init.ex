defmodule StorexTest.Store.ErrorInit do
  use Storex.Store

  def init(_session, _params) do
    {:error, "Unauthorized"}
  end

  def mutation(_mutation, _data, _session_id, _params, state) do
    {:noreply, state}
  end
end
