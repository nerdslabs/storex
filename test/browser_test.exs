defmodule StorexTest.Browser do
  use ExUnit.Case
  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1, css: 2]

  setup_all do
    dispatch =
      :cowboy_router.compile([
        {:_,
         [
           {"/static/[...]", :cowboy_static, {:dir, "priv/static"}},
           {"/storex", Storex.Socket.Handler, []},
           {:_, StorexTest.Browser.Handler, []}
         ]}
      ])

    {:ok, _} =
      :cowboy.start_clear(:test_http, [{:port, 9999}], %{
        :env => %{dispatch: dispatch}
      })

    :ok
  end

  setup do
    {:ok, session} = Wallaby.start_session()

    %{session: session}
  end

  test "test connected", %{session: session} do
    session
    |> visit("http://localhost:9999/")
    |> assert_has(css(".counter-connected", text: "true"))
  end

  test "basic state", %{session: session} do
    session
    |> visit("http://localhost:9999/")
    |> assert_has(css(".counter-value", text: "0"))
  end

  test "increase state browser", %{session: session} do
    session
    |> visit("http://localhost:9999/")
    |> click(css(".increase"))
    |> assert_has(css(".counter-value", text: "1"))
  end

  test "increase state elixir", %{session: session} do
    session = session
    |> visit("http://localhost:9999/")

    session_id = session |> text(css(".session"))

    Storex.mutate(session_id, "StorexTest.Store.Counter", "increase")

    session
    |> assert_has(css(".counter-value", text: "1"))
  end

  test "decrease state browser reply", %{session: session} do
    session
    |> visit("http://localhost:9999/")
    |> click(css(".decrease"))
    |> assert_has(css(".reply", text: "decreased"))
  end

  test "set text state", %{session: session} do
    session
    |> visit("http://localhost:9999/")
    |> fill_in(css(".input-text"), with: "John Doe")
    |> click(css(".text-send"))
    |> assert_has(css(".text-value", text: "John Doe"))
  end
end
