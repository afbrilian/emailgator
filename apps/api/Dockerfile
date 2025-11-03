# --- build stage (Alpine / musl) ---
FROM elixir:1.17-otp-27-alpine AS build

RUN apk add --no-cache build-base git npm
WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN MIX_ENV=prod mix deps.get --only prod && MIX_ENV=prod mix deps.compile

COPY lib lib
COPY priv priv
# COPY assets assets
# RUN MIX_ENV=prod mix assets.deploy

RUN MIX_ENV=prod mix compile && MIX_ENV=prod mix release

# --- runtime stage (use the exact SAME base image) ---
FROM elixir:1.17-otp-27-alpine

# Install only runtime libs (no compilers)
RUN apk add --no-cache \
  openssl \
  ncurses-libs \
  libstdc++ \
  libgcc \
  bash \
  wget \
  ca-certificates \
  && apk del --no-network --purge npm || true  # best-effort trim if present

WORKDIR /app
COPY --from=build /app/_build/prod/rel/emailgator_api /app

# non-root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup && chown -R appuser:appgroup /app
USER appuser

ENV PHX_SERVER=true LANG=C.UTF-8
EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1

ENTRYPOINT ["/app/bin/emailgator_api"]
CMD ["start"]
