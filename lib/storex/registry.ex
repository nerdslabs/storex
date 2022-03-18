defmodule Storex.Registry do
  @doc """
  Register session PID with a `session` id.
  """
  @callback register_session(session :: String.t(), pid()) :: {:ok, pid} | :error

  @doc """
  Unregister session with a `session` id.
  """
  @callback unregister_session(session :: String.t()) :: :ok | :error

  @doc """
  Gets session PID by `session` id.
  """
  @callback session_pid(session :: String.t()) :: pid() | :undefined

  @doc """
  Return list of stores registered with `session` id.
  """
  @callback session_stores(session :: String.t()) :: [String.t()]

  @doc """
  Register store PID in `session` by id with `store` id.
  """
  @callback register_store(session :: String.t(), store :: String.t(), pid()) ::
              {:ok, pid} | :error

  @doc """
  Unegister store in `session` by id with `store` id.
  """
  @callback unregister_store(session :: String.t(), store :: String.t()) :: :ok | :error

  @doc """
  Returns store PID by `session` id and `store` id.
  """
  @callback get_store_pid(session :: String.t(), store :: String.t()) :: pid() | :undefined

  defp implementation() do
    Application.get_env(:storex, :registry, Storex.Registry.ETS)
  end

  @doc false
  def register_session(session, pid) do
    implementation()
    |> Kernel.apply(:register_session, [session, pid])
  end

  @doc false
  def unregister_session(session) do
    implementation()
    |> Kernel.apply(:unregister_session, [session])
  end

  @doc false
  def session_pid(session) do
    implementation()
    |> Kernel.apply(:session_pid, [session])
  end

  @doc false
  def register_store(session, store, pid) do
    implementation()
    |> Kernel.apply(:register_store, [session, store, pid])
  end

  @doc false
  def unregister_store(session, store) do
    implementation()
    |> Kernel.apply(:unregister_store, [session, store])
  end

  @doc false
  def get_store_pid(session, store) do
    implementation()
    |> Kernel.apply(:get_store_pid, [session, store])
  end

  @doc false
  def session_stores(session) do
    implementation()
    |> Kernel.apply(:session_stores, [session])
  end
end
