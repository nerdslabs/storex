defmodule StexTest.Store.Counter do
  use Stex.Store

  def init(_session, _params) do
    %{
      counter: 0
    }
  end

  def mutation("increase", _data, _session_id, _params, state) do
    counter = state.counter + 1

    {:ok, %{
      counter: counter
    }}
  end

end
