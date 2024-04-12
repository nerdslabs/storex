defmodule StorexTest.Handler.Cowboy do
  use ExUnit.Case, async: false

  import StorexTest.HandlerHelpers

  setup_all do
    dispatch =
      :cowboy_router.compile([
        {:_,
         [
           {"/storex", Storex.Handler.Cowboy, []}
         ]}
      ])

    {:ok, _} = :cowboy.start_clear(__MODULE__.HTTP, [{:port, 0}], %{env: %{dispatch: dispatch}})

    {:ok, port: :ranch.get_port(__MODULE__.HTTP)}
  end

  describe "init" do
    test "success", context do
      client = tcp_client(context)
      http1_handshake(client)

      send_text_frame(client, """
      {
        "type": "join",
        "store": "StorexTest.Store.Counter",
        "data": {}
      }
      """)

      {:ok, result} = recv_text_frame(client)

      assert %{data: %{counter: 0}, type: "join", store: "StorexTest.Store.Counter"} =
               Jason.decode!(result, keys: :atoms)
    end

    test "not existing store", context do
      client = tcp_client(context)
      http1_handshake(client)

      send_text_frame(client, """
      {
        "type": "join",
        "store": "StorexTest.Store.NotExisting",
        "data": {}
      }
      """)

      assert recv_connection_close_frame(client) ==
               {:ok,
                <<4001::16,
                  "Store 'StorexTest.Store.NotExisting' is not defined or can't be compiled."::binary>>}
    end

    test "without store", context do
      client = tcp_client(context)
      http1_handshake(client)

      send_text_frame(client, """
      {
        "type": "join",
        "store": null,
        "data": {}
      }
      """)

      assert recv_connection_close_frame(client) ==
               {:ok, <<4000::16, "Store is not set."::binary>>}
    end
  end

  describe "mutate" do
    test "success", context do
      client = tcp_client(context)
      http1_handshake(client)

      send_text_frame(client, """
      {
        "type": "join",
        "store": "StorexTest.Store.Counter",
        "data": {}
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
        }
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
      http1_handshake(client)

      send_text_frame(client, """
      {
        "type": "join",
        "store": "StorexTest.Store.Counter",
        "data": {}
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
        }
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

  # Simple WebSocket client

  def tcp_client(context) do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", context[:port], active: false, mode: :binary)

    socket
  end

  def http1_handshake(client) do
    :gen_tcp.send(client, """
    GET /storex HTTP/1.1\r
    Host: localhost\r
    Upgrade: websocket\r
    Connection: Upgrade\r
    Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r
    Sec-WebSocket-Version: 13\r
    \r
    """)

    {:ok, response} = :gen_tcp.recv(client, 0, 6000)

    [
      "HTTP/1.1 101 Switching Protocols",
      "connection: Upgrade",
      "date: " <> _,
      "sec-websocket-accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=",
      "server: Cowboy",
      "upgrade: websocket",
      "",
      ""
    ] = String.split(response, "\r\n")
  end
end
