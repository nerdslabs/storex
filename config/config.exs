import Config

config :storex,
  session_id_library: Nanoid,
  registry: Storex.Registry.ETS

if Mix.env() == :test do
  import_config "test.exs"
end
