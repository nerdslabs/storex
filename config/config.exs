import Config

config :storex,
  session_id_library: Nanoid,
  registry: Storex.Registry.ETS
