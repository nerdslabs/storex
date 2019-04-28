# Examples

## Javascript

```javascript
import Stex from 'stex'

const store = new Stex({
  store: 'ExampleApp.Store.Sample',
  params: {},
})

document.querySelector('#app span.hello').innerHTML = store.state.hello
```

## VueJS

```
<template>
  <div id="app">
    {{ hello }}
  </div>
</template>

<script>
import Stex from 'stex'

const store = new Stex({
  store: 'ExampleApp.Store.Sample',
  params: {},
})

export default {
  data() {
    return {
      store: store,
    };
  },
  computed: {
    hello() {
      return this.store.state.hello
    }
  }
};
</script>
```