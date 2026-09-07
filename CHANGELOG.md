# storex

## 0.7.0

- **[BREAKING]** Updated the minimum required version of Elixir to `1.16`
- Fix type warnings emitted by `use Storex.Store` on Elixir 1.18 and newer
- **[BREAKING]** A `FunctionClauseError` raised inside a mutation that *did* match is no longer reported to the client as `No mutation matching ...`. Only the store's own `mutation/5` failing to match produces that error; anything else propagates with its original stacktrace, which stops the store process and the socket with it
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
