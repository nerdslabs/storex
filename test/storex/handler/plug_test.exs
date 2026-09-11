defmodule StorexTest.Handler.Plug do
  use ExUnit.Case, async: false

  import StorexTest.HandlerHelpers

  setup_all do
    {:ok, _} = Plug.Cowboy.http(__MODULE__, [], port: 0, protocol_options: [idle_timeout: 1000])
    on_exit(fn -> :ok = Plug.Cowboy.shutdown(__MODULE__.HTTP) end)
    {:ok, port: :ranch.get_port(__MODULE__.HTTP)}
  end

  @behaviour Plug

  @impl Plug
  def init(arg), do: arg

  @impl Plug
  def call(conn, _opts) do
    conn = Plug.Conn.fetch_query_params(conn)
    websock = conn.query_params["websock"] |> String.to_atom()
    WebSockAdapter.upgrade(conn, websock, [], timeout: 1000)
  end

  describe "init" do
    test "success", context do
      client = tcp_client(context)
      http1_handshake(client, Storex.Handler.Plug)

      send_text_frame(client, """
      {
        "type": "join",
        "store": "StorexTest.Store.Counter",
        "data": {},
        "request": "#{random_string()}"
      }
      """)

      {:ok, result} = recv_text_frame(client)

      assert %{data: %{counter: 0}, type: "join", store: "StorexTest.Store.Counter"} =
               Jason.decode!(result, keys: :atoms)
    end

    test "error", context do
      client = tcp_client(context)
      http1_handshake(client, Storex.Handler.Plug)

      send_text_frame(client, """
      {
        "type": "join",
        "store": "StorexTest.Store.ErrorInit",
        "data": {},
        "request": "#{random_string()}"
      }
      """)

      {:ok, result} = recv_text_frame(client)

      assert %{error: "Unauthorized", type: "error"} = Jason.decode!(result, keys: :atoms)
    end

    test "not existing store", context do
      client = tcp_client(context)
      http1_handshake(client, Storex.Handler.Plug)

      send_text_frame(client, """
      {
        "type": "join",
        "store": "StorexTest.Store.NotExisting",
        "data": {},
        "request": "#{random_string()}"
      }
      """)

      assert recv_connection_close_frame(client) ==
               {:ok,
                <<4001::16,
                  "Store 'StorexTest.Store.NotExisting' is not defined or can't be compiled."::binary>>}
    end

    test "without store", context do
      client = tcp_client(context)
      http1_handshake(client, Storex.Handler.Plug)

      send_text_frame(client, """
      {
        "type": "join",
        "store": null,
        "data": {},
        "request": "#{random_string()}"
      }
      """)

      assert recv_connection_close_frame(client) ==
               {:ok, <<4000::16, "Store is not set."::binary>>}
    end
  end

  describe "mutate" do
    test "success", context do
      client = tcp_client(context)
      http1_handshake(client, Storex.Handler.Plug)

      send_text_frame(client, """
      {
        "type": "join",
        "store": "StorexTest.Store.Counter",
        "data": {},
        "request": "#{random_string()}"
      }
      """)

      {:ok, result} = recv_text_frame(client)

      assert %{session: session} = Jason.decode!(result, keys: :atoms)

      send_text_frame(client, """
      {
        "type": "mutation",
        "store": "StorexTest.Store.Counter",
        "session": "#{session}",
        "data": {
          "name": "increase",
          "data": []
        },
        "request": "#{random_string()}"
      }
      """)

      {:ok, result} = recv_text_frame(client)

      assert %{
               diff: [%{p: ["counter"], a: "u", t: 1}],
               store: "StorexTest.Store.Counter",
               type: "mutation"
             } =
               Jason.decode!(result, keys: :atoms)
    end

    test "not existing mutation", context do
      client = tcp_client(context)
      http1_handshake(client, Storex.Handler.Plug)

      send_text_frame(client, """
      {
        "type": "join",
        "store": "StorexTest.Store.Counter",
        "data": {},
        "request": "#{random_string()}"
      }
      """)

      {:ok, result} = recv_text_frame(client)

      assert %{session: session} = Jason.decode!(result, keys: :atoms)

      send_text_frame(client, """
      {
        "type": "mutation",
        "store": "StorexTest.Store.Counter",
        "session": "#{session}",
        "data": {
          "name": "not_existing",
          "data": []
        },
        "request": "#{random_string()}"
      }
      """)

      {:ok, result} = recv_text_frame(client)

      assert %{
               error:
                 "No mutation matching \"not_existing\" with data [] in store StorexTest.Store.Counter",
               type: "error"
             } =
               Jason.decode!(result, keys: :atoms)
    end
  end

  describe "unknown message types" do
    test "an error frame is refused with 1007", context do
      client = tcp_client(context)
      http1_handshake(client, Storex.Handler.Plug)

      # `error` frames only travel server to client. This one used to pass
      # `Storex.Message.cast/1` and then crash `message_handle/2`.
      send_text_frame(client, """
      {
        "type": "error",
        "store": "StorexTest.Store.Counter",
        "data": null,
        "request": "#{random_string()}",
        "session": "#{random_string()}"
      }
      """)

      assert recv_connection_close_frame(client) ==
               {:ok, <<1007::16, "Payload is malformed."::binary>>}
    end
  end

  describe "binary frames" do
    test "are rejected with 1003", context do
      client = tcp_client(context)
      http1_handshake(client, Storex.Handler.Plug)

      send_binary_frame(client, :erlang.term_to_binary(%{type: "ping", request: "r"}))

      assert recv_connection_close_frame(client) ==
               {:ok, <<1003::16, "Binary frames are not supported."::binary>>}
    end

    test "cannot create atoms", context do
      client = tcp_client(context)
      http1_handshake(client, Storex.Handler.Plug)

      name = "storex_binary_frame_probe_#{System.unique_integer([:positive])}"

      # External term format for an atom that does not exist in this VM yet. It
      # is built by hand because `:erlang.term_to_binary/1` would create the atom
      # here first, in the test process.
      send_binary_frame(client, <<131, 118, byte_size(name)::16, name::binary>>)

      assert recv_connection_close_frame(client) ==
               {:ok, <<1003::16, "Binary frames are not supported."::binary>>}

      assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
    end
  end

  describe "keepalive" do
    test "a ping is answered with a pong carrying the same request id", context do
      client = tcp_client(context)
      http1_handshake(client, Storex.Handler.Plug)

      request = random_string()

      send_text_frame(client, """
      {
        "type": "ping",
        "request": "#{request}"
      }
      """)

      {:ok, result} = recv_text_frame(client)

      assert %{type: "pong", request: ^request} = Jason.decode!(result, keys: :atoms)
    end

    test "a ping does not need a store to be joined", context do
      client = tcp_client(context)
      http1_handshake(client, Storex.Handler.Plug)

      send_text_frame(client, ~s({"type": "ping", "request": "#{random_string()}"}))

      assert {:ok, _} = recv_text_frame(client)
    end
  end

  describe "session cleanup" do
    test "closing the connection stops the session's stores", context do
      client = tcp_client(context)
      http1_handshake(client, Storex.Handler.Plug)

      send_text_frame(client, """
      {
        "type": "join",
        "store": "StorexTest.Store.Counter",
        "data": {},
        "request": "#{random_string()}"
      }
      """)

      {:ok, result} = recv_text_frame(client)
      assert %{session: session} = Jason.decode!(result, keys: :atoms)

      store_pid = Storex.Registry.get_store_pid("StorexTest.Store.Counter", session)
      assert is_pid(store_pid)

      :gen_tcp.close(client)

      assert Enum.reduce_while(1..200, false, fn _, _ ->
               if Storex.Registry.session_stores(session) == [] do
                 {:halt, true}
               else
                 Process.sleep(10)
                 {:cont, false}
               end
             end),
             "the session's registry rows were not cleaned up"

      refute Process.alive?(store_pid)
    end
  end

  describe "shared scope" do
    test "a mutation by one session is pushed to the others sharing the store", context do
      room = "room-#{random_string()}"

      a = tcp_client(context)
      http1_handshake(a, Storex.Handler.Plug)

      b = tcp_client(context)
      http1_handshake(b, Storex.Handler.Plug)

      [session_a, _session_b] =
        for client <- [a, b] do
          send_text_frame(client, """
          {
            "type": "join",
            "store": "StorexTest.Store.Room",
            "data": {"room": "#{room}"},
            "request": "#{random_string()}"
          }
          """)

          {:ok, joined} = recv_text_frame(client)

          assert %{type: "join", data: %{counter: 0}, session: session} =
                   Jason.decode!(joined, keys: :atoms)

          session
        end

      request = random_string()

      send_text_frame(a, """
      {
        "type": "mutation",
        "store": "StorexTest.Store.Room",
        "data": {"name": "increase", "data": []},
        "session": "#{session_a}",
        "request": "#{request}"
      }
      """)

      # The mutating session gets the diff as the reply to its own request.
      {:ok, reply} = recv_text_frame(a)

      assert %{type: "mutation", request: ^request, diff: diff} =
               Jason.decode!(reply, keys: :atoms)

      assert Enum.any?(diff, &match?(%{a: "u", p: ["counter"], t: 1}, &1))

      # The other one is pushed the same diff, with no request to resolve.
      {:ok, pushed} = recv_text_frame(b)

      assert %{type: "mutation", request: nil, diff: ^diff, store: "StorexTest.Store.Room"} =
               Jason.decode!(pushed, keys: :atoms)
    end

    test "joining without the scope param is an error frame, not a close", context do
      client = tcp_client(context)
      http1_handshake(client, Storex.Handler.Plug)

      send_text_frame(client, """
      {
        "type": "join",
        "store": "StorexTest.Store.Room",
        "data": {},
        "request": "#{random_string()}"
      }
      """)

      {:ok, result} = recv_text_frame(client)

      assert %{type: "error", error: error} = Jason.decode!(result, keys: :atoms)
      assert error =~ "scoped by param \"room\""
    end
  end

  # Simple WebSocket client

  def tcp_client(context) do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", context[:port], active: false, mode: :binary)

    socket
  end

  def http1_handshake(client, module, params \\ []) do
    params = params |> Keyword.put(:websock, module)

    :gen_tcp.send(client, """
    GET /?#{URI.encode_query(params)} HTTP/1.1\r
    Host: server.example.com\r
    Upgrade: websocket\r
    Connection: Upgrade\r
    Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r
    Sec-WebSocket-Version: 13\r
    \r
    """)

    {:ok, response} = :gen_tcp.recv(client, 234)

    [
      "HTTP/1.1 101 Switching Protocols",
      "cache-control: max-age=0, private, must-revalidate",
      "connection: Upgrade",
      "date: " <> _date,
      "sec-websocket-accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=",
      "server: Cowboy",
      "upgrade: websocket",
      "",
      ""
    ] = String.split(response, "\r\n")
  end
end
