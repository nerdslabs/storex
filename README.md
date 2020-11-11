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
  [{:storex, "~> 0.1.0"}]
end
```

Also you need to add **storex** to `package.json` dependencies:

```javascript
{
  "storex": "file:../deps/storex",
}
```

### Add storex websocket handler

You need to add handler `Storex.Socket.Handler` to cowboy dispatch.

**Phoenix:**
Example based on [Phoenix guides](https://hexdocs.pm/phoenix/Phoenix.Endpoint.Cowboy2Adapter.html)

```elixir
config :exampleapp, ExampleApp.Endpoint,
  http: [
    dispatch: [
      {:_,
       [
         {"/storex", Storex.Socket.Handler, []},
         {:_, Phoenix.Endpoint.Cowboy2Handler, {ExampleApp.Endpoint, []}}
       ]}
    ]
  ]
```

**Cowboy:**
```elixir
:cowboy_router.compile([
    {:_, [
      # ...
      {"/storex", Storex.Socket.Handler, []},
      # ...
    ]}
  ])
```

### Create store

To create a store you need to create new elixir module with `init/2` which is called when a page is loaded, every time websocket is connected it generates session_id and passes it as the first argument, params are from Javascript store declaration. Next, you can declare `mutation/5` where the first argument is mutation name, second is data passed to mutation, next two params are same like in `init/2`, the last one is the current state of the store.

```elixir
defmodule ExampleApp.Store.Counter do
  use Storex.Store

  def init(session_id, params) do
    0
  end

  def mutation("increase", _data, _session_id, _params, state) do
    state = state + 1

    {:noreply, state}
  end

  def mutation("decrease", _data, _session_id, _params, state) do
    state = state - 1

    {:reply, "message", state}
  end

  def mutation("set", [number], _session_id, _params, state) do
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
    const state = state
  },
  connection: (state) => {
    console.log(state ? 'connected' : 'disconnected')
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
Storex.mutate(session_id, store, "increase")
Storex.mutate(session_id, store, "set", [10])
```

### Subscribe to store state changes

You can subscribe to store state changes in javascript with function subscribe:

```javascript
store.subscribe((state) => {
  const state = state
})
```

### Subscribe to store connection

You can subscribe to store connection state changes in javascript with function connection:

```javascript
store.connection((state) => {
  console.log(state ? 'connected' : 'disconnected')
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