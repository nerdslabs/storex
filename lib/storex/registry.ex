defmodule Storex.Registry do
  @callback register_session(session :: String.t(), pid()) :: {:ok, pid} | :error
  @callback unregister_session(session :: String.t()) :: :ok | :error
  @callback session_pid(session :: String.t()) :: pid() | :undefined
  @callback session_stores(session :: String.t()) :: [String.t()]
  @callback register_store(session :: String.t(), store :: String.t(), pid()) ::
              {:ok, pid} | :error
  @callback unregister_store(session :: String.t(), store :: String.t()) :: :ok | :error
  @callback get_store_pid(session :: String.t(), store :: String.t()) :: pid() | :undefined

  defp implementation() do
    Application.get_env(:storex, :registry, Storex.Registry.ETS)
  end

  def register_session(session, pid) do
    implementation()
    |> Kernel.apply(:register_session, [session, pid])
  end

  def unregister_session(session) do
    implementation()
    |> Kernel.apply(:unregister_session, [session])
  end

  def session_pid(session) do
    implementation()
    |> Kernel.apply(:session_pid, [session])
  end

  def register_store(session, store, pid) do
    implementation()
    |> Kernel.apply(:register_store, [session, store, pid])
  end

  def unregister_store(session, store) do
    implementation()
    |> Kernel.apply(:unregister_store, [session, store])
  end

  def get_store_pid(session, store) do
    implementation()
    |> Kernel.apply(:get_store_pid, [session, store])
  end

  def session_stores(session) do
    implementation()
    |> Kernel.apply(:session_stores, [session])
  end
end
