defmodule StorexTest.Store.Room do
  @moduledoc """
  Scoped by the `"room"` param: every session that joins with the same room
  value shares one process and one state.

  Reports `init/2` and `terminate/3` to the pid found under the `"reporter"`
  param, which is kept out of the state so the state stays JSON encodable.
  """

  use Storex.Store, scope: {:key, "room"}

  def init(session, params) do
    report(params, {:initialized, session})

    {:ok, %{counter: 0, last: nil}}
  end

  def mutation("increase", _data, session, _params, state) do
    {:noreply, %{state | counter: state.counter + 1, last: session}}
  end

  def mutation("noop", _data, _session, _params, state) do
    {:noreply, state}
  end

  def terminate(session, params, state) do
    report(params, {:terminated, session, params, state})
  end

  defp report(params, message) do
    case Map.get(params, "reporter") do
      nil -> :ok
      pid -> send(pid, message)
    end
  end
end
