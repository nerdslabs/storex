defmodule StorexTest.Browser.Plug do
  use ExUnit.Case
  use Wallaby.DSL

  import Wallaby.Query, only: [css: 1, css: 2]

  @port 9998

  setup_all do
    Supervisor.start_link(
      [{Plug.Cowboy, scheme: :http, plug: MyApp.Browser.Plug, port: @port}],
      strategy: :one_for_one,
      name: StorexTest.Supervisor
    )

    :ok
  end

  setup do
    {:ok, session} = Wallaby.start_session()

    %{session: session}
  end

  test "test connected", %{session: session} do
    session
    |> visit("http://localhost:#{@port}/")
    |> assert_has(css(".counter-connected", text: "true"))
  end

  test "basic state", %{session: session} do
    session
    |> visit("http://localhost:#{@port}/")
    |> assert_has(css(".counter-value", text: "0"))
  end

  test "increase state browser", %{session: session} do
    session
    |> visit("http://localhost:#{@port}/")
    |> click(css(".increase"))
    |> assert_has(css(".counter-value", text: "1"))
  end

  test "increase state elixir", %{session: session} do
    session =
      session
      |> visit("http://localhost:#{@port}/")
      |> assert_has(css(".counter-connected", text: "true"))

    Storex.mutate("StorexTest.Store.Counter", "increase", [])

    session
    |> assert_has(css(".counter-value", text: "1"))
  end

  test "decrease state browser reply", %{session: session} do
    session
    |> visit("http://localhost:#{@port}/")
    |> click(css(".decrease"))
    |> assert_has(css(".reply", text: "decreased"))
  end

  test "set text state", %{session: session} do
    session
    |> visit("http://localhost:#{@port}/")
    |> fill_in(css(".input-text"), with: "John Doe")
    |> click(css(".text-send"))
    |> assert_has(css(".text-value", text: "John Doe"))
  end

  test "test join error", %{session: session} do
    session
    |> visit("http://localhost:#{@port}/")
    |> assert_has(css(".error-message", text: "Unauthorized"))
  end

  def sleep(session, time \\ 10000) do
    Process.sleep(time)

    session
  end
end
