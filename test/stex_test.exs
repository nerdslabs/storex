defmodule StexTest do
  use ExUnit.Case
  doctest Stex

  setup_all do
    %{
      session: Application.get_env(:stex, :session_id_library, Nanoid).generate(),
      store: "StexTest.Store.Counter"
    }
  end

  test "create store", %{session: session, store: store} do
    assert {:ok, _pid} = Stex.Supervisor.add_store(session, store, %{})
  end

  test "get store", %{session: session, store: store} do
    assert %{counter: 0} = Stex.Supervisor.get_store(session, store)
  end

  test "mutate store", %{session: session, store: store} do
    Stex.Supervisor.mutate_store(session, store, "increase", [])

    assert %{counter: 1} = Stex.Supervisor.get_store(session, store)
  end
end
