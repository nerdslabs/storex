interface Message {
  type: string
  store: string
  session: string
  data: any,
  message?: any
}

interface Error {
  type: string
  store: string
  session: string
  error: string
}

class Diff {

  private static set(object: any, path: any[], value: any) {
    let index = path.pop()
    let parent = path.reduce((o, i) => o[i], object)

    parent[index] = value
  }

  private static remove(object: any, path: any[]) {
    let index = path.pop()
    let parent = path.reduce((o, i) => o[i], object)

    if (Array.isArray(parent)) {
      parent.splice(index, 1)
    } else {
      delete parent[index]
    }
  }

  public static patch(source: any, changes: any[]) {
    for (let change of changes) {
      if (change.a === "u") {
        Diff.set(source, change.p, change.t)
      } else if (change.a === "d") {
        Diff.remove(source, change.p)
      } else if (change.a === "i") {
        Diff.set(source, change.p, change.t)
      }
    }

    return source
  }
}

class Socket {
  private socket: WebSocket
  private keeper: any
  private requests: { [key: string]: any }

  private connections: any[] = []

  public stores: { [key: string]: Stex }

  constructor() {
    this.keeper = null

    this.requests = {}
    this.stores = {}
  }

  connect(): Promise<any> {
    return new Promise((resolve, reject) => {
      if (this.isConnected) {
        resolve()
      } else {
        this.connections.push({ resolve, reject })

        if (this.socket === void 0) {
          const address = Stex.defaults.address || location.host + '/stex'

          this.socket = new WebSocket('ws://' + address)
          this.socket.binaryType = 'arraybuffer'

          this.socket.onopen = this.opened.bind(this)
          this.socket.onclose = this.closed.bind(this)
          this.socket.onmessage = this.message.bind(this)
        }
      }
    })
  }

  get isConnected() {
    return this.socket !== void 0 && this.socket.readyState === this.socket.OPEN
  }

  send(data: any): Promise<Message> {
    return new Promise((resolve, reject) => {
      const request = Math.random().toString(36).substr(2, 5)
      const payload = data
      payload.request = request

      this.socket.send(JSON.stringify(payload))

      this.requests[request] = [resolve, reject]
    })
  }

  message(message: MessageEvent) {
    const data = JSON.parse(message.data)
    const request = this.requests[data.request]
    if (request !== void 0) {
      const [resolve, reject] = request

      if(data.type === "error") {
        reject(data)
      } else {
        resolve(data)
      }
    } else {
      if (data.type === "mutation") {
        const store = this.stores[data.store]
        if (store !== void 0) {
          store._mutate(data)
        }
      }
    }
  }

  opened(event: Event) {
    if (this.socket.readyState === this.socket.OPEN) {
      while (this.connections.length > 0) {
        const { resolve, _ } = this.connections.shift()
        resolve()
      }

      this.keeper = setInterval(() => {
        this.send({
          type: 'ping'
        })
      }, 30000)
    } else {
      setTimeout(this.opened.bind(this, event), 100)
    }
  }

  closed(event: CloseEvent) {
    while (this.connections.length > 0) {
      const { _, reject } = this.connections.shift()
      reject()
    }

    console.log(event)

    const code = event.code
    const reason = event.reason

    if (code >= 4000) {
      console.error('[stex]', reason)
    } else if (code === 1000) {
      this.connect()
    }

    if (this.keeper !== null) {
      clearInterval(this.keeper)
    }
  }
}

const socket = new Socket()

interface StoreConfig {
  session?: string
  store: string
  params: {[key: string]: any}
  subscribe?: () => void
}

class Stex {
  private session: string
  private config: any
  private socket: Socket
  private listeners: ((state: any) => void)[] = []

  public state: any

  public static defaults: { params: { [key: string]: any }, address?: string } = {
    params: {},
  }

  constructor(config: StoreConfig) {
    this.session = config.session || null
    this.config = config
    this.socket = socket
    this.state = null

    if (!this.config.store) {
      throw new Error('[stex] Store is required')
    }

    if (this.config.subscribe) {
      if (typeof this.config.subscribe !== "function") {
        throw new ErrorEvent("Listener has to be a function.")
      }

      this.listeners.push(this.config.subscribe)
    }

    this.socket.connect().then(this._connected.bind(this))
  }

  _connected() {
    this.socket.stores[this.config.store] = this

    this.socket.send({
      type: 'join',
      store: this.config.store,
      data: { ...Stex.defaults.params, ...this.config.params }
    }).then((message: Message) => {
      this.session = message.session
      this._mutate(message)
    })
  }

  _mutate(message: any) {
    if (message.diff !== void 0) {
      this.state = Diff.patch(this.state, message.diff)
    } else {
      this.state = message.data
    }

    for (let i = 0; i < this.listeners.length; i++) {
      const listener = this.listeners[i]
      listener(this.state)
    }
  }

  commit(name: string, ...data: any) {
    return new Promise((resolve, reject) => {
      this.socket.send({
        type: 'mutation',
        store: this.config.store,
        session: this.session,
        data: {
          name, data
        }
      }).then((message: Message) => {
        this._mutate(message)
        if (message.message !== void 0) {
          resolve(message.message)
        } else {
          resolve()
        }
      }, (error: Error) => {
        reject(error.error)
      })
    })
  }

  subscribe(listener: (state: any) => void): () => void {
    if(typeof listener !== "function") {
      throw new ErrorEvent("Listener has to be a function.")
    }

    this.listeners.push(listener)
    listener(this.state)

    return function unsubscribe() {
      const index = this.listeners.indexOf(listener)
      if(index > -1) {
        this.listeners.splice(index, 1)
      }
    }
  }
}

export default Stex