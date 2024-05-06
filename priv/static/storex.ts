interface Response {
  type: string
  store: string
  session: string
  data: any
  message?: any
}

interface Error {
  type: string
  store: string
  session: string
  error: string
}

interface Change {
  a: 'u' | 'd' | 'i'
  p: any[]
  t: unknown
}

class Diff {
  private static set<T>(object: T, path: any[], value: unknown): T {
    if (path.length > 0) {
      const index = path.pop()
      const parent = path.reduce((o, i) => o[i], object)

      parent[index] = value

      return object
    } else {
      return value as T
    }
  }

  private static remove<T>(object: T, path: any[]): T {
    const index = path.pop()
    const parent = path.reduce((o, i) => o[i], object)

    if (Array.isArray(parent)) {
      parent.splice(index, 1)
    } else {
      delete parent[index]
    }

    return object
  }

  public static patch<T>(source: T, changes: Change[]): T {
    for (const change of changes) {
      if (change.a === 'u') {
        source = Diff.set<T>(source, change.p, change.t)
      } else if (change.a === 'd') {
        source = Diff.remove<T>(source, change.p)
      } else if (change.a === 'i') {
        source = Diff.set<T>(source, change.p, change.t)
      }
    }

    return source
  }
}

class Socket {
  private socket: WebSocket | null = null
  private keeper: any
  private requests: { [key: string]: any }

  private connectListeners: (() => void)[] = []

  public stores: { [key: string]: Storex<any> }

  constructor() {
    this.keeper = null

    this.requests = {}
    this.stores = {}
  }

  connect(): void {
    if (this.isConnected === false && this.socket === null) {
      const address = Storex.defaults.address || location.host + '/storex'
      const protocol = location.protocol === 'https:' ? 'wss://' : 'ws://'

      this.socket = new WebSocket(protocol + address)
      this.socket.binaryType = 'arraybuffer'

      this.socket.onopen = this.opened.bind(this)
      this.socket.onclose = this.closed.bind(this)
      this.socket.onmessage = this.message.bind(this)
    }
  }

  onConnect(listener: () => void) {
    if (this.isConnected) {
      listener()
    }

    this.connectListeners.push(listener)
  }

  get isConnected() {
    return this.socket !== void 0 && this.socket?.readyState === WebSocket.OPEN
  }

  _generateRequestId() {
    const minCharCode = 48
    const maxCharCode = 122

    let randomString = ''

    for (let i = 0; i < 10; i++) {
      const randomCharCode =
        Math.floor(Math.random() * (maxCharCode - minCharCode + 1)) + minCharCode
      randomString += String.fromCharCode(randomCharCode)
    }

    return randomString
  }

  send(data: any): Promise<Response> {
    return new Promise((resolve, reject) => {
      const request = this._generateRequestId()
      const payload = data
      payload.request = request

      this.socket?.send(JSON.stringify(payload))

      this.requests[request] = [resolve, reject]
    })
  }

  message(message: MessageEvent) {
    const data = JSON.parse(message.data)
    const request = this.requests[data.request]
    if (request !== void 0) {
      const [resolve, reject] = request

      if (data.type === 'error') {
        reject(data)
      } else {
        resolve(data)
      }
    } else {
      if (data.type === 'mutation') {
        const store = this.stores[data.store]
        if (store !== void 0) {
          store._mutate(data)
        }
      }
    }
  }

  opened(event: Event) {
    if (this.socket?.readyState === WebSocket.OPEN) {
      this.connectListeners.forEach((listener) => listener())

      this.keeper = setInterval(() => {
        this.send({
          type: 'ping',
        })
      }, 30000)
    } else {
      setTimeout(this.opened.bind(this, event), 100)
    }
  }

  closed(event: CloseEvent) {
    this.socket = null

    const code = event.code
    const reason = event.reason

    if (code >= 4000) {
      console.error('[storex]', reason)
    } else if ([1000, 1005, 1006].includes(code)) {
      this.connect()
    }

    Object.values(this.stores).forEach((store) => store._disconnected(event))

    if (this.keeper !== null) {
      clearInterval(this.keeper)
    }
  }
}

const socket = new Socket()

interface StoreConfig<T> {
  session?: string
  store: string
  params: { [key: string]: any }
  subscribe?: (state: T) => void
  onConnected?: () => void
  onError?: (error: unknown) => void
  onDisconnected?: (event: CloseEvent) => void
}

class Storex<T> {
  private session: string | null
  private config: StoreConfig<T>
  private socket: Socket
  private listeners: {
    messages: ((state: T) => void)[]
    connected: (() => void)[]
    errors: ((error: unknown) => void)[]
    disconnected: ((event: CloseEvent) => void)[]
  } = {
    messages: [],
    connected: [],
    errors: [],
    disconnected: [],
  }

  public state: T

  public static defaults: { params: { [key: string]: any }; address?: string } = {
    params: {},
  }

  constructor(config: StoreConfig<T>) {
    this.session = config.session || null
    this.config = config
    this.socket = socket

    if (!this.config.store) {
      throw new Error('[storex] Store is required')
    }

    if (this.config.subscribe) {
      if (typeof this.config.subscribe !== 'function') {
        throw new ErrorEvent('Listener has to be a function.')
      }

      this.listeners.messages.push(this.config.subscribe)
    }

    if (this.config.onConnected) {
      if (typeof this.config.onConnected !== 'function') {
        throw new ErrorEvent('Listener has to be a function.')
      }

      this.listeners.connected.push(this.config.onConnected)
    }

    if (this.config.onError) {
      if (typeof this.config.onError !== 'function') {
        throw new ErrorEvent('Listener has to be a function.')
      }

      this.listeners.errors.push(this.config.onError)
    }

    if (this.config.onDisconnected) {
      if (typeof this.config.onDisconnected !== 'function') {
        throw new ErrorEvent('Listener has to be a function.')
      }

      this.listeners.disconnected.push(this.config.onDisconnected)
    }

    this.socket.onConnect(this._connected.bind(this))
    this.socket.connect()
  }

  _connected() {
    this.socket.stores[this.config.store] = this

    this.socket
      .send({
        type: 'join',
        store: this.config.store,
        data: { ...Storex.defaults.params, ...this.config.params },
      })
      .then(
        (response: Response) => {
          this.session = response.session
          this._mutate(response)

          this.listeners.connected.forEach((listener) => listener())
        },
        (error: Error) => {
          this.listeners.errors.forEach((listener) => listener(error.error))
        },
      )
  }

  _disconnected(event: CloseEvent) {
    this.listeners.disconnected.forEach((listener) => listener(event))
  }

  _mutate(message: any) {
    if (message.diff !== void 0) {
      this.state = Diff.patch<T>(this.state, message.diff)
    } else {
      this.state = message.data
    }

    for (let i = 0; i < this.listeners.messages.length; i++) {
      const listener = this.listeners.messages[i]
      listener(this.state)
    }
  }

  commit<T>(name: string, ...data: any): Promise<T | undefined> {
    return new Promise((resolve, reject) => {
      this.socket
        .send({
          type: 'mutation',
          store: this.config.store,
          session: this.session,
          data: {
            name,
            data,
          },
        })
        .then(
          (response: Response) => {
            this._mutate(response)
            if (response.message !== void 0) {
              resolve(response.message)
            } else {
              resolve(undefined)
            }
          },
          (error: Error) => {
            reject(error.error)
          },
        )
    })
  }

  subscribe(listener: (state: T) => void): () => void {
    if (typeof listener !== 'function') {
      throw new ErrorEvent('Listener has to be a function.')
    }

    this.listeners.messages.push(listener)
    listener(this.state)

    return function unsubscribe() {
      const index = this?.listeners.messages.indexOf(listener)
      if (index > -1) {
        this.listeners.messages.splice(index, 1)
      }
    }
  }

  onConnected(listener: () => void): () => void {
    if (typeof listener !== 'function') {
      throw new ErrorEvent('Listener has to be a function.')
    }

    this.listeners.connected.push(listener)

    return function unsubscribe() {
      const index = this?.listeners.connected.indexOf(listener)
      if (index > -1) {
        this.listeners.connected.splice(index, 1)
      }
    }
  }

  onError(listener: (error: unknown) => void): () => void {
    if (typeof listener !== 'function') {
      throw new ErrorEvent('Listener has to be a function.')
    }

    this.listeners.errors.push(listener)

    return function unsubscribe() {
      const index = this?.listeners.errors.indexOf(listener)
      if (index > -1) {
        this.listeners.errors.splice(index, 1)
      }
    }
  }

  onDisconnected(listener: (event: CloseEvent) => void): () => void {
    if (typeof listener !== 'function') {
      throw new ErrorEvent('Listener has to be a function.')
    }

    this.listeners.disconnected.push(listener)

    return function unsubscribe() {
      const index = this?.listeners.disconnected.indexOf(listener)
      if (index > -1) {
        this.listeners.disconnected.splice(index, 1)
      }
    }
  }
}

export default Storex
