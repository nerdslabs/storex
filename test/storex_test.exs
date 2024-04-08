defmodule StorexTest do
  use ExUnit.Case
  doctest Storex

  setup_all do
    %{
      session: Application.get_env(:storex, :session_id_library, Nanoid).generate(),
      store: "StorexTest.Store.Counter"
    }
  end

  test "create store", %{session: session, store: store} do
    assert {:ok, _pid} = Storex.Supervisor.add_store(session, store, %{})
  end

  test "get store", %{session: session, store: store} do
    assert %{counter: 0} = Storex.Supervisor.get_store_state(session, store)
  end

  test "mutate store", %{session: session, store: store} do
    Storex.Supervisor.mutate_store(session, store, "increase", [])

    assert %{counter: 1} = Storex.Supervisor.get_store_state(session, store)
  end
end
