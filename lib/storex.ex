defmodule Storex do

  use Application

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Storex.Registries.Sessions, []),
      worker(Storex.Registries.Stores, []),
      supervisor(Storex.Supervisor, [])
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  @doc """
  Mutate store from elixir.

  ```elixir
  Storex.mutate("d9ez7fgkp96", "ExampleApp.Store", "reload", ["user_id"])
  ```
  """
  def mutate(session, store, mutation, payload \\ []) do
    Storex.Registries.Sessions.whereis_name(session)
    |> case do
      :undefined -> {:error, "Session #{session} not found."}
      pid -> Kernel.send(pid, {:mutate, store, mutation, payload})
    end
  end
end
