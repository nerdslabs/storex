# Storex

![Elixir CI](https://github.com/nerdslabs/storex/workflows/Elixir%20CI/badge.svg) [![Downloads](https://img.shields.io/hexpm/dt/storex.svg)](https://hex.pm/packages/storex)

Frontend store with the state on the backend. You are able to mutate store state from the frontend and also from the backend. Whole communication going through WebSocket.

**Important:** Storex is under active development. Report issues and send proposals [here](https://github.com/nerdslabs/storex/issues/new).

Only diff of the store state is being sent on each mutation.

## Basic usage

### Installation

Add **storex** to deps in `mix.exs`:

```elixir
defp deps do
  [{:storex, "~> 0.4.0"}]
end
```

Also you need to add **storex** to `package.json` dependencies:

```javascript
{
  "storex": "file:../deps/storex",
}
```

### Add storex websocket handler

You need to add handler `Storex.Handler.Plug` or `Storex.Handler.Cowboy`.

**Phoenix:**
```elixir
defmodule YourAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :your_app

  plug Storex.Plug, path: "/storex"

  # ...
end
```

**Cowboy:**
```elixir
:cowboy_router.compile([
  {:_, [
    # ...
    {"/storex", Storex.Handler.Cowboy, []},
    # ...
  ]}
])
```

### Create store

To create a store you need to create new elixir module with `init/2` which is called when a page is loaded, every time websocket is connected it generates session_id and passes it as the first argument, params are from Javascript store declaration. `init/2` callback need to return one of this tuples:

- `{:ok, state}` - for initial state
- `{:ok, state, key}` - for initial state with `key` which can be used as selector for future mutations
- `{:error, reason}` - to send error message to frontend on initialization

Next, you can declare `mutation/5` where the first argument is mutation name, second is data passed to mutation, next two params are same like in `init/2`, the last one is the current state of the store.

```elixir
defmodule ExampleApp.Store.Counter do
  use Storex.Store

  def init(session_id, params) do
    {:ok, 0}
  end

  # `increase` is mutation name, `data` is payload from front-end, `session_id` is current session id of connecton, `initial_params` with which store was initialized, `state` is store current state.
  def mutation("increase", _data, _session_id, _initial_params, state) do
    state = state + 1

    {:noreply, state}
  end

  def mutation("decrease", _data, _session_id, _initial_params, state) do
    state = state - 1

    {:reply, "message", state}
  end

  def mutation("set", [number], _session_id, _initial_params, state) do
    {:noreply, number}
  end
end
```

### Connect to store

You have to connect the newly created store with a frontend side to be able to synchronise the state: `params` are passed as second argument in store `init/2` and as third in `mutation/5`. You can subscribe to changes inside store state by passing option `subscribe` with function as a value.

```javascript
import Storex from 'storex'

const store = new Storex({
  store: 'ExampleApp.Store.Counter',
  params: {},
  subscribe: (state) => {
    console.log(state)
  },
  onConnected() {
    console.log('connected')
  },
  onError(error) {
    console.log('error', error)
  },
  onDisconnected(closeEvent) {
    console.log('disconnected', closeEvent)
  }
})
```

### Mutate store

You can mutate store from javascript with store instance:

```javascript
store.commit("increase")
store.commit("decrease").then((response) => {
  response // Reply from elixir
})
store.commit("set", 10)
```

Or directly from elixir:

```elixir
Storex.mutate(store, "increase", [])
Storex.mutate(store, "set", [10])
Storex.mutate(key, store, "increase", [])
Storex.mutate(key, store, "set", [10])
```

### Subscribe to store changes

You can subscribe to store state changes in javascript with function subscribe:

```javascript
store.subscribe((state) => {
  const state = state
})
```

You can also subscribe to events after store is created:

```javascript
store.onConnected(() => {
  console.log('connected')
})

store.onError((error) => {
  console.log('error', error)
})

store.onDisconnected((closeEvent) => {
  console.log('disconnected', closeEvent)
})
```

## Configuration

### Session id generation library

You can change library which generate session id for stores. Module needs to have **generate/0** method.

```elixir
config :storex, :session_id_library, Ecto.UUID
```

### Default params

You can set default params for all stores in Javascript which will be passed to store.

```javascript
Storex.defaults.params = {
  jwt: 'someJWT'
}
```

### Custom store address

```javascript
Storex.defaults.address = 'localhost/stores'
```