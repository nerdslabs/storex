# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :storex, :session_id_library, Nanoid

config :hound, driver: "selenium"
