defmodule Storex do
  use Application

  @doc false
  def start(_type, _args) do
    children = [
      %{id: :pg, start: {:pg, :start_link, [Storex.PG]}},
      {Storex.PG, []},
      {Storex.Registry, []},
      {Registry, keys: :unique, name: Storex.StoreRegistry},
      {Storex.Supervisor, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
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
