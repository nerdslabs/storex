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

  def mutate(session, store, mutation, payload \\ []) do
    Stex.Registries.Sessions.whereis_name(session)
    |> case do
      :undefined -> {:error, "Session #{session} not found."}
      pid -> Kernel.send(pid, {:mutate, store, mutation, payload})
    end
  end
end
