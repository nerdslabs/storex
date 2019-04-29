# Basic usage

## Installation

Add **stex** to deps in `mix.exs`:

```elixir
defp deps do
  [
    {:stex, git: "https://github.com/nerdslabs/stex"}, # After release
  ]
end
```

Also you need to add **stex** to `package.json` dependencies:

```javascript
{
  "stex": "file:../deps/stex",
}
```

## Add stex websocket handler

You need to add handler `Stex.Socket.Handler` to cowboy dispatch.

### Phoenix:
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

### Cowboy:
```
:cowboy_router.compile([
    {:_, [
      # ...
      {"/stex", Stex.Socket.Handler, []},
      # ...
    ]}
  ])
```

## Create store

To create store you need to create new elixir module with `init/2` which is called everytime page is loaded, next to it you can declare `mutation/3` where first argument is mutation name, second is data passed to mutation, and last is current state of store.

```elixir
defmodule ExampleApp.Store.Sample do
  use Stex.Store

  def init(session, params) do
    {:ok, list} = ExampleApp.get_some_data

    list
  end

  def mutation("refresh", _data, _session, _params, _state) do
    {:ok, list} = ExampleApp.get_some_data

    {:ok, list}
  end
end
```

## Connect to store

Next part is connect from javascript to created store.

```javascript
import Stex from 'stex'

const store = new Stex({
  store: 'ExampleApp.Store.Sample',
  params: {},
})
```

## Mutate store

You can mutate store from javascript with store instance:

```javascript
store.mutate("mutation", ...data)
```

Or directly from elixir:

```elixir
Stex.mutate(session_id, store, "mutation", [data...])
```