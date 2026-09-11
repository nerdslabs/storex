defmodule StorexTest.HTTPTest do
  use ExUnit.Case

  describe "init_store/2" do
    test "returns the initial state of a store" do
      assert {:ok,
              %{
                type: "join",
                session: "SSR",
                store: "StorexTest.Store.Counter",
                data: %{counter: 0}
              }} = Storex.HTTP.init_store("StorexTest.Store.Counter", "{}")
    end

    test "params are forwarded to the store" do
      assert {:ok, %{data: "custom"}} =
               Storex.HTTP.init_store("StorexTest.Store.Text", ~s({"initial_value": "custom"}))
    end

    test "a module that is not a store is refused without being called" do
      # StorexTest.NotAStore exports init/2 and raises if it is ever reached.
      assert {:error,
              %{
                type: "error",
                session: "SSR",
                store: "StorexTest.NotAStore",
                error: "Store 'StorexTest.NotAStore' is not defined or can't be compiled."
              }} = Storex.HTTP.init_store("StorexTest.NotAStore", "{}")
    end

    test "a name that does not resolve to a module is refused" do
      assert {:error, %{type: "error", error: error}} =
               Storex.HTTP.init_store("StorexTest.Store.NotExisting", "{}")

      assert error ==
               "Store 'StorexTest.Store.NotExisting' is not defined or can't be compiled."
    end

    test "an {:error, reason} from the store is passed through" do
      assert {:error, %{type: "error", error: "Unauthorized"}} =
               Storex.HTTP.init_store("StorexTest.Store.ErrorInit", "{}")
    end

    test "an unsupported return value from the store raises" do
      assert_raise RuntimeError,
                   "Return value of store init should be {:ok, state}, {:ok, state, key} or {:error, reason}",
                   fn -> Storex.HTTP.init_store("StorexTest.Store.InvalidInit", "{}") end
    end
  end
end
