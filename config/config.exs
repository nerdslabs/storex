# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :storex, :session_id_library, Nanoid

config :hound, driver: "chrome_driver", browser: "chrome_headless", retries: 3, genserver_timeout: 480000, retry_time: 3000
