defmodule Storex.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :storex,
      version: @version,
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "storex",
      source_url: "https://github.com/nerdslabs/storex",
      homepage_url: "http://nerdslabs.co",
      docs: docs(),
      description: description(),
      package: package(),
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/browser_test", "test/stores"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      mod: {Storex, []},
      extra_applications: [:logger]
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
