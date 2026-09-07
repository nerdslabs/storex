defmodule StorexTest.RegistryTest do
  use ExUnit.Case, async: false

  @registry :storex_registry

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
