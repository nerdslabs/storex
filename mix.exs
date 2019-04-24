defmodule Stex.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :stex,
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env),
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

  defp elixirc_paths(:test), do: ["lib", "test/browser_test", "test/stores"]
  defp elixirc_paths(_), do: ["lib"]

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
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev], runtime: false},

      # Tests
      {:hound, "~> 1.1", only: [:test]}
    ]
  end
end
