import Config

config :emailgator_api, Emailgator.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "emailgator_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :emailgator_api, EmailgatorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false

config :emailgator_api, :openai,
  api_key: "test-key",
  # Mock server
  base_url: "http://localhost:4003"

config :emailgator_api, :assent,
  providers: [
    google: [
      client_id: "test-client-id",
      client_secret: "test-client-secret",
      redirect_uri: "http://localhost:4000/auth/google/callback"
    ]
  ]

config :emailgator_api, :sidecar,
  url: "http://localhost:4004",
  token: "test-token"

# Sentry - not included in test (only in production)

config :logger, level: :warning

# ExCoveralls configuration
config :excoveralls,
  tool: ExCoveralls

# Oban configuration for tests - disable queues and plugins to avoid sandbox connection issues
# This prevents Oban's background GenServers (Stager, Producers) from trying to access the database
# Jobs can still be inserted and manually executed using Oban.Testing helpers
config :emailgator_api, Oban,
  queues: false,
  plugins: false,
  crontab: false
