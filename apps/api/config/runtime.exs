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
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

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
end

# Runtime config for dev/test (already handled above)
