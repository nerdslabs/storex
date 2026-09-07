defmodule StorexTest.StoreTest do
  use ExUnit.Case

  alias StorexTest.Store.Counter
  alias StorexTest.Store.ErrorInit
  alias StorexTest.Store.InvalidInit
  alias StorexTest.Store.InvalidMutation
  alias StorexTest.Store.KeyInit
  alias StorexTest.Store.Text

  describe "resolve/1" do
    test "resolves a module that declares the behaviour" do
      assert Storex.Store.resolve("StorexTest.Store.Counter") == {:ok, Counter}
    end

    test "refuses a module that does not declare the behaviour" do
      assert Storex.Store.resolve("StorexTest.NotAStore") == {:error, :not_store}
    end

    test "refuses a name that does not resolve to a module" do
      assert Storex.Store.resolve("StorexTest.Store.NotExisting") == {:error, :not_exists}
    end

    test "refuses a name that is not an existing atom" do
      assert Storex.Store.resolve("Never.Compiled.#{System.unique_integer([:positive])}") ==
               {:error, :not_exists}
    end
  end

  describe "init dispatch" do
    test "{:ok, state} is normalized with a nil key" do
      assert Storex.Store.__init__(Counter, "session", %{}) == {:ok, %{counter: 0}, nil}
    end

    test "{:ok, state, key} keeps the key" do
      assert Storex.Store.__init__(KeyInit, "session", %{}) == {:ok, %{counter: 0}, "user_id"}
    end

    test "{:error, reason} is passed through" do
      assert Storex.Store.__init__(ErrorInit, "session", %{}) == {:error, "Unauthorized"}
    end

    test "params are forwarded to the store" do
      assert Storex.Store.__init__(Text, "session", %{"initial_value" => "custom"}) ==
               {:ok, "custom", nil}
    end

    test "an unsupported return value raises" do
      assert_raise RuntimeError,
                   "Return value of store init should be {:ok, state}, {:ok, state, key} or {:error, reason}",
                   fn -> Storex.Store.__init__(InvalidInit, "session", %{}) end
    end
  end

  describe "mutation dispatch" do
    test "{:noreply, state} is passed through" do
      assert Storex.Store.__mutation__(Counter, "increase", [], "session", %{}, %{counter: 0}) ==
               {:noreply, %{counter: 1}}
    end

    test "{:reply, message, state} is passed through" do
      assert Storex.Store.__mutation__(Counter, "decrease", [], "session", %{}, %{counter: 0}) ==
               {:reply, "decreased", %{counter: -1}}
    end

    test "{:error, reason} is passed through" do
      assert Storex.Store.__mutation__(InvalidMutation, "error", [], "session", %{}, %{}) ==
               {:error, "Not allowed"}
    end

    test "an unsupported return value is reported as an error" do
      assert Storex.Store.__mutation__(InvalidMutation, "invalid", [], "session", %{}, %{}) ==
               {:error,
                "Return value of mutation should be {:reply, message, state}, {:noreply, state} or {:error, error}"}
    end

    test "an unmatched mutation name is reported as an error" do
      assert Storex.Store.__mutation__(Counter, "unknown", [1], "session", %{}, %{counter: 0}) ==
               {:error,
                "No mutation matching \"unknown\" with data [1] in store StorexTest.Store.Counter"}
    end

    test "a FunctionClauseError raised inside a matching mutation is not swallowed" do
      error =
        assert_raise FunctionClauseError, fn ->
          Storex.Store.__mutation__(InvalidMutation, "raise", 1, "session", %{}, %{})
        end

      assert error.function == :only_zero
      assert error.arity == 1
    end

    test "the original stacktrace of a raise inside a mutation is preserved" do
      stacktrace =
        try do
          Storex.Store.__mutation__(InvalidMutation, "raise", 1, "session", %{}, %{})
        rescue
          _ -> __STACKTRACE__
        end

      assert [{InvalidMutation, :only_zero, [1], _location} | _rest] = stacktrace
    end
  end

  describe "store server" do
    setup do
      session = "session-#{System.unique_integer([:positive])}"

      on_exit(fn ->
        Storex.Registry.session_stores(session)
        |> Enum.each(fn {store, _, _, _, _} -> Storex.Supervisor.remove_store(session, store) end)
      end)

      %{session: session}
    end

    test "starts a store returning {:ok, state}", %{session: session} do
      assert {:ok, nil} =
               Storex.Supervisor.add_store("StorexTest.Store.Counter", session, self(), %{})

      assert Storex.Supervisor.get_store_state(session, "StorexTest.Store.Counter") ==
               {:ok, %{counter: 0}}
    end

    test "starts a store returning {:ok, state, key}", %{session: session} do
      assert {:ok, "user_id"} =
               Storex.Supervisor.add_store("StorexTest.Store.KeyInit", session, self(), %{})
    end

    test "does not start a store returning {:error, reason}", %{session: session} do
      assert {:error, "Unauthorized"} =
               Storex.Supervisor.add_store("StorexTest.Store.ErrorInit", session, self(), %{})
    end

    test "mutating through the server returns the state diff", %{session: session} do
      {:ok, _} = Storex.Supervisor.add_store("StorexTest.Store.Counter", session, self(), %{})

      assert {:ok, [%{a: "u", p: [:counter], t: 1}]} =
               Storex.Supervisor.mutate_store(session, "StorexTest.Store.Counter", "increase", [])
    end
  end
end
