# Stex

**TODO: Add description**

## Installation

**TODO**

## Basic usage

```elixir
defmodule ExampleApp.Store.Sample do
  use Stex.Store

  def init(session, params) do
    {:ok, list} = ExampleApp.get_some_data

    list
  end

  def mutation({"refresh", _params}, _state) do
    {:ok, list} = ExampleApp.get_some_data

    list
  end
end
```

```javascript
import Stex from 'stex'

export default new Stex({
  store: 'ExampleApp.Store.Sample',
  params: {},
})
```

## Set defalt params

For example you can set current user JWT

```javascript
  Stex.defaults.params.jwt = 'someJWT'
```

## Mutate store

**Javascipt**
```javascript
store.$commit(mutation, ...params)
```
**Elixir**
```elixir
Stex.mutate(session, store, mutation, params)
```