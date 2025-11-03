# --- build stage (Alpine / musl) ---
FROM elixir:1.17-otp-27-alpine AS build

# Build deps
RUN apk add --no-cache build-base git npm

WORKDIR /app

# Hex / Rebar
RUN mix local.hex --force && mix local.rebar --force

# Deps
COPY mix.exs mix.lock ./
COPY config config
RUN MIX_ENV=prod mix deps.get --only prod && MIX_ENV=prod mix deps.compile

# App code
COPY lib lib
COPY priv priv
# If you have assets, uncomment:
# COPY assets assets
# RUN MIX_ENV=prod mix assets.deploy

# Release (includes ERTS by default)
RUN MIX_ENV=prod mix compile && MIX_ENV=prod mix release

# --- runtime stage (Alpine / musl) ---
FROM alpine:3.20

# Runtime libs for OTP 27 + Phoenix healthcheck
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    libstdc++ \
    libgcc \
    bash \
    wget \
    ca-certificates

WORKDIR /app

# Copy the full release (includes erts-*/bin)
COPY --from=build /app/_build/prod/rel/emailgator_api /app

# Non-root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup && chown -R appuser:appgroup /app
USER appuser

# Env
ENV PHX_SERVER=true LANG=C.UTF-8

EXPOSE 4000

# Health check (make sure /health exists in your app)
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1

ENTRYPOINT ["/app/bin/emailgator_api"]
CMD ["start"]
