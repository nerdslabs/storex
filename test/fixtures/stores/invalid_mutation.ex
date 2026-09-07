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
end
