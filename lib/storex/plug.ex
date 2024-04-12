defmodule Storex.Plug do
  import Plug.Conn

  @moduledoc """
  Add Storex to your Plug application, to handle WebSocket connections.

  Example for Phoenix Endpoint:

  ```elixir
  defmodule YourAppWeb.Endpoint do
    use Phoenix.Endpoint, otp_app: :your_app

    plug Storex.Plug

    # ...
  end
  ```

  ## Options

  - `:path` - The path to mount the Storex handler. Default is `"/storex"`.
  """

  @doc false
  def init(options \\ []) do
    [
      path: Keyword.get(options, :path, "/storex")
    ]
  end

  @doc false
  def call(%{method: "GET", request_path: path} = conn, path: path) do
    conn
    |> WebSockAdapter.upgrade(Storex.Handler.Plug, [], timeout: 60_000)
    |> halt()
  end

  @doc false
  def call(conn, _) do
    conn
  end
end
