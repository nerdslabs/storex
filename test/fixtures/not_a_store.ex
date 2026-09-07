defmodule StorexTest.NotAStore do
  @moduledoc """
  A plain module that exports `init/2` but does not declare the `Storex.Store`
  behaviour. The SSR path used to resolve and call it.
  """

  def init(_session, _params) do
    raise "init/2 must not be called on a module that is not a Storex.Store"
  end
end
