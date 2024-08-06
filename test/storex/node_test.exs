defmodule StorexTest.Node do
  use ExUnit.Case

  @port 9996

  setup_all do
    Bandit.start_link(plug: MyApp.Browser.Plug, port: @port, startup_log: false)

    :ok
  end

  test "test connected" do
    result = run_store("StorexTest.Store.Counter")

    assert result == %{"error" => nil, "state" => %{"counter" => 0}}
  end

  test "test error" do
    result = run_store("StorexTest.Store.ErrorInit")

    assert result == %{"error" => "Unauthorized", "state" => nil}
  end

  defp run_store(store, params \\ %{}) do
    {result, _} =
      System.cmd("node", [
        "--input-type=module",
        "--trace-uncaught",
        "-e",
        "import run from './test/fixtures/node.mjs'; run('#{store}', '#{Jason.encode!(params)}')"
      ])

    Jason.decode!(result)
  end
end
