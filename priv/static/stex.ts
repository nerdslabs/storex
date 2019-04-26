interface Message {
  type: string
  store: string
  session: string
  data: any
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

      resolve(data)
    } else {
      if (data.type === "mutation") {
        const store = this.stores[data.store]
        if (store !== void 0) {
          store.state = data.data
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

class Stex {
  private session: string
  private config: any
  private socket: Socket

  public state: any

  public static defaults: { params: { [key: string]: any }, address?: string } = {
    params: {},
  }

  constructor(config: any) {
    this.session = config.session || null
    this.config = config
    this.socket = socket
    this.state = null

    if (!this.config.store) {
      console.error('[stex]', 'Store is required')
      return
    }

    this.socket.connect().then(this._connected.bind(this))
  }

  _connected() {
    this.socket.stores[this.config.store] = this

    this.socket.send({
      type: 'join',
      store: this.config.store,
      data: { ...Stex.defaults.params, ...this.config.params }
    }).then((response: Message) => {
      this.session = response.session
      this.state = response.data
    })
  }

  commit(name: string, ...data: any) {
    return this.socket.send({
      type: 'mutation',
      store: this.config.store,
      session: this.session,
      data: {
        name, data
      }
    }).then((message: Message) => {
      this.state = message.data
    })
  }
}

export default Stex