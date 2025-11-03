# Build stage
FROM elixir:1.17-otp-27-alpine AS build

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
RUN MIX_ENV=prod mix deps.get --only prod && \
    MIX_ENV=prod mix deps.compile

# Copy application code
COPY lib lib
COPY priv priv

# Compile and build release
RUN MIX_ENV=prod mix compile && \
    MIX_ENV=prod mix release

# Production stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    openssl \
    bash \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy release from build stage
COPY --from=build /app/_build/prod/rel/emailgator_api .

# Create a non-root user
RUN groupadd -r appgroup && \
    useradd -r -g appgroup appuser && \
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
