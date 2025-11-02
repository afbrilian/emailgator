import Config

# Ecto repos configuration
config :emailgator_api, ecto_repos: [Emailgator.Repo]

config :emailgator_api, Emailgator.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "emailgator_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :emailgator_api, EmailgatorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [json: EmailgatorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Emailgator.PubSub,
  live_view: [signing_salt: "emailgator"],
  signing_salt: "emailgator_salt"

# Oban configuration
# Queue concurrency settings:
# - poll: 1 (Gmail API polling - rate limited, keep low)
# - import: 1 (Email import with LLM - rate limited, keep low)
# - archive: 5 (Email archiving - can be higher)
# - unsubscribe: 5 (Unsubscribe processing - increase for high volume)
#   For production with thousands of unsubscribes, consider increasing to 10-20
config :emailgator_api, Oban,
  repo: Emailgator.Repo,
  queues: [poll: 1, import: 1, archive: 5, unsubscribe: 5],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 3600 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       {"*/2 * * * *", Emailgator.Jobs.PollCron}
     ],
     timezone: "Etc/UTC"}
  ]

# Tesla adapter
config :tesla, adapter: Tesla.Adapter.Finch
config :tesla, disable_deprecated_builder_warning: true

# Assent SSL configuration
# With ssl_verify_fun dependency, Assent will use it automatically
# No additional config needed - the dependency handles SSL verification

# Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :logger, level: :info

import_config "#{config_env()}.exs"
