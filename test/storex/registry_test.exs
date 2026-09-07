defmodule StorexTest.RegistryTest do
  use ExUnit.Case, async: false

  @registry :storex_registry

  defp eventually(check, attempts \\ 100) do
    Enum.reduce_while(1..attempts, false, fn _, _ ->
      if check.() do
        {:halt, true}
      else
        Process.sleep(10)
        {:cont, false}
      end
    end)
  end

  setup do
    session = "session-#{System.unique_integer([:positive])}"
    {:ok, _} = Storex.Registry.register_store("Store", self(), session, self(), "key")
    on_exit(fn -> Storex.Registry.unregister_store("Store", session) end)
    %{session: session}
  end

  test "get_store/2 returns the whole row", %{session: session} do
    assert Storex.Registry.get_store("Store", session) ==
             {"Store", self(), session, self(), "key"}
  end

  test "get_store_pid/2 returns the store pid", %{session: session} do
    assert Storex.Registry.get_store_pid("Store", session) == self()
  end

  test "session_stores/1 returns every row of a session", %{session: session} do
    assert Storex.Registry.session_stores(session) ==
             [{"Store", self(), session, self(), "key"}]
  end

  test "get_store_instances/1 matches on the given query", %{session: session} do
    assert Storex.Registry.get_store_instances({"Store", :_, :_, :_, "key"})
           |> Enum.any?(fn
             {_, _, ^session, _, _} -> true
             _ -> false
           end)
  end

  test "a miss is :undefined", %{session: session} do
    assert Storex.Registry.get_store("Never.Joined", session) == :undefined
    assert Storex.Registry.get_store_pid("Never.Joined", session) == :undefined
  end

  test "a row is dropped when the store process dies" do
    session = "session-#{System.unique_integer([:positive])}"
    store_pid = spawn(fn -> Process.sleep(:infinity) end)

    {:ok, _} = Storex.Registry.register_store("Dying", store_pid, session, self(), nil)
    assert Storex.Registry.get_store_pid("Dying", session) == store_pid

    Process.exit(store_pid, :kill)

    # The registry monitors the store, so the row goes when the process does.
    assert eventually(fn -> Storex.Registry.get_store_pid("Dying", session) == :undefined end)
    assert Storex.Registry.session_stores(session) == []
  end

  test "only the dead process's rows are dropped", %{session: session} do
    other = "session-#{System.unique_integer([:positive])}"
    store_pid = spawn(fn -> Process.sleep(:infinity) end)

    {:ok, _} = Storex.Registry.register_store("Dying", store_pid, other, self(), nil)
    Process.exit(store_pid, :kill)

    assert eventually(fn -> Storex.Registry.get_store_pid("Dying", other) == :undefined end)
    assert Storex.Registry.get_store_pid("Store", session) == self()
  end

  test "reads do not go through the registry process", %{session: session} do
    # With the owner suspended, anything that needs a GenServer round-trip
    # blocks. Reads run in the calling process, so they still answer.
    :sys.suspend(@registry)

    try do
      assert Storex.Registry.get_store_pid("Store", session) == self()
      assert Storex.Registry.get_store("Store", session) |> elem(0) == "Store"
      assert Storex.Registry.session_stores(session) != []

      # A write still needs the process, so it times out while it is suspended.
      assert catch_exit(GenServer.call(@registry, {:unregister_store, "Store", session}, 100))
    after
      :sys.resume(@registry)
    end
  end
end
