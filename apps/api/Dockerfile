# --- build stage (Alpine / musl) ---
FROM elixir:1.17-otp-27-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git npm

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./
COPY config config

# Install dependencies
RUN MIX_ENV=prod mix deps.get --only prod && MIX_ENV=prod mix deps.compile

# Copy source code
COPY lib lib
COPY priv priv
# If you have assets, also copy and build them here
# COPY assets assets
# RUN MIX_ENV=prod mix assets.deploy

# Build release
RUN MIX_ENV=prod mix compile && MIX_ENV=prod mix release

# --- runtime stage (Alpine / musl) ---
FROM alpine:3.20

# Install runtime libs for OTP 27
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    bash \
    wget \
    ca-certificates

WORKDIR /app

# Copy the full release
COPY --from=build /app/_build/prod/rel/emailgator_api /app

# Non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup && chown -R appuser:appgroup /app
USER appuser

# Environment
ENV PHX_SERVER=true LANG=C.UTF-8

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1

# Start release
ENTRYPOINT ["/app/bin/emailgator_api"]
CMD ["start"]
