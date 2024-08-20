defmodule StorexTest.Plug do
  use ExUnit.Case

  test ":upgraded Bandit" do
    options = Storex.Plug.init()

    response =
      %Plug.Conn{
        adapter:
          {Bandit.Adapter,
           %Bandit.Adapter{
             transport: %Bandit.HTTP1.Socket{version: :"HTTP/1.1"},
             opts: %{websocket: []}
           }}
      }
      |> Map.put(:method, "GET")
      |> Map.put(:request_path, "/storex")
      |> Map.update!(:req_headers, &[{"host", "server.example.com"} | &1])
      |> Plug.Conn.put_req_header("upgrade", "WebSocket")
      |> Plug.Conn.put_req_header("connection", "Upgrade")
      |> Plug.Conn.put_req_header("sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ==")
      |> Plug.Conn.put_req_header("sec-websocket-version", "13")
      |> Storex.Plug.call(options)

    assert %{state: :upgraded} = response
  end

  test ":upgraded Cowboy" do
    options = Storex.Plug.init()

    response =
      %Plug.Conn{adapter: {Plug.Cowboy.Conn, %{version: :"HTTP/1.1"}}}
      |> Map.put(:method, "GET")
      |> Map.put(:request_path, "/storex")
      |> Map.update!(:req_headers, &[{"host", "server.example.com"} | &1])
      |> Plug.Conn.put_req_header("upgrade", "WebSocket")
      |> Plug.Conn.put_req_header("connection", "Upgrade")
      |> Plug.Conn.put_req_header("sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ==")
      |> Plug.Conn.put_req_header("sec-websocket-version", "13")
      |> Storex.Plug.call(options)

    assert %{state: :upgraded} = response
  end

  test ":set Cowboy" do
    options = Storex.Plug.init()

    response =
      %Plug.Conn{adapter: {Plug.Cowboy.Conn, %{version: :"HTTP/1.1"}}}
      |> Map.put(:method, "GET")
      |> Map.put(:request_path, "/storex")
      |> Map.put(:query_string, "store=StorexTest.Store.Counter&params=%7B%7D")
      |> Map.update!(:req_headers, &[{"host", "server.example.com"} | &1])
      |> Storex.Plug.call(options)

    assert %{
             resp_body: body,
             status: 200
           } = response

    assert %{
             "data" => %{"counter" => 0},
             "session" => "SSR",
             "store" => "StorexTest.Store.Counter",
             "type" => "join"
           } = Jason.decode!(body)
  end

  test ":unset with POST" do
    options = Storex.Plug.init()

    response =
      %Plug.Conn{
        adapter:
          {Bandit.Adapter,
           %Bandit.Adapter{
             transport: %Bandit.HTTP1.Socket{version: :"HTTP/1.1"},
             opts: %{websocket: []}
           }}
      }
      |> Map.put(:method, "POST")
      |> Map.put(:request_path, "/storex")
      |> Map.update!(:req_headers, &[{"host", "server.example.com"} | &1])
      |> Plug.Conn.put_req_header("upgrade", "WebSocket")
      |> Plug.Conn.put_req_header("connection", "Upgrade")
      |> Plug.Conn.put_req_header("sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ==")
      |> Plug.Conn.put_req_header("sec-websocket-version", "13")
      |> Storex.Plug.call(options)

    assert %{state: :unset} = response
  end
end
