interface Message {
  type: string
  store: string
  session: string
  data: any
}

class Socket {
  private socket: WebSocket
  private keeper: null | number
  private requests: { [key: string]: any }

  public stores: { [key: string]: Stex }

  constructor() {
    this.keeper = null

    this.requests = {}
    this.stores = {}

    this.connect()
  }

  connect() {
    this.socket = new WebSocket('ws://' + location.host + '/stex')
    this.socket.binaryType = 'arraybuffer'

    this.socket.onopen = this.opened.bind(this)
    this.socket.onclose = this.closed.bind(this)
    this.socket.onmessage = this.message.bind(this)
  }

  send(data: any): Promise<Message> {
    return new Promise((resolve, reject) => {
      const request = Math.random().toString(36).substr(2, 5)
      const payload = data
      payload.request = request

      this.socket.send(JSON.stringify(payload))
      // const binary = Uint8Array.from(Bert.binaryToList(Bert.encode(payload))).buffer
      // this.socket.send(binary)

      this.requests[request] = [resolve, reject]
    })
  }

  message(message: MessageEvent) {
    // const array = Array.from(new Uint8Array(message.data))
    // const bert = array.map(x => String.fromCharCode(x)).join('')
    // const data = Bert.decode(bert)

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
    this.keeper = setInterval(() => {
      this.send({
        type: 'ping'
      })
    }, 30000)
  }

  closed(event: CloseEvent) {
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

  public static defaults: { params: {[key: string]: any}} = {
    params: {}
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

    this.socket.stores[this.config.store] = this

    setTimeout(() => {
      this.socket.send({
        type: 'join',
        store: this.config.store,
        data: { ...Stex.defaults.params, ...this.config.params }
      }).then((response: Message) => {
        this.session = response.session
        this.state = response.data
      })
    }, 300)
  }

  commit(type: string, ...data: any) {
    return this.socket.send({
      type: 'mutation',
      store: this.config.store,
      session: this.session,
      data: {
        type, data
      }
    }).then((message: Message) => {
      this.state = message.data
    })
  }
}

export default Stex