defmodule MyApp.Browser.Plug do
  use Plug.Router

  plug(Plug.Static,
    at: "/static",
    from: "priv/static"
  )

  plug(Storex.Plug, path: "/storex")

  plug(:match)
  plug(:dispatch)

  get "/" do
    {:ok, file} = File.read("./test/fixtures/browser/browser_test.html")

    send_resp(conn, 200, file)
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end
