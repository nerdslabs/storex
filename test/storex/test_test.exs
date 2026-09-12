defmodule StorexTest.TestTest do
  # Tests `Storex.Test`. Sync, because `broadcast/4` exercises the cluster
  # fan-out, which reaches every session of a store on the node.
  use ExUnit.Case, async: false

  alias StorexTest.Store.Counter
  alias StorexTest.Store.ErrorInit
  alias StorexTest.Store.InvalidMutation
  alias StorexTest.Store.KeyInit
  alias StorexTest.Store.Terminating

  describe "start_store/2" do
    test "takes a module" do
      assert {:ok, handle} = Storex.Test.start_store(Counter)

      assert handle.store == "StorexTest.Store.Counter"
      assert is_pid(Storex.Registry.get_store_pid(handle.store, handle.session))
    end

    test "takes the name a client would send" do
      assert {:ok, handle} = Storex.Test.start_store("StorexTest.Store.Counter")
      assert handle.store == "StorexTest.Store.Counter"
    end

    test "params reach init/2" do
      assert {:ok, handle} =
               Storex.Test.start_store(StorexTest.Store.Text, params: %{"initial_value" => "hi"})

      assert Storex.Test.state(handle) == "hi"
    end

    test "the key from {:ok, state, key} is on the handle" do
      assert {:ok, %{key: "user_id"}} = Storex.Test.start_store(KeyInit)
    end

    test "a store with no key has a nil one" do
      assert {:ok, %{key: nil}} = Storex.Test.start_store(Counter)
    end

    test "sessions are unique per call" do
      {:ok, one} = Storex.Test.start_store(Counter)
      {:ok, two} = Storex.Test.start_store(Counter)

      refute one.session == two.session

      refute Storex.Registry.get_store_pid(one.store, one.session) ==
               Storex.Registry.get_store_pid(two.store, two.session)
    end

    test "a session can be given" do
      assert {:ok, %{session: "chosen"}} = Storex.Test.start_store(Counter, session: "chosen")
    end

    test "a store refusing to start is an error, not a raise" do
      assert Storex.Test.start_store(ErrorInit) == {:error, "Unauthorized"}
    end
  end

  describe "start_store!/2" do
    test "returns the handle" do
      assert %Storex.Test{} = Storex.Test.start_store!(Counter)
    end

    test "raises when the store refuses to start" do
      assert_raise RuntimeError, ~r/did not start: "Unauthorized"/, fn ->
        Storex.Test.start_store!(ErrorInit)
      end
    end
  end

  describe "state/1" do
    test "reads the current state" do
      handle = Storex.Test.start_store!(Counter)
      assert Storex.Test.state(handle) == %{counter: 0}
    end

    test "raises for a store that is gone" do
      handle = Storex.Test.start_store!(Counter)
      Storex.Test.stop(handle)

      assert_raise RuntimeError, ~r/is not joined in this session/, fn ->
        Storex.Test.state(handle)
      end
    end
  end

  describe "commit/3" do
    test "gives back the state, the diff and no message" do
      handle = Storex.Test.start_store!(Counter)

      assert {:ok, result} = Storex.Test.commit(handle, "increase")

      assert result.state == %{counter: 1}
      assert result.diff == [%{a: "u", p: [:counter], t: 1}]
      assert result.message == nil
    end

    test "carries the reply of a {:reply, message, state} mutation" do
      handle = Storex.Test.start_store!(Counter)

      assert {:ok, %{message: "decreased", state: %{counter: -1}}} =
               Storex.Test.commit(handle, "decrease")
    end

    test "passes data through" do
      handle = Storex.Test.start_store!(StorexTest.Store.Text)

      assert {:ok, %{state: "changed"}} = Storex.Test.commit(handle, "change", ["changed"])
    end

    test "a mutation returning an error is an error" do
      handle = Storex.Test.start_store!(InvalidMutation)

      assert Storex.Test.commit(handle, "error") == {:error, "Not allowed"}
    end

    test "a name no clause matches is an error" do
      handle = Storex.Test.start_store!(Counter)

      assert {:error, message} = Storex.Test.commit(handle, "nope", [1])
      assert message =~ "No mutation matching \"nope\""
    end

    test "state is unchanged after an error" do
      handle = Storex.Test.start_store!(InvalidMutation)

      assert {:error, _} = Storex.Test.commit(handle, "error")
      assert Storex.Test.state(handle) == %{counter: 0}
    end

    test "an empty diff is an empty list, not an absence" do
      handle = Storex.Test.start_store!(StorexTest.Store.Text, params: %{"initial_value" => "x"})

      assert {:ok, %{diff: []}} = Storex.Test.commit(handle, "change", ["x"])
    end
  end

  describe "commit!/3" do
    test "returns the result" do
      handle = Storex.Test.start_store!(Counter)
      assert %{state: %{counter: 1}} = Storex.Test.commit!(handle, "increase")
    end

    test "raises on an error" do
      handle = Storex.Test.start_store!(InvalidMutation)

      assert_raise RuntimeError, ~r/mutation "error" failed: "Not allowed"/, fn ->
        Storex.Test.commit!(handle, "error")
      end
    end
  end

  describe "broadcast/4" do
    test "applies a Storex.mutate/3 fan-out" do
      handle = Storex.Test.start_store!(Counter)

      assert {:ok, result} = Storex.Test.broadcast(handle, "increase")

      assert result.state == %{counter: 1}
      assert result.diff == [%{a: "u", p: [:counter], t: 1}]
    end

    test "filters on the key, like Storex.mutate/4" do
      handle = Storex.Test.start_store!(KeyInit)

      assert {:ok, %{state: %{counter: 5}}} =
               Storex.Test.broadcast(handle, "set", [5], key: "user_id")
    end

    test "a key the store did not return never reaches it" do
      handle = Storex.Test.start_store!(KeyInit)

      assert Storex.Test.broadcast(handle, "set", [5], key: "somebody_else", timeout: 100) ==
               {:error, :timeout}

      assert Storex.Test.state(handle) == %{counter: 0}
    end
  end

  describe "stop/1" do
    test "runs terminate/3 with the state as of the last mutation" do
      handle = Storex.Test.start_store!(Terminating, params: %{"reporter" => self()})
      session = handle.session

      {:ok, _} = Storex.Test.commit(handle, "increase")

      assert Storex.Test.stop(handle) == :ok

      # stop/1 waits for the process, so the message is already here.
      assert_received {:terminated, ^session, _params, %{counter: 1}}
    end

    test "the process is gone when it returns" do
      handle = Storex.Test.start_store!(Counter)
      pid = Storex.Registry.get_store_pid(handle.store, handle.session)

      Storex.Test.stop(handle)

      refute Process.alive?(pid)
      assert Storex.Registry.get_store_pid(handle.store, handle.session) == :undefined
    end

    test "stopping twice is fine" do
      handle = Storex.Test.start_store!(Counter)

      assert Storex.Test.stop(handle) == :ok
      assert Storex.Test.stop(handle) == :ok
    end
  end

  describe "cleanup" do
    test "a store started here is stopped when the test ends" do
      # `on_exit` runs callbacks last-registered-first, and it runs them in
      # another process — hence the unlinked agent to carry the handle across.
      # Registering before the store exists is what puts this assertion *after*
      # the callback `start_store/2` registers.
      {:ok, agent} = Agent.start(fn -> nil end)

      on_exit(fn ->
        handle = Agent.get(agent, & &1)
        Agent.stop(agent)

        assert Storex.Registry.get_store_pid(handle.store, handle.session) == :undefined
      end)

      handle = Storex.Test.start_store!(Counter)
      Agent.update(agent, fn _ -> handle end)

      assert is_pid(Storex.Registry.get_store_pid(handle.store, handle.session))
    end
  end
end
