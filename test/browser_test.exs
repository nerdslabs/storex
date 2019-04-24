defmodule StexTest.Browser do
  use ExUnit.Case
  use Hound.Helpers

  setup_all do
    dispatch = :cowboy_router.compile([
      {:_, [
        {"/static/[...]", :cowboy_static, {:dir, "priv/static"}},
        {"/stex", Stex.Socket.Handler, []},
        {:_, StexTest.Browser.Handler, []},
      ]}
    ])

    {:ok, _} = :cowboy.start_clear(:test_http, [{:port, 9999}], %{
      :env => %{dispatch: dispatch}
    })

    :ok
  end

  hound_session()

  test "basic state", _meta do
    navigate_to("http://localhost:9999/")

    :timer.sleep(1000)

    counter = find_element(:class, "counter")

    assert inner_html(counter) == "0"
  end

  test "increase state browser", _meta do
    navigate_to("http://localhost:9999/")

    :timer.sleep(1000)

    find_element(:class, "increase")
    |> click()

    :timer.sleep(1000)

    counter = find_element(:class, "counter")

    assert inner_html(counter) == "1"
  end

  test "increase state elixir", _meta do
    navigate_to("http://localhost:9999/")

    :timer.sleep(1000)

    session = find_element(:class, "session") |> inner_html()

    Stex.mutate(session, "StexTest.Store.Counter", "increase")

    :timer.sleep(1000)

    counter = find_element(:class, "counter")

    assert inner_html(counter) == "1"
  end

end
