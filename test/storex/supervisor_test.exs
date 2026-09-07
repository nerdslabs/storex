defmodule StorexTest.SupervisorTest do
  use ExUnit.Case

  @store "StorexTest.Store.Counter"

  defp session, do: "session-#{System.unique_integer([:positive])}"

  defp start_store(session) do
    {:ok, _key} = Storex.Supervisor.add_store(@store, session, self(), %{})
    on_exit(fn -> Storex.Supervisor.remove_store(session, @store) end)
    session
  end

  describe "store process naming" do
    test "a store is registered under a {session, store} key, not an atom" do
      session = start_store(session())

      assert [{pid, nil}] = Registry.lookup(Storex.StoreRegistry, {session, @store})
      assert pid == Storex.Registry.get_store_pid(@store, session)
    end

    test "starting stores does not create atoms" do
      # Warm up so that first-call code paths are not counted.
      for _ <- 1..5, do: start_store(session())

      sessions = for _ <- 1..200, do: session()

      atoms_before = :erlang.system_info(:atom_count)
      for session <- sessions, do: start_store(session)
      atoms_after = :erlang.system_info(:atom_count)

      assert atoms_after - atoms_before == 0
    end

    test "the same session and store cannot be started twice" do
      session = start_store(session())

      spec = %{
        id: StorexTest.Store.Counter.Server,
        start:
          {StorexTest.Store.Counter.Server, :start_link,
           [[session: session, store: @store, params: %{}]]},
        restart: :transient
      }

      assert {:error, {:already_started, pid}} =
               DynamicSupervisor.start_child(Storex.Supervisor, spec)

      assert pid == Storex.Registry.get_store_pid(@store, session)
    end

    test "the name is released when the store stops" do
      session = start_store(session())

      assert [{_pid, nil}] = Registry.lookup(Storex.StoreRegistry, {session, @store})

      Storex.Supervisor.remove_store(session, @store)

      # The cast is asynchronous, so wait for the Registry to drop the entry.
      Enum.reduce_while(1..100, nil, fn _, _ ->
        case Registry.lookup(Storex.StoreRegistry, {session, @store}) do
          [] -> {:halt, :ok}
          _ -> Process.sleep(10) && {:cont, nil}
        end
      end)

      assert Registry.lookup(Storex.StoreRegistry, {session, @store}) == []
    end
  end
end
