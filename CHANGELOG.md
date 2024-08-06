# storex

## 0.5.0

- **[BREAKING]** Frontend client fully rewritten
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
