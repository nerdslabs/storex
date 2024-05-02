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
      assert %{counter: 0} = Storex.Supervisor.get_store_state(session, store)
      Storex.Supervisor.remove_store(session, store)
    end

    test "mutate store", %{session: session, store: store, pid: pid} do
      assert {:ok, _pid} = Storex.Supervisor.add_store(store, session, pid, %{})

      Storex.mutate(store, "increase", [])

      assert_receive :ok

      assert %{counter: 1} = Storex.Supervisor.get_store_state(session, store)
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

      assert %{counter: 1} = Storex.Supervisor.get_store_state(session, store)
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
        Storex.mutate("user_id", store, "increase", [])
      end)

      assert_receive :ok

      assert %{counter: 1} = Storex.Supervisor.get_store_state(session, store)
    end

    test "don't mutate store for invalid key", %{session: session, store: store, pid: pid} do
      assert {:ok, _pid} = Storex.Supervisor.add_store(store, session, pid, %{})

      Storex.mutate("invalid_key", store, "increase", [])

      refute_receive :ok

      assert %{counter: 0} = Storex.Supervisor.get_store_state(session, store)
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
        Storex.mutate("invalid_key", store, "increase", [])
      end)

      refute_receive :ok

      assert %{counter: 0} = Storex.Supervisor.get_store_state(session, store)
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
end
