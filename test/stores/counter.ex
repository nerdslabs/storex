defmodule StexTest.Store.Counter do
  use Stex.Store

  def init(_session, _params) do
    %{
      counter: 0
    }
  end

  def mutation("increase", _params, state) do
    counter = state.counter + 1

    %{
      counter: counter
    }
  end

end
