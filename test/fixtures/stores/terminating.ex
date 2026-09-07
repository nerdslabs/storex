defmodule StorexTest.Store.Terminating do
  @moduledoc """
  Implements the optional `terminate/3` callback and reports it to the pid found
  under the `"reporter"` param. The pid is kept out of the state so the state
  stays JSON encodable.
  """

  use Storex.Store

  def init(_session, _params) do
    {:ok, %{counter: 0}}
  end

  def mutation("increase", _data, _session_id, _params, state) do
    {:noreply, %{state | counter: state.counter + 1}}
  end

  def terminate(session, params, state) do
    case Map.get(params, "reporter") do
      nil -> :ok
      pid -> send(pid, {:terminated, session, params, state})
    end
  end
end
