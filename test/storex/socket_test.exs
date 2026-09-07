defmodule StorexTest.SocketTest do
  use ExUnit.Case

  @store "StorexTest.Store.Counter"

  defp session, do: "session-#{System.unique_integer([:positive])}"

  defp joined_session do
    session = session()
    {:ok, _key} = Storex.Supervisor.add_store(@store, session, self(), %{})
    on_exit(fn -> Storex.Supervisor.remove_store(session, @store) end)
    session
  end

  defp mutation(session, name) do
    %Storex.Message{
      type: "mutation",
      store: @store,
      session: session,
      data: %{name: name, data: []},
      request: "request-id"
    }
  end

  describe "mutation" do
    test "the session in the frame cannot address another session's store" do
      attacker = joined_session()
      victim = joined_session()

      # The frame claims the victim's session; the socket belongs to the attacker.
      message = mutation(victim, "increase")
      state = %{session: attacker, pid: self()}

      assert {:text, response, ^state} = Storex.Socket.message_handle(message, state)

      assert Storex.Supervisor.get_store_state(victim, @store) == {:ok, %{counter: 0}}
      assert Storex.Supervisor.get_store_state(attacker, @store) == {:ok, %{counter: 1}}

      assert %{"session" => ^attacker, "diff" => [%{"p" => ["counter"], "t" => 1}]} =
               Jason.decode!(response)
    end

    test "the response always echoes the session of the socket" do
      session = joined_session()
      state = %{session: session, pid: self()}

      assert {:text, response, ^state} =
               Storex.Socket.message_handle(mutation("some-other-session", "increase"), state)

      assert %{"session" => ^session} = Jason.decode!(response)
    end

    test "a store the session has not joined returns an error instead of crashing" do
      session = session()
      state = %{session: session, pid: self()}

      assert {:text, response, ^state} =
               Storex.Socket.message_handle(mutation(session, "increase"), state)

      assert %{
               "type" => "error",
               "session" => ^session,
               "store" => @store,
               "error" => error,
               "request" => "request-id"
             } = Jason.decode!(response)

      assert error == "Store 'StorexTest.Store.Counter' is not joined in this session."
    end

    test "a reply from the store is passed through" do
      session = joined_session()
      state = %{session: session, pid: self()}

      assert {:text, response, ^state} =
               Storex.Socket.message_handle(mutation(session, "decrease"), state)

      assert %{"message" => "decreased", "diff" => [%{"p" => ["counter"], "t" => -1}]} =
               Jason.decode!(response)
    end

    test "a mutation pushed by Storex.mutate/3 is handled" do
      session = joined_session()
      state = %{session: session, pid: self()}

      # The shape the handlers build in handle_info/2: a plain map, no request id.
      pushed = %{
        type: "mutation",
        session: session,
        store: @store,
        data: %{data: [], name: "increase"}
      }

      assert {:text, response, ^state} = Storex.Socket.message_handle(pushed, state)

      assert %{"request" => nil, "diff" => [%{"p" => ["counter"], "t" => 1}]} =
               Jason.decode!(response)
    end
  end
end
