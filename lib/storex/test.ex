defmodule Storex.Test do
  @moduledoc """
  Drives a store from a test, with no socket and no browser.

  Everything a store does is reachable through `Storex.Supervisor` and
  `Storex.Registry`, but both are `@moduledoc false` — a test written against
  them is written against internals that are free to move. This is the supported
  way.

      defmodule MyApp.Store.CounterTest do
        use ExUnit.Case

        test "increasing counts up" do
          store = Storex.Test.start_store!(MyApp.Store.Counter)

          assert {:ok, result} = Storex.Test.commit(store, "increase")

          assert result.state == %{counter: 1}
          assert result.diff == [%{a: "u", p: [:counter], t: 1}]
        end
      end

  `result.diff` is the reason this exists. The diff is the contract with the
  frontend — it is what actually goes over the wire — and it is the part a store
  author cannot otherwise get at without a browser.

  ## The calling process is the session

  A store started here registers the calling process as its session, the way a
  socket process would. That is what makes `broadcast/4` able to observe a
  `Storex.mutate/3` fan-out, and it means a store is cleaned up when the test
  ends: `start_store/2` registers an `ExUnit` `on_exit` callback that calls
  `stop/1`. Outside ExUnit nothing is registered and `stop/1` is yours to call.
  """

  @enforce_keys [:store, :session, :key]
  defstruct [:store, :session, :key]

  @type t :: %__MODULE__{store: binary(), session: binary(), key: binary() | nil}

  @type result :: %{state: any(), diff: list(), message: any()}

  @doc """
  Starts a store and attaches the calling process to it as a session.

  Takes the store module, or the name a client would send. Options:

  - `:params` - the params `init/2` is given. Defaults to `%{}`. Keys are
    binaries, as they are when they arrive from a client.
  - `:session` - the session id. Defaults to a unique one per call.
  - `:session_pid` - the process standing in for the socket. Defaults to the
    caller, which is what `broadcast/4` needs.

  Returns `{:error, reason}` when the store's `init/2` does, so that refusing to
  start is testable.
  """
  @spec start_store(module() | binary(), keyword()) :: {:ok, t()} | {:error, any()}
  def start_store(store, opts \\ []) do
    store = name(store)
    session = Keyword.get_lazy(opts, :session, &unique_session/0)
    session_pid = Keyword.get(opts, :session_pid, self())
    params = Keyword.get(opts, :params, %{})

    case Storex.Supervisor.add_store(store, session, session_pid, params) do
      {:ok, key} ->
        handle = %__MODULE__{store: store, session: session, key: key}
        cleanup(handle)
        {:ok, handle}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Same as `start_store/2`, raising when the store refuses to start.
  """
  @spec start_store!(module() | binary(), keyword()) :: t()
  def start_store!(store, opts \\ []) do
    case start_store(store, opts) do
      {:ok, handle} ->
        handle

      {:error, reason} ->
        raise "store #{inspect(name(store))} did not start: #{inspect(reason)}"
    end
  end

  @doc """
  The store's current state.

  Raises if the store is not running, which in a test is a failure rather than
  an outcome to assert on.
  """
  @spec state(t()) :: any()
  def state(%__MODULE__{} = handle) do
    case Storex.Supervisor.get_store_state(handle.session, handle.store) do
      {:ok, state} -> state
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Runs a mutation, the way a `commit` from the client does.

  Returns `{:ok, result}` where `result` is a map of:

  - `:state` - the store's state after the mutation
  - `:diff` - the diff the client would have been sent
  - `:message` - the reply from `{:reply, message, state}`, or `nil`

  `{:error, reason}` is what the client would have received as an error frame:
  a mutation returning `{:error, reason}`, a name no clause matches, or an
  unsupported return value.
  """
  @spec commit(t(), binary(), any()) :: {:ok, result()} | {:error, any()}
  def commit(%__MODULE__{} = handle, name, data \\ []) do
    Storex.Supervisor.mutate_store(handle.session, handle.store, name, data)
    |> case do
      {:ok, diff} -> {:ok, result(handle, diff, nil)}
      {:ok, message, diff} -> {:ok, result(handle, diff, message)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Same as `commit/3`, raising when the mutation errors.
  """
  @spec commit!(t(), binary(), any()) :: result()
  def commit!(%__MODULE__{} = handle, name, data \\ []) do
    case commit(handle, name, data) do
      {:ok, result} -> result
      {:error, reason} -> raise "mutation #{inspect(name)} failed: #{inspect(reason)}"
    end
  end

  @doc """
  Runs a mutation the way `Storex.mutate/3` and `Storex.mutate/4` do, through
  the cluster fan-out, and applies what comes back.

  `Storex.mutate/3` broadcasts over `:pg` and sends the mutation to each
  session's *socket* process, which is what normally turns it into a call on the
  store. There is no socket here, so this waits for that message and applies it,
  giving back the same result as `commit/3`.

  Options:

  - `:key` - filter on the key `init/2` returned, as `Storex.mutate/4` does.
  - `:timeout` - how long to wait for the fan-out. Defaults to 1000ms.

  Requires the session pid to be the calling process, which is the default.
  Returns `{:error, :timeout}` when nothing arrives, which is the assertion for
  a store the fan-out should *not* have reached.
  """
  @spec broadcast(t(), binary(), any(), keyword()) :: {:ok, result()} | {:error, any()}
  def broadcast(%__MODULE__{} = handle, name, data \\ [], opts \\ []) do
    store = handle.store
    timeout = Keyword.get(opts, :timeout, 1000)

    case Keyword.fetch(opts, :key) do
      {:ok, key} -> Storex.mutate(key, store, name, data)
      :error -> Storex.mutate(store, name, data)
    end

    receive do
      {:mutate, ^store, ^name, payload} -> commit(handle, name, payload)
    after
      timeout -> {:error, :timeout}
    end
  end

  @doc """
  Stops the store, running `terminate/3` if it defines one.

  Waits for the process to go down, so a test can assert on what `terminate/3`
  did on the line after. `Storex.Supervisor.remove_store/2` is a cast, and
  asserting on its effects without waiting is a race.
  """
  @spec stop(t(), timeout()) :: :ok
  def stop(%__MODULE__{} = handle, timeout \\ 1000) do
    case Storex.Registry.get_store_pid(handle.store, handle.session) do
      :undefined ->
        :ok

      pid ->
        reference = Process.monitor(pid)
        Storex.Supervisor.remove_store(handle.session, handle.store)

        receive do
          {:DOWN, ^reference, :process, ^pid, _reason} -> :ok
        after
          timeout ->
            Process.demonitor(reference, [:flush])
            :ok
        end
    end
  end

  defp result(handle, diff, message) do
    %{state: state(handle), diff: diff, message: message}
  end

  defp name(store) when is_atom(store), do: inspect(store)
  defp name(store) when is_binary(store), do: store

  defp unique_session, do: "storex-test-#{System.unique_integer([:positive])}"

  # A store outlives the process that started it — `Storex.Registry` monitors the
  # store, not the session — so without this every test that starts one leaks a
  # process for the rest of the run. Reached through `apply/3` so that this
  # module carries no compile-time reference to ExUnit, which is not there in
  # the environments the library is actually built for.
  defp cleanup(handle) do
    if Code.ensure_loaded?(ExUnit.Callbacks) do
      apply(ExUnit.Callbacks, :on_exit, [fn -> stop(handle) end])
    end

    :ok
  rescue
    # `on_exit/1` raises when it is not called from a test process.
    ArgumentError -> :ok
  end
end
