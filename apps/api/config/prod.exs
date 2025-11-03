import Config

# Production config - most settings come from runtime.exs
# This file is mainly for compile-time settings

# Logger configuration
config :logger, level: :info

# Do not include debugger and annotate Ecto queries
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
