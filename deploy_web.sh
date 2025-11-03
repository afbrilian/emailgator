#!/bin/bash
# Deploy EmailGator Web app to Vercel
#
# Usage:
#   ./deploy_web.sh              # Deploy to preview environment
#   ./deploy_web.sh --production # Deploy to production environment
#
# Requirements:
#   - Vercel CLI installed globally: npm i -g vercel
#   - Environment variable NEXT_PUBLIC_API_URL set to your API URL
#
# Example:
#   export NEXT_PUBLIC_API_URL=https://emailgator.fly.dev
#   ./deploy_web.sh --production

set -e

# Parse arguments
PRODUCTION=false
if [[ "$1" == "--production" || "$1" == "--prod" ]]; then
  PRODUCTION=true
  echo "🚀 Deploying to PRODUCTION environment..."
else
  echo "🧪 Deploying to PREVIEW environment..."
fi

# Check if vercel CLI is installed
if ! command -v vercel &> /dev/null; then
  echo "❌ Vercel CLI is not installed. Please install it first:"
  echo "   npm i -g vercel"
  exit 1
fi

# Navigate to web directory
cd "$(dirname "$0")/apps/web"

echo "📦 Installing dependencies..."
npm ci

# Build the application (this will run codegen via prebuild script if configured)
echo "🏗️  Building Next.js application..."
echo "ℹ️  Note: GraphQL codegen will run automatically via prebuild script"
npm run build

# Deploy to Vercel
echo "🌐 Deploying to Vercel..."
if [ "$PRODUCTION" = true ]; then
  vercel --prod --yes
else
  vercel --yes
fi

echo "✅ Deployment completed successfully!"

