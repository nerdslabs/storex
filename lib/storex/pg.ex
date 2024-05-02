defmodule Storex.PG do
  @moduledoc false
  use GenServer

  @name :storex_pg

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  @impl true
  def init(_) do
    :ok = pg_join(@name)
    {:ok, @name}
  end

  def broadcast(payload) do
    pg_members(@name)
    |> case do
      {:error, _} ->
        :error

      pids ->
        for pid <- pids do
          send(pid, {:broadcast, payload})
        end
    end
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

  if Code.ensure_loaded?(:pg) do
    defp pg_members(group) do
      :pg.get_members(Storex.PG, group)
    end
  else
    defp pg_members(group) do
      :pg2.get_members({:storex, group})
    end
  end

  if Code.ensure_loaded?(:pg) do
    defp pg_join(group) do
      :ok = :pg.join(Storex.PG, group, self())
    end
  else
    defp pg_join(group) do
      namespace = {:storex, group}
      :ok = :pg2.create(namespace)
      :ok = :pg2.join(namespace, self())
      :ok
    end
  end
end
