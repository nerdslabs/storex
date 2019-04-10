defmodule Stex.MixProject do
  use Mix.Project

  def project do
    [
      app: :stex,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "stex",
      source_url: "https://github.com/nerdslabs/stex",
      homepage_url: "http://nerdslabs.co",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Stex, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cowboy, "~> 2.6"},
      {:nanoid, "~> 2.0.1"},
      {:jason, "~> 1.0", optional: true},

      # Docs
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end
end
