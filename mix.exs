defmodule Storex.MixProject do
  use Mix.Project

  @version "0.5.1"

  def project do
    [
      app: :storex,
      version: @version,
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "storex",
      source_url: "https://github.com/nerdslabs/storex",
      homepage_url: "http://nerdslabs.co",
      docs: docs(),
      description: description(),
      package: package(),
      aliases: [
        test: "test --no-start"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/fixtures", "test/storex", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      mod: {Storex, []}
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp deps do
    [
      {:websock_adapter, "~> 0.5.6"},
      {:plug, "~> 1.15"},
      {:nanoid, "~> 2.0"},
      {:jason, "~> 1.4"},

      # Docs
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},

      # Tests
      {:ssl_verify_fun, "~> 1.1", only: :test, manager: :rebar3, override: true},
      {:wallaby, "~> 0.30.0", runtime: false, only: :test},
      {:cowboy, "~> 2.9", only: :test},
      {:bandit, "~> 1.4", only: :test},
      {:plug_cowboy, "~> 2.0", only: :test},
      {:local_cluster, "~> 1.2", only: [:test]}
    ]
  end

  defp description() do
    "Frontend store managed in backend."
  end

  defp package() do
    [
      name: "storex",
      files: ["lib", "priv", "mix.exs", "package.json", "README*", "LICENSE*", ".formatter.exs"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/nerdslabs/storex"}
    ]
  end
end
