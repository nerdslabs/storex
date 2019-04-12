defmodule Stex do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Stex.Registries.Sessions, []),
      worker(Stex.Registries.Stores, []),
      supervisor(Stex.Supervisor, [])
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end
