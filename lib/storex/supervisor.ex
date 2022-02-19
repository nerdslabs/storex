defmodule Storex.Supervisor do
  @moduledoc false

  use DynamicSupervisor

  def start_link() do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(initial_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [initial_arg]
    )
  end

  def has_store(session, store) do
    Storex.Registry.get_store_pid(session, store)
    |> case do
      :undefined -> false
      _ -> true
    end
  end

  def name(session, store) do
    String.to_atom("#{session}_#{store}")
  end

  def add_store(session, store, params \\ %{}) do
    store_server = Module.concat([store, "Server"])
    spec = {store_server, [session: session, store: store, params: params]}
    # TODO: If server not start error is not raised!
    DynamicSupervisor.start_child(__MODULE__, spec)
    |> case do
      {:error, error} -> IO.warn(error)
      result -> result
    end
    |> case do
      {:ok, pid} ->
        Storex.Registry.register_store(session, store, pid)
      _ ->
        :error
    end
  end

  def get_store_state(session, store) do
    Storex.Registry.get_store_pid(session, store)
    |> :sys.get_state()
    |> Map.get(:state)
  end

  def mutate_store(session, store, name, data) do
    Storex.Registry.get_store_pid(session, store)
    |> GenServer.call({name, data})
  end

  def remove_store(session, store) do
    Storex.Registry.get_store_pid(session, store)
    |> GenServer.cast(:session_ended)
  end
end
