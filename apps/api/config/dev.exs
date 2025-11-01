import Config

config :emailgator_api, Emailgator.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "emailgator_dev#{System.get_env("MIX_TEST_PARTITION")}",
  pool_size: 10,
  show_sensitive_data_on_connection_error: true,
  code_reloader: true

config :emailgator_api, EmailgatorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev-secret-key-base-replace-in-production",
  watchers: []

config :emailgator_api, EmailgatorWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/emailgator_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# OpenAI (use dev key or mock)
config :emailgator_api, :openai,
  api_key: System.get_env("OPENAI_API_KEY") || "dev-key",
  base_url: "https://api.openai.com/v1"

# Google OAuth
config :emailgator_api, :assent,
  providers: [
    google: [
      client_id: System.get_env("GOOGLE_CLIENT_ID") || "dev-client-id",
      client_secret: System.get_env("GOOGLE_CLIENT_SECRET") || "dev-client-secret",
      redirect_uri:
        System.get_env("GOOGLE_OAUTH_REDIRECT_URL") ||
          "http://localhost:4000/auth/google/callback"
    ]
  ]

# Sidecar
config :emailgator_api, :sidecar,
  url: System.get_env("SIDECAR_URL") || "http://localhost:3001",
  token: System.get_env("SIDECAR_TOKEN") || "supersecret"

# Sentry - not included in dev (only in production)
