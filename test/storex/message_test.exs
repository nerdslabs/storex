defmodule StorexTest.MessageTest do
  use ExUnit.Case

  describe "cast/1" do
    test "casts a ping" do
      assert Storex.Message.cast(%{"type" => "ping", "request" => "r"}) ==
               {:ok, %Storex.Message{type: "ping", request: "r"}}
    end

    test "casts a join" do
      assert Storex.Message.cast(%{
               "type" => "join",
               "store" => "Store",
               "data" => %{},
               "request" => "r"
             }) ==
               {:ok, %Storex.Message{type: "join", store: "Store", data: %{}, request: "r"}}
    end

    test "casts a join carrying a session" do
      assert Storex.Message.cast(%{
               "type" => "join",
               "store" => "Store",
               "data" => %{},
               "request" => "r",
               "session" => "s"
             }) ==
               {:ok,
                %Storex.Message{
                  type: "join",
                  store: "Store",
                  data: %{},
                  request: "r",
                  session: "s"
                }}
    end

    test "casts a mutation" do
      assert Storex.Message.cast(%{
               "type" => "mutation",
               "store" => "Store",
               "data" => %{"name" => "increase", "data" => []},
               "request" => "r",
               "session" => "s"
             }) ==
               {:ok,
                %Storex.Message{
                  type: "mutation",
                  store: "Store",
                  data: %{name: "increase", data: []},
                  request: "r",
                  session: "s"
                }}
    end

    test "refuses an error frame, which only travels server to client" do
      assert Storex.Message.cast(%{
               "type" => "error",
               "store" => "Store",
               "data" => nil,
               "request" => "r",
               "session" => "s"
             }) == {:error, "Unknown message type"}
    end

    test "refuses a mutation without a name" do
      assert Storex.Message.cast(%{
               "type" => "mutation",
               "store" => "Store",
               "data" => %{},
               "request" => "r",
               "session" => "s"
             }) == {:error, "Unknown message type"}
    end

    test "refuses an unknown type" do
      assert Storex.Message.cast(%{"type" => "whatever", "request" => "r"}) ==
               {:error, "Unknown message type"}
    end

    test "refuses a payload that is not a message" do
      assert Storex.Message.cast(%{}) == {:error, "Unknown message type"}
    end
  end
end
