import Config

config :storex,
  session_id_library: Nanoid,
  registry: Storex.Registry.ETS

config :wallaby,
  otp_app: :storex,
  chromedriver: [
    # headless: false
  ]
