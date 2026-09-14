defmodule StorexTest.ScopeTest do
  use ExUnit.Case, async: false

  @counter "StorexTest.Store.Counter"
  @room "StorexTest.Store.Room"
  @shared "StorexTest.Store.Shared"

  defp session, do: "session-#{System.unique_integer([:positive])}"
  defp room, do: "room-#{System.unique_integer([:positive])}"

  defp join(store, session, params) do
    result = Storex.Supervisor.add_store(store, session, self(), params)
    on_exit(fn -> Storex.Supervisor.remove_store(session, store) end)
    result
  end

  describe "scope resolution" do
    test "a store without the option is :session scoped" do
      assert Storex.Store.scope(StorexTest.Store.Counter) == :session
      assert Storex.Store.scope_id(StorexTest.Store.Counter, "s", %{}) == {:ok, "s"}
    end

    test ":global resolves to the same id for every session" do
      assert Storex.Store.scope(StorexTest.Store.Shared) == :global
      assert Storex.Store.scope_id(StorexTest.Store.Shared, "a", %{}) == {:ok, :global}
      assert Storex.Store.scope_id(StorexTest.Store.Shared, "b", %{}) == {:ok, :global}
    end

    test "{:key, _} resolves to the param value" do
      assert Storex.Store.scope(StorexTest.Store.Room) == {:key, "room"}

      assert Storex.Store.scope_id(StorexTest.Store.Room, "a", %{"room" => "lobby"}) ==
               {:ok, {"room", "lobby"}}
    end

    test "{:key, _} without the param is an error, not a crash" do
      assert Storex.Store.scope_id(StorexTest.Store.Room, "a", %{}) ==
               {:error,
                "Store StorexTest.Store.Room is scoped by param \"room\", which was not given."}

      # Params are whatever the client sent — a non-map must not raise either.
      assert {:error, _} = Storex.Store.scope_id(StorexTest.Store.Room, "a", "not a map")
    end

    test "an unknown scope is refused at compile time" do
      assert_raise ArgumentError, ~r/invalid :scope for use Storex.Store/, fn ->
        Code.eval_string("""
        defmodule StorexTest.Store.BadScope#{System.unique_integer([:positive])} do
          use Storex.Store, scope: :nope
        end
        """)
      end
    end
  end

  describe ":session scope" do
    test "two sessions get two processes and two states" do
      a = session()
      b = session()

      {:ok, _} = join(@counter, a, %{})
      {:ok, _} = join(@counter, b, %{})

      pid_a = Storex.Registry.get_store_pid(@counter, a)
      pid_b = Storex.Registry.get_store_pid(@counter, b)

      refute pid_a == pid_b

      {:ok, _} = Storex.Supervisor.mutate_store(a, @counter, "increase", [])

      assert Storex.Supervisor.get_store_state(a, @counter) == {:ok, %{counter: 1}}
      assert Storex.Supervisor.get_store_state(b, @counter) == {:ok, %{counter: 0}}
    end

    test "a mutation pushes no diff to anybody else" do
      a = session()
      {:ok, _} = join(@counter, a, %{})

      {:ok, _} = Storex.Supervisor.mutate_store(a, @counter, "increase", [])

      refute_receive {:storex_diff, _, _}, 100
    end
  end

  describe "shared scope" do
    test "sessions with the same key share one process and one state" do
      a = session()
      b = session()
      room = room()

      {:ok, _} = join(@room, a, %{"room" => room})
      {:ok, _} = join(@room, b, %{"room" => room})

      pid_a = Storex.Registry.get_store_pid(@room, a)
      pid_b = Storex.Registry.get_store_pid(@room, b)

      assert pid_a == pid_b
      assert [{^pid_a, nil}] = Registry.lookup(Storex.StoreRegistry, {{"room", room}, @room})

      {:ok, _} = Storex.Supervisor.mutate_store(a, @room, "increase", [])

      assert {:ok, %{counter: 1}} = Storex.Supervisor.get_store_state(b, @room)
    end

    test "sessions with different keys do not share" do
      a = session()
      b = session()

      {:ok, _} = join(@room, a, %{"room" => room()})
      {:ok, _} = join(@room, b, %{"room" => room()})

      refute Storex.Registry.get_store_pid(@room, a) ==
               Storex.Registry.get_store_pid(@room, b)
    end

    test "init/2 runs once, for the session that attaches first" do
      a = session()
      b = session()
      room = room()

      {:ok, _} = join(@room, a, %{"room" => room, "reporter" => self()})
      assert_receive {:initialized, ^a}, 1000

      {:ok, _} = join(@room, b, %{"room" => room, "reporter" => self()})
      refute_receive {:initialized, ^b}, 100
    end

    test "a missing scope param is reported to the caller" do
      assert {:error, message} = Storex.Supervisor.add_store(@room, session(), self(), %{})
      assert message =~ "scoped by param \"room\""
    end

    test "mutation/5 is given the session that issued it, not the one init/2 ran with" do
      a = session()
      b = session()
      room = room()

      {:ok, _} = join(@room, a, %{"room" => room})
      {:ok, _} = join(@room, b, %{"room" => room})

      {:ok, _} = Storex.Supervisor.mutate_store(b, @room, "increase", [])

      assert {:ok, %{last: ^b}} = Storex.Supervisor.get_store_state(a, @room)
    end
  end

  describe "shared scope diff fan-out" do
    test "the other sessions are pushed the diff, the mutating one is not" do
      a = session()
      b = session()
      room = room()

      {:ok, _} = join(@room, a, %{"room" => room})
      {:ok, _} = join(@room, b, %{"room" => room})

      {:ok, diff} = Storex.Supervisor.mutate_store(a, @room, "increase", [])

      # Both sessions registered this process as their session pid, so exactly
      # one push means session b was sent the diff and session a was not: it
      # already has it, as the reply to its own call.
      assert_receive {:storex_diff, @room, ^diff}, 1000
      refute_receive {:storex_diff, @room, _}, 100

      assert Enum.any?(diff, &match?(%{a: "u", p: [:counter], t: 1}, &1))
    end

    test "an empty diff is not pushed" do
      a = session()
      b = session()
      room = room()

      {:ok, _} = join(@room, a, %{"room" => room})
      {:ok, _} = join(@room, b, %{"room" => room})

      assert {:ok, []} = Storex.Supervisor.mutate_store(a, @room, "noop", [])

      refute_receive {:storex_diff, _, _}, 100
    end
  end

  describe "shared scope lifetime" do
    test "the process outlives a session that leaves and stops with the last one" do
      a = session()
      b = session()
      room = room()

      {:ok, _} = join(@room, a, %{"room" => room, "reporter" => self()})
      {:ok, _} = join(@room, b, %{"room" => room})

      pid = Storex.Registry.get_store_pid(@room, a)
      assert_receive {:initialized, ^a}, 1000

      Storex.Supervisor.remove_store(a, @room)

      refute_receive {:terminated, _, _, _}, 100
      assert Process.alive?(pid)
      assert Storex.Registry.get_store_pid(@room, b) == pid

      Storex.Supervisor.remove_store(b, @room)

      # terminate/3 is given the session and params init/2 ran with, which is
      # session a — the one that is already gone.
      assert_receive {:terminated, ^a, %{"room" => ^room}, %{counter: 0}}, 1000
    end

    test "the scope name is released once the last session leaves" do
      a = session()
      room = room()

      {:ok, _} = join(@room, a, %{"room" => room})
      assert [{_, nil}] = Registry.lookup(Storex.StoreRegistry, {{"room", room}, @room})

      Storex.Supervisor.remove_store(a, @room)

      assert eventually(fn ->
               Registry.lookup(Storex.StoreRegistry, {{"room", room}, @room}) == []
             end)
    end
  end

  describe "Storex.mutate/3 against a shared store" do
    test "the mutation is dispatched once per store process, not once per session" do
      a = session()
      b = session()
      room = room()

      {:ok, _} = join(@room, a, %{"room" => room})
      {:ok, _} = join(@room, b, %{"room" => room})

      # Both sessions registered this process as their session pid. A shared
      # store must run the mutation once against the state they share, so the
      # fan-out has to reach one of them and not both.
      Storex.mutate(@room, "increase", [])

      assert_receive {:mutate, @room, "increase", []}, 1000
      refute_receive {:mutate, @room, "increase", []}, 100
    end

    test "a :session scoped store is still reached once per session" do
      a = session()
      b = session()

      {:ok, _} = join(@counter, a, %{})
      {:ok, _} = join(@counter, b, %{})

      Storex.mutate(@counter, "increase", [])

      assert_receive {:mutate, @counter, "increase", []}, 1000
      assert_receive {:mutate, @counter, "increase", []}, 1000
    end
  end

  describe ":global scope" do
    test "every session on the node lands on the same process" do
      a = session()
      b = session()

      {:ok, _} = join(@shared, a, %{})
      {:ok, _} = join(@shared, b, %{})

      pid = Storex.Registry.get_store_pid(@shared, a)

      assert Storex.Registry.get_store_pid(@shared, b) == pid
      assert [{^pid, nil}] = Registry.lookup(Storex.StoreRegistry, {:global, @shared})

      {:ok, _} = Storex.Supervisor.mutate_store(a, @shared, "increase", [])

      assert {:ok, %{counter: counter}} = Storex.Supervisor.get_store_state(b, @shared)
      assert counter > 0
    end
  end

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
end
