defmodule StorexTest.Browser do
  use ExUnit.Case
  use Hound.Helpers

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

  hound_session()

  test "test connected", _meta do
    navigate_to("http://localhost:9999/")

    :timer.sleep(500)

    connected = find_element(:class, "connected")

    assert inner_html(connected) == "true"
  end

  test "basic state", _meta do
    navigate_to("http://localhost:9999/")

    :timer.sleep(500)

    counter = find_element(:class, "counter")

    assert inner_html(counter) == "0"
  end

  test "increase state browser", _meta do
    navigate_to("http://localhost:9999/")

    :timer.sleep(500)

    find_element(:class, "increase")
    |> click()

    :timer.sleep(500)

    counter = find_element(:class, "counter")

    assert inner_html(counter) == "1"
  end

  test "increase state elixir", _meta do
    navigate_to("http://localhost:9999/")

    :timer.sleep(500)

    session = find_element(:class, "session") |> inner_html()

    Storex.mutate(session, "StorexTest.Store.Counter", "increase")

    :timer.sleep(500)

    counter = find_element(:class, "counter")

    assert inner_html(counter) == "1"
  end

  test "decrease state browser reply", _meta do
    navigate_to("http://localhost:9999/")

    :timer.sleep(500)

    find_element(:class, "decrease")
    |> click()

    :timer.sleep(500)

    reply = find_element(:class, "reply")

    assert inner_html(reply) == "decreased"
  end
end
