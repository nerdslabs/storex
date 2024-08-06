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
    |> fetch_query_params()
    |> handle()
  end

  @doc false
  def call(conn, _) do
    conn
  end

  def handle(
        %{
          method: "GET",
          query_params: %{"store" => encoded_store, "params" => encoded_params}
        } = conn
      ) do
    store = encoded_store |> URI.decode()

    with {:store, {:ok, store}} <- {:store, store |> Storex.HTTP.get_module()},
         {:params, {:ok, params}} <- {:params, encoded_params |> Storex.HTTP.get_params()},
         {:state, {:ok, result}} <- {:state, Storex.HTTP.get_state(store, params)} do
      response = %{
        type: "join",
        session: "SSR",
        store: store,
        data: result
      }
      |> Jason.encode!()

      resp(conn, 200, response)
    else
      {:store, {:error, _}} ->
        response = %{
          type: "error",
          session: "SSR",
          store: store,
          error: "Store '#{inspect(store)}' is not defined or can't be compiled."
        }
        |> Jason.encode!()

        resp(conn, 400, response)

      {:state, {:error, message}} ->
        response = %{
          type: "error",
          session: "SSR",
          store: store,
          error: message
        }
        |> Jason.encode!()

        resp(conn, 400, response)

      _ ->
        response = %{
          type: "error",
          session: "SSR",
          store: store,
          error: "Unknown error"
        }
        |> Jason.encode!()

        resp(conn, 400, response)
    end
    |> put_resp_content_type("application/json")
    |> halt()
  end

  @doc false
  def handle(%{method: "GET"} = conn) do
    conn
    |> WebSockAdapter.upgrade(Storex.Handler.Plug, [], timeout: 60_000)
    |> halt()
  end

  @doc false
  def handle(conn) do
    conn
  end
end
