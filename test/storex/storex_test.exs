defmodule StorexTest do
  use ExUnit.Case
  doctest Storex

  defmodule FakeWebsocketServer do
    use GenServer

    @impl true
    def init([parent_pid, session]) do
      {:ok, %{session: session, parent_pid: parent_pid}}
    end

    @impl true
    def handle_info(
          {:mutate, store, mutation, data},
          %{session: session, parent_pid: parent_pid} = state
        ) do
      %{
        type: "mutation",
        session: session,
        store: store,
        data: %{
          data: data,
          name: mutation
        }
      }
      |> Storex.Socket.message_handle(state)

      send(parent_pid, :ok)

      {:noreply, state}
    end
  end

  describe "global" do
    setup do
      session = Application.get_env(:storex, :session_id_library, Nanoid).generate()

      {:ok, pid} =
        GenServer.start_link(FakeWebsocketServer, [self(), session], name: {:global, session})

      %{
        session: session,
        store: "StorexTest.Store.Counter",
        pid: pid
      }
    end

    test "create store", %{session: session, store: store, pid: pid} do
      assert {:ok, _pid} = Storex.Supervisor.add_store(store, session, pid, %{})
      Storex.Supervisor.remove_store(session, store)
    end

    test "get store", %{session: session, store: store, pid: pid} do
      assert {:ok, _pid} = Storex.Supervisor.add_store(store, session, pid, %{})
      assert {:ok, %{counter: 0}} = Storex.Supervisor.get_store_state(session, store)
      Storex.Supervisor.remove_store(session, store)
    end

    test "mutate store", %{session: session, store: store, pid: pid} do
      assert {:ok, _pid} = Storex.Supervisor.add_store(store, session, pid, %{})

      Storex.mutate(store, "increase", [])

      assert_receive :ok

      assert {:ok, %{counter: 1}} = Storex.Supervisor.get_store_state(session, store)
    end

    test "reaches every session of the store", %{session: session, store: store, pid: pid} do
      # The point of mutate/3 is the fan-out. One session proves nothing.
      other_session = Application.get_env(:storex, :session_id_library, Nanoid).generate()

      {:ok, other_pid} =
        GenServer.start_link(FakeWebsocketServer, [self(), other_session],
          name: {:global, other_session}
        )

      assert {:ok, _} = Storex.Supervisor.add_store(store, session, pid, %{})
      assert {:ok, _} = Storex.Supervisor.add_store(store, other_session, other_pid, %{})

      Storex.mutate(store, "increase", [])

      assert_receive :ok
      assert_receive :ok

      assert {:ok, %{counter: 1}} = Storex.Supervisor.get_store_state(session, store)
      assert {:ok, %{counter: 1}} = Storex.Supervisor.get_store_state(other_session, store)

      Storex.Supervisor.remove_store(other_session, store)
    end

    test "does not reach a session that joined a different store", %{
      session: session,
      store: store,
      pid: pid
    } do
      other_session = Application.get_env(:storex, :session_id_library, Nanoid).generate()

      {:ok, other_pid} =
        GenServer.start_link(FakeWebsocketServer, [self(), other_session],
          name: {:global, other_session}
        )

      assert {:ok, _} = Storex.Supervisor.add_store(store, session, pid, %{})

      assert {:ok, _} =
               Storex.Supervisor.add_store("StorexTest.Store.Text", other_session, other_pid, %{})

      Storex.mutate(store, "increase", [])

      assert_receive :ok
      refute_receive :ok, 200

      Storex.Supervisor.remove_store(other_session, "StorexTest.Store.Text")
    end

    test "mutate store in cluster", %{session: session, store: store, pid: pid} do
      [node_1] =
        LocalCluster.start_nodes(:spawn, 1,
          files: [
            __ENV__.file
          ]
        )

      assert {:ok, _pid} = Storex.Supervisor.add_store(store, session, pid, %{})

      Node.spawn(node_1, fn ->
        Storex.mutate(store, "increase", [])
      end)

      assert_receive :ok

      assert {:ok, %{counter: 1}} = Storex.Supervisor.get_store_state(session, store)
    end
  end

  describe "key" do
    setup do
      session = Application.get_env(:storex, :session_id_library, Nanoid).generate()

      {:ok, pid} =
        GenServer.start_link(FakeWebsocketServer, [self(), session], name: {:global, session})

      %{
        session: session,
        store: "StorexTest.Store.KeyInit",
        pid: pid
      }
    end

    test "mutate store", %{session: session, store: store, pid: pid} do
      [node_1] =
        LocalCluster.start_nodes(:spawn, 1,
          files: [
            __ENV__.file
          ]
        )

      assert {:ok, _pid} = Storex.Supervisor.add_store(store, session, pid, %{})

      Node.spawn(node_1, fn ->
        Storex.mutate("user_id", store, "set", [1])
      end)

      assert_receive :ok

      assert {:ok, %{counter: 1}} = Storex.Supervisor.get_store_state(session, store)
    end

    test "don't mutate store for invalid key", %{session: session, store: store, pid: pid} do
      assert {:ok, _pid} = Storex.Supervisor.add_store(store, session, pid, %{})

      Storex.mutate("invalid_key", store, "set", [1])

      refute_receive :ok

      assert {:ok, %{counter: 0}} = Storex.Supervisor.get_store_state(session, store)
    end

    test "don't mutate store for invalid key in cluster", %{
      session: session,
      store: store,
      pid: pid
    } do
      [node_1] =
        LocalCluster.start_nodes(:spawn, 1,
          files: [
            __ENV__.file
          ]
        )

      assert {:ok, _pid} = Storex.Supervisor.add_store(store, session, pid, %{})

      Node.spawn(node_1, fn ->
        Storex.mutate("invalid_key", store, "set", [1])
      end)

      refute_receive :ok

      assert {:ok, %{counter: 0}} = Storex.Supervisor.get_store_state(session, store)
    end
  end

  describe "error" do
    setup do
      %{
        session: Application.get_env(:storex, :session_id_library, Nanoid).generate(),
        store: "StorexTest.Store.ErrorInit"
      }
    end

    test "create store", %{session: session, store: store} do
      assert {:error, "Unauthorized"} = Storex.Supervisor.add_store(store, session, self(), %{})
    end
  end

  describe "mutate return value" do
    test "mutate/3 returns :ok" do
      assert Storex.mutate("StorexTest.Store.Counter", "increase", []) == :ok
    end

    test "mutate/4 returns :ok" do
      assert Storex.mutate("key", "StorexTest.Store.Counter", "increase", []) == :ok
    end
  end
end
