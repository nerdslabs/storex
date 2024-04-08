defmodule Storex do
  use Application

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Storex.Registry.ETS, []),
      supervisor(Storex.Supervisor, [])
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  @doc """
  Mutate store from elixir.

  Call mutation callback in store synchronously:
  ```elixir
  Storex.mutate("d9ez7fgkp96", "ExampleApp.Store", "reload", ["user_id"])
  ```
  """
  def mutate(session, store, mutation, payload \\ [])
      when is_binary(session) and is_binary(store) do
    Storex.Registry.session_pid(session)
    |> case do
      :undefined -> {:error, "Session #{session} not found."}
      pid -> Kernel.send(pid, {:mutate, store, mutation, payload})
    end
  end
end
