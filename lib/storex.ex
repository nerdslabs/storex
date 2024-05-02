defmodule Storex do
  use Application

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children =
      pg_children() ++
        [
          {Storex.PG, []},
          {Storex.Registry, []},
          {Storex.Supervisor, []}
        ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  if Code.ensure_loaded?(:pg) do
    defp pg_children() do
      [%{id: :pg, start: {:pg, :start_link, [Storex.PG]}}]
    end
  else
    defp pg_children() do
      []
    end
  end

  @doc """
  Mutate store from elixir.

  Invoke mutation callback globally across specified store asynchronously:
  ```elixir
  Storex.mutate("ExampleApp.Store", "reload", ["params"])
  ```
  """
  def mutate(store, mutation, payload) do
    Storex.PG.broadcast({:mutate, store, mutation, payload})
  end

  @doc """
  Mutate store from elixir.

  Invoke mutation callback by specified key and store asynchronously:
  ```elixir
  Storex.mutate("user_id", "ExampleApp.Store", "reload", ["params"])
  ```
  """
  def mutate(key, store, mutation, payload) do
    Storex.PG.broadcast({:mutate, key, store, mutation, payload})
  end
end
