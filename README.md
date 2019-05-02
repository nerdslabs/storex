# Stex

Frontend store with the state on the backend. You are able to mutate store state from the frontend and also from the backend. Whole communications going throw WebSocket.

**Important:** Stex is under active development. Report issues and send proposals [here](https://github.com/nerdslabs/stex/issues/new).

Currently, the entire state of the store is being sent on each mutation, planned is to send difference of state.

## Basic usage

### Installation

Add **stex** to deps in `mix.exs`:

```elixir
defp deps do
  [
    {:stex, git: "https://github.com/nerdslabs/stex"},
  ]
end
```

Also you need to add **stex** to `package.json` dependencies:

```javascript
{
  "stex": "file:../deps/stex",
}
```

### Add stex websocket handler

You need to add handler `Stex.Socket.Handler` to cowboy dispatch.

**Phoenix:**
Example based on [Phoenix guides](https://hexdocs.pm/phoenix/Phoenix.Endpoint.Cowboy2Adapter.html)

```
config :exampleapp, ExampleApp.Endpoint,
  http: [
    dispatch: [
      {:_,
       [
         {"/stex", Stex.Socket.Handler, []},
         {:_, Phoenix.Endpoint.Cowboy2Handler, {ExampleApp.Endpoint, []}}
       ]}
    ]
  ]
```

**Cowboy:**
```
:cowboy_router.compile([
    {:_, [
      # ...
      {"/stex", Stex.Socket.Handler, []},
      # ...
    ]}
  ])
```

### Create store

To create a store you need to create new elixir module with `init/2` which is called when a page is loaded, every time websocket is connected it generates session_id and passes it as the first argument, params are from Javascript store declaration. Next, to it you can declare `mutation/5` where the first argument is mutation name, second is data passed to mutation, next two params are same like in `init/2`, the last one is the current state of the store.

```elixir
defmodule ExampleApp.Store.Counter do
  use Stex.Store

  def init(session_id, params) do
    0
  end

  def mutation("increase", _data, _session_id, _params, state) do
    state = state + 1

    {:ok, state}
  end

  def mutation("decrease", _data, _session_id, _params, state) do
    state = state - 1

    {:ok, state}
  end

  def mutation("set", [number], _session_id, _params, state) do
    {:ok, number}
  end
end
```

### Connect to store

Next part is connect from javascript to created store, `params` are passed as second argument in store `init/2` and as third in `mutation/5`.

```javascript
import Stex from 'stex'

const store = new Stex({
  store: 'ExampleApp.Store.Counter',
  params: {},
})
```

### Mutate store

You can mutate store from javascript with store instance:

```javascript
store.mutate("increase")
store.mutate("set", 10)
```

Or directly from elixir:

```elixir
Stex.mutate(session_id, store, "increase")
Stex.mutate(session_id, store, "set", [10])
```

## Configuration

### Session library

You can change library which generate session id for stores. Module needs to have **generate/0** method.

```elixir
config :stex, :session_id_library, Ecto.UUID
```

### Default params

You can set default params for all stores in Javascript which will be passed to store.

```javascript
Stex.defaults.params = {
  jwt: 'someJWT'
}
```

### Custom store address

```javascript
Stex.defaults.address = 'localhost/stores'
```