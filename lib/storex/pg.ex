defmodule Storex.PG do
  @moduledoc false
  use GenServer

  @name :storex_pg

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  @impl true
  def init(_) do
    :ok = :pg.join(Storex.PG, @name, self())
    {:ok, @name}
  end

  # `:pg.get_members/2` always returns a list — the `{:error, _}` clause this used
  # to carry was `:pg2`'s contract, and `:pg2` is gone. `Enum.each/2` rather than
  # a comprehension so the return value is `:ok`: `send/2` returns the message,
  # so `Storex.mutate/3` used to hand back the internal broadcast envelope once
  # per node.
  def broadcast(payload) do
    Storex.PG
    |> :pg.get_members(@name)
    |> Enum.each(&send(&1, {:broadcast, payload}))
  end

  @impl true
  def handle_info({:broadcast, {:mutate, store, mutation, payload}}, state) do
    Storex.Registry.get_store_instances({store, :_, :_, :_, :_})
    |> Enum.map(fn {^store, _, _, session_pid, _} ->
      Kernel.send(session_pid, {:mutate, store, mutation, payload})
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:broadcast, {:mutate, key, store, mutation, payload}}, state) do
    Storex.Registry.get_store_instances({store, :_, :_, :_, key})
    |> Enum.each(fn {^store, _, _, session_pid, ^key} ->
      Kernel.send(session_pid, {:mutate, store, mutation, payload})
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(_, state) do
    {:noreply, state}
  end
end
