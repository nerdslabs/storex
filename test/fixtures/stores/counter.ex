defmodule StorexTest.Store.Counter do
  use Storex.Store

  def init(_session, _params) do
    %{
      counter: 0
    }
  end

  def mutation("increase", _data, _session_id, _params, state) do
    counter = state.counter + 1

    {:noreply,
     %{
       counter: counter
     }}
  end

  def mutation("decrease", _data, _session_id, _params, state) do
    counter = state.counter - 1

    {:reply, "decreased",
     %{
       counter: counter
     }}
  end
end
