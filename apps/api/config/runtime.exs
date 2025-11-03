import Config

# Load .env file for dev and test environments at runtime
if config_env() in [:dev, :test] do
  # Try to load dotenv if available
  case Code.ensure_loaded(Dotenv) do
    {:module, Dotenv} ->
      Dotenv.load()
      IO.puts("✅ Loaded .env file via dotenv")

    {:error, _reason} ->
      IO.puts("⚠️  Dotenv not available - using environment variables or defaults")
  end
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :emailgator_api, Emailgator.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :emailgator_api, EmailgatorWeb.Endpoint,
    url: [host: host, scheme: "https", port: 443],
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base,
    server: true

  config :emailgator_api, :openai,
    api_key: System.fetch_env!("OPENAI_API_KEY"),
    base_url: System.get_env("OPENAI_BASE_URL") || "https://api.openai.com/v1"

  config :emailgator_api, :assent,
    providers: [
      google: [
        client_id: System.fetch_env!("GOOGLE_CLIENT_ID"),
        client_secret: System.fetch_env!("GOOGLE_CLIENT_SECRET"),
        redirect_uri: System.fetch_env!("GOOGLE_OAUTH_REDIRECT_URL")
      ]
    ]

  config :emailgator_api, :sidecar,
    url: System.fetch_env!("SIDECAR_URL"),
    token: System.fetch_env!("SIDECAR_TOKEN")

  # Sentry configuration - only enabled if DSN is set
  sentry_dsn = System.get_env("SENTRY_DSN")

  if is_nil(sentry_dsn) or sentry_dsn == "" do
    # Disable Sentry when DSN is absent so boot never fails
    config :sentry, enable: false
  else
    config :sentry,
      dsn: sentry_dsn,
      environment_name: System.get_env("SENTRY_ENVIRONMENT") || "production",
      # optional but nice on Fly:
      release: System.get_env("FLY_IMAGE_REF") || System.get_env("RELEASE_SHA"),
      server_name: System.get_env("FLY_MACHINE_ID")
  end
end

# Runtime config for dev/test (already handled above)
