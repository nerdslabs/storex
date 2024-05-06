defmodule Storex.Supervisor do
  @moduledoc false

  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(initial_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [initial_arg]
    )
  end

  def name(session, store) do
    String.to_atom("#{session}_#{store}")
  end

  def add_store(store, session, session_pid, params \\ %{}) do
    Storex.Registry.get_store(store, session)
    |> case do
      :undefined ->
        store_server = Module.concat([store, "Server"])

        spec = %{
          id: store_server,
          start: {store_server, :start_link, [[session: session, store: store, params: params]]},
          restart: :transient
        }

        DynamicSupervisor.start_child(__MODULE__, spec)
        |> case do
          {:ok, store_pid, %{key: key}} ->
            Storex.Registry.register_store(store, store_pid, session, session_pid, key)
            {:ok, key}

          {:error, error} ->
            {:error, error}
        end

      {_, _, _, _, key} ->
        {:ok, key}
    end
  end

  def get_store_state(session, store) do
    Storex.Registry.get_store_pid(store, session)
    |> :sys.get_state()
    |> Map.get(:state)
  end

  def mutate_store(session, store, name, data) do
    Storex.Registry.get_store_pid(store, session)
    |> GenServer.call({name, data})
  end

  def remove_store(session, store) do
    Storex.Registry.get_store_pid(store, session)
    |> GenServer.cast(:session_ended)

    Storex.Registry.unregister_store(store, session)
  end
end
