# storex

## 0.7.0

- **[BREAKING]** Updated the minimum required version of Elixir to `1.16`
- Fix type warnings emitted by `use Storex.Store` on Elixir 1.18 and newer
- **[BREAKING]** A `FunctionClauseError` raised inside a mutation that *did* match is no longer reported to the client as `No mutation matching ...`. Only the store's own `mutation/5` failing to match produces that error; anything else propagates with its original stacktrace, which stops the store process and the socket with it
- `terminate/3` is no longer skipped when the store module happens not to be loaded yet. `Storex.Store.__terminate__/4` gated the call on `function_exported?/3`, which answers `false` for an unloaded module, so whether the callback ran depended on the code server rather than on the store
- Housekeeping: dropped the unused `import Supervisor.Spec, warn: false` from `Storex.start/2` (deprecated since Elixir 1.5, and the `warn: false` was hiding it) and the `registry: Storex.Registry.ETS` key from `config/config.exs` (that module was removed in 0.4.0 and nothing read the key). The project is now formatted, and CI checks it
- `Storex.Registry` reads (`get_store/2`, `get_store_pid/2`, `get_store_instances/1`, `session_stores/1`) now run in the calling process against the `:protected` ETS table instead of a `GenServer.call`. The registry process was a global serialisation point — every mutation performs at least one lookup — and the cost grew with the number of connections. Measured at 500 lookups per reader: 98.3ms against 16.2ms with 64 concurrent readers, 335.8ms against 56.2ms with 256. Writes and the `:DOWN` cleanup still go through the process
- **[BREAKING]** `Storex.mutate/3` and `Storex.mutate/4` return `:ok`. They used to return whatever the comprehension in `Storex.PG.broadcast/1` produced, which was the internal broadcast envelope repeated once per node (`[broadcast: {:mutate, "Store", "reload", []}]`)
- Removed the unreachable `{:error, _}` branch in `Storex.PG.broadcast/1`. `:pg.get_members/2` always returns a list; the error tuple was `:pg2`'s contract, and `:pg2` support went away in this release
- The state a store reports on join is now read by asking the store process (`handle_call(:get_state, ...)` on the generated `Server`) instead of `:sys.get_state/1`, a debug function that was reaching into the process's internal state shape from the outside on every join. If the process is gone by the time the join reads it, the client now gets an error frame instead of the connection exiting
- A client could kill its connection process with a well-formed `error` frame: `Storex.Message.cast/1` accepted the shape but `Storex.Socket.message_handle/2` had no clause for it. `error` frames only travel server to client, so the shape is no longer accepted and the frame is refused with `1007` like any other unknown type
- `Storex.Handler.Plug` closed a malformed payload with a bare `1007`, passing the reason as the process exit reason instead of the close payload. It now sends `1007` with the reason, matching `Storex.Handler.Cowboy`
- Removed dead code: `Storex.Registry.session_pid/1` (no callers, and its `:ets.match/2` pattern was a 4-tuple against 5-tuple records, so it never matched anything) and `Storex.Handler.Cowboy.websocket_init/3` (a cowboy 1.x callback, unreachable on cowboy 2.x)
- **[SECURITY]** The SSR/HTTP path now runs the same store-name checks as the WebSocket path. `Storex.HTTP` carried its own copy of the resolution logic with only `Module.safe_concat/1`, missing `Code.ensure_compiled/1` and the `Storex.Store` behaviour check, so `GET /storex?store=Any.Module&params=%7B%7D` called `init/2` on any loaded module whose name resolved and serialised the result back to the caller. Both transports now share `Storex.Store.resolve/1`
- **[BREAKING]** **[SECURITY]** `Storex.Handler.Cowboy` no longer accepts `:binary` frames. It decoded them with `:erlang.binary_to_term/1`, which creates atoms out of bytes the client controls — a single 25-byte frame is enough — and passed the resulting term straight to `Storex.Socket.message_handle/2`, bypassing the `Storex.Message.cast/1` allowlist every other entry point goes through. Binary frames are now closed with `1003`
- `Storex.Handler.Plug` had no clause for `:binary` frames at all, so one raised `FunctionClauseError` and closed the connection with `1011`. It now closes with `1003` like the cowboy handler
- **[SECURITY]** A `mutation` frame is now resolved against the session the server assigned to the connection, not the `session` field carried by the frame. Any client could previously mutate — and read the resulting diff of — any other session's store by naming its session id. Mutating other sessions on purpose is what `Storex.mutate/3` and `Storex.mutate/4` are for
- A `mutation` for a store the session has not joined now returns an error to the client instead of exiting the connection process
- Store processes are now registered through a `Registry` keyed by `{session, store}` instead of being named `:"#{session}_#{store}"`. Session ids are unique per connection, so the old naming created one permanent atom per session-store pair and could exhaust the atom table on a long-running node
- Removed the `:pg2` fallback, unreachable since OTP 24
- Updated dependencies

## 0.6.1

- Add missing `cast` to `Storex.Message`

## 0.6.0

- **[BREAKING]** Keys of params in Store are now type `binary` instead of `atom`
- Added message validation with structured casting

## 0.5.1

- Fix frontend client type for `commit`

## 0.5.0

- **[BREAKING]** Frontend client fully rewritten
- **[BREAKING]** Updated the minimum required version of Elixir to `1.10`
- Added support for non browser environment

## 0.4.0

- **[BREAKING]** `Storex.mutate/3` is no longer based on `session_id`
- **[BREAKING]** `Store.init/2` callback now need to return `{:ok, state} | {:ok, state, key} | {:error, reason}`
- **[BREAKING]** Remove custom `Registry` logic
- **[BREAKING]** Remove `connection` callback from javascript client
- New registry mechanism provides distributed mutations across the cluster
- Fix `terminate` callback in `Storex.Handler.Plug`
- Added three callbacks to frontend client `onConnected`, `onError` and `onDisconnected`

## 0.3.0

- **[BREAKING]** Rename Cowbow handler module from `Storex.Socket.Handler` to `Storex.Handler.Cowboy`
- Add support for Plug based apps `plug Storex.Plug`
- Update Storex application supervisor children spec

## 0.2.5

- Fix diff of Date struct
- Rewrite tests from Hound to Wallaby

## 0.2.4

- Fix root state update
- Remove optional from jason dependency

## 0.2.3

- Fix reconnect of WebSocket on connection close

## 0.2.2

- Fix reconnect of WebSocket on connection close

## 0.2.1

- Typescript/Javascript improvements

## 0.2.0

- Dynamic registry declaration
- - Default registry on ETS
- Fix issue with a restart of Store when stopped on disconnect
- Update dependencies

## 0.1.0

- The only diff of the store state is being sent on each mutation.
- Subscriber of connection status
- Fixes in library
