#!/bin/bash
# Deploy EmailGator Sidecar to Fly.io
#
# Usage:
#   ./deploy_sidecar.sh                  # Standard deploy
#   ./deploy_sidecar.sh --region iad     # Deploy with a specific primary region
#   ./deploy_sidecar.sh --no-remote      # Build locally instead of remote builder
#
# Requirements:
#   - Fly.io CLI installed: curl -L https://fly.io/install.sh | sh
#   - Logged in: fly auth login
#
# Notes:
#   - App name is fixed to "emailgator-sidecar" (see sidecar/fly.toml)

set -e

APP_NAME="emailgator-sidecar"
REMOTE_ONLY=true
PRIMARY_REGION=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)
      PRIMARY_REGION="$2"
      shift 2
      ;;
    --no-remote)
      REMOTE_ONLY=false
      shift 1
      ;;
    -h|--help)
      echo "Deploy EmailGator Sidecar to Fly.io"
      echo "\nUsage: ./deploy_sidecar.sh [--region <code>] [--no-remote]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Check flyctl
if ! command -v fly &> /dev/null; then
  echo "❌ Fly.io CLI (fly) is not installed. Install with:"
  echo "   curl -L https://fly.io/install.sh | sh"
  exit 1
fi

# Navigate to sidecar directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/sidecar"

echo "📄 Using fly config: $(pwd)/fly.toml"
echo "🛰️  Target app: $APP_NAME"

# Ensure app exists (idempotent)
if ! fly apps list --json | grep -q "\"Name\": \"$APP_NAME\"\|\"name\": \"$APP_NAME\""; then
  echo "🆕 App $APP_NAME not found. Creating..."
  if [[ -n "$PRIMARY_REGION" ]]; then
    fly apps create "$APP_NAME" --region "$PRIMARY_REGION"
  else
    fly apps create "$APP_NAME"
  fi
fi

# Optionally set primary region
if [[ -n "$PRIMARY_REGION" ]]; then
  echo "📍 Setting primary region to $PRIMARY_REGION"
  fly regions set "$PRIMARY_REGION" --app "$APP_NAME"
fi

DEPLOY_ARGS=(
  "--config" "fly.toml"
  "--app" "$APP_NAME"
)

if [[ "$REMOTE_ONLY" == true ]]; then
  DEPLOY_ARGS+=("--remote-only")
fi

echo "🚀 Deploying to Fly.io..."
fly deploy "${DEPLOY_ARGS[@]}" --yes

echo "✅ Deployment completed successfully!"


