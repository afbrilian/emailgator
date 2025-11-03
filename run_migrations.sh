#!/bin/bash
# Run database migrations against Supabase PostgreSQL
# Usage: ./run_migrations.sh [DATABASE_URL]
#
# IMPORTANT: For Supabase, use the TRANSACTION pooler (port 6543) NOT the SESSION pooler
# Default below uses transaction pooler which is correct for migrations
# If using direct connection, use: aws-0-us-east-2.pooler.supabase.com:5432

set -e

# Default database URL (replace with your actual password)
DATABASE_URL="${1:-postgresql://postgres.vflmrebrxapmxirqcitr:[YOUR-PASSWORD]@aws-0-us-east-2.pooler.supabase.com:6543/postgres}"

echo "🚀 Running database migrations..."
# Hide password in output
SAFE_URL=$(echo "$DATABASE_URL" | sed 's/:.*@/:***@/')
echo "Database: $SAFE_URL"

# Navigate to API directory
cd "$(dirname "$0")/apps/api"

# Set required environment variables for production config first
export MIX_ENV=prod
export DATABASE_URL
export SECRET_KEY_BASE="${SECRET_KEY_BASE:-$(mix phx.gen.secret)}"
export POOL_SIZE="${POOL_SIZE:-10}"

# Optional: Set dummy values for other required vars to avoid crashes during migration
export OPENAI_API_KEY="${OPENAI_API_KEY:-dummy-for-migration-only}"
export GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-dummy-for-migration-only}"
export GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET:-dummy-for-migration-only}"
export GOOGLE_OAUTH_REDIRECT_URL="${GOOGLE_OAUTH_REDIRECT_URL:-http://localhost:4000/auth/google/callback}"
export SIDECAR_URL="${SIDECAR_URL:-http://localhost:4005}"
export SIDECAR_TOKEN="${SIDECAR_TOKEN:-dummy-for-migration-only}"

# Run migrations using Mix
echo "Starting mix ecto.migrate..."
mix ecto.migrate || {
  echo "::error::Migration failed."
  exit 1
}

echo "✅ Migrations completed successfully"

