defmodule StorexTest.Store.KeyInit do
  use Storex.Store

  def init(_session, _params) do
    {:ok,
     %{
       counter: 0
     }, "user_id"}
  end

  def mutation("set", [value], _session_id, _params, _state) do
    counter = value

    {:reply, "decreased",
     %{
       counter: counter
     }}
  end
end
