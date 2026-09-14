defmodule StorexTest.Store.Shared do
  @moduledoc """
  A `:global` store — one process, one state, for the whole node.
  """

  use Storex.Store, scope: :global

  def init(_session, _params) do
    {:ok, %{counter: 0}}
  end

  def mutation("increase", _data, _session, _params, state) do
    {:noreply, %{state | counter: state.counter + 1}}
  end
end
