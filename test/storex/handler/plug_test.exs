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
