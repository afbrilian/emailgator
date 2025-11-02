# Build stage
FROM hexpm/elixir:1.17.0-erlang-27.0-alpine-3.19.0 AS build

# Install build dependencies
RUN apk add --no-cache build-base git npm

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./
COPY config config

# Install dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy application code
COPY lib lib
COPY priv priv

# Compile and build release
RUN mix compile && \
    mix release

# Production stage
FROM alpine:3.19.0

# Install runtime dependencies
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    ca-certificates \
    bash

WORKDIR /app

# Copy release from build stage
COPY --from=build /app/_build/prod/rel/emailgator_api .

# Create a non-root user
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

USER appuser

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1

# Start the application
ENTRYPOINT ["/app/bin/emailgator_api"]
CMD ["start"]
