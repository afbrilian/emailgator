defmodule EmailgatorApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :emailgator_api,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixir_paths: elixir_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      mod: {Emailgator.Application, []},
      extra_applications: [:logger, :runtime_tools, :oban, :hackney]
    ]
  end

  defp elixir_paths(:test), do: ["lib", "test/support"]
  defp elixir_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.12"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.1"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.7"},

      # GraphQL
      {:absinthe, "~> 1.7"},
      {:absinthe_plug, "~> 1.5"},

      # Background jobs
      {:oban, "~> 2.17"},

      # HTTP client
      {:tesla, "~> 1.8"},
      {:finch, "~> 0.18"},

      # OAuth
      {:assent, "~> 0.2"},
      {:ssl_verify_fun, "~> 1.1"},
      {:certifi, "~> 2.4"},

      # Environment variables
      {:dotenv, "~> 3.0", only: [:dev, :test]},

      # Encryption for tokens
      {:cloak, "~> 1.1"},

      # Monitoring (production only)
      {:sentry, "~> 9.0", only: :prod},
      {:hackney, "~> 1.8", only: :prod},

      # Testing
      {:mox, "~> 1.1", only: :test},
      {:hammox, "~> 0.7", only: :test},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "test.coverage": ["coveralls.json"]
    ]
  end
end
