# EmailGator Deployment Guide

Complete guide for deploying EmailGator to production.

## Overview

EmailGator consists of three main components:

- **Backend (Phoenix API)**: Deployed to Fly.io
- **Frontend (Next.js)**: Deployed to Vercel
- **Sidecar (Node.js)**: Deployed to Fly.io
- **Database**: Supabase PostgreSQL (provisioned via Terraform)

## Prerequisites

Before starting, ensure you have:

1. **GitHub Account** with repository access
2. **Fly.io Account** - Sign up at [fly.io](https://fly.io)
3. **Vercel Account** - Sign up at [vercel.com](https://vercel.com)
4. **Supabase Account** - Sign up at [supabase.com](https://supabase.com)
5. **Terraform** installed (version >= 1.0)

## Deployment Flow

### Phase 1: Infrastructure Setup

#### 1.1 Provision Database with Terraform

See [infra/README.md](./infra/README.md) for detailed instructions.

Quick start:

```bash
cd infra

# Create terraform.tfvars (see infra/README.md for template)
# Generate secure password: openssl rand -base64 32

terraform init
terraform plan
terraform apply

# Save the DATABASE_URL output
terraform output -raw database_url
```

#### 1.2 Create Fly.io Applications

```bash
# Install Fly.io CLI if not already installed
curl -L https://fly.io/install.sh | sh

# Login to Fly.io
fly auth login

# Create backend API app
cd apps/api
fly apps create emailgator-api

# Create sidecar app
cd ../../sidecar
fly apps create emailgator-sidecar
```

#### 1.3 Create Vercel Project

1. Go to [vercel.com](https://vercel.com)
2. Import your GitHub repository
3. Configure project:
   - Framework Preset: Next.js
   - Root Directory: `apps/web`
   - Build Command: `npm run build`
   - Output Directory: `.next`
4. Save project (deployment will be configured via GitHub Actions later)

### Phase 2: Configure Secrets

#### 2.1 Fly.io Secrets (Backend API)

Set all required secrets for the backend:

```bash
cd apps/api

# Database
fly secrets set DATABASE_URL="$(cd ../../infra && terraform output -raw database_url)" --app emailgator-api

# Generate secret key base
fly secrets set SECRET_KEY_BASE="$(mix phx.gen.secret)" --app emailgator-api

# Google OAuth (get from Google Cloud Console)
fly secrets set GOOGLE_CLIENT_ID="your-client-id" --app emailgator-api
fly secrets set GOOGLE_CLIENT_SECRET="your-client-secret" --app emailgator-api
fly secrets set GOOGLE_OAUTH_REDIRECT_URL="https://emailgator-api.fly.dev/auth/google/callback" --app emailgator-api

# OpenAI
fly secrets set OPENAI_API_KEY="your-openai-api-key" --app emailgator-api

# Sidecar configuration
fly secrets set SIDECAR_URL="https://emailgator-sidecar.fly.dev" --app emailgator-api
fly secrets set SIDECAR_TOKEN="$(openssl rand -base64 32)" --app emailgator-api

# Frontend URL (update after Vercel deployment)
fly secrets set FRONTEND_URL="https://your-vercel-app.vercel.app" --app emailgator-api

# Phoenix host
fly secrets set PHX_HOST="emailgator-api.fly.dev" --app emailgator-api

# Optional: Sentry for error tracking
# fly secrets set SENTRY_DSN="your-sentry-dsn" --app emailgator-api
```

**Generate SIDECAR_TOKEN and save it** - you'll need it for the sidecar app.

#### 2.2 Fly.io Secrets (Sidecar)

```bash
cd sidecar

# Use the same token as SIDECAR_TOKEN from backend
fly secrets set INTERNAL_TOKEN="same-token-as-sidcar-token-above" --app emailgator-sidecar

# Optional: Domain allowlist
fly secrets set ALLOWLIST_DOMAINS="example.com,another-domain.com" --app emailgator-sidecar
```

#### 2.3 Vercel Environment Variables

1. Go to your Vercel project settings
2. Navigate to Environment Variables
3. Add:
   - `NEXT_PUBLIC_API_URL`: `https://emailgator-api.fly.dev`
   - Any other environment variables needed

#### 2.4 GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following secrets:

```
FLY_API_TOKEN         # Get from: fly auth token
VERCEL_TOKEN          # Get from Vercel dashboard → Settings → Tokens
VERCEL_ORG_ID         # Found in Vercel project settings
VERCEL_PROJECT_ID     # Found in Vercel project settings
NEXT_PUBLIC_API_URL   # https://emailgator-api.fly.dev
```

**Note**: `SUPABASE_API_KEY` can be set as an environment variable when running Terraform, or stored in GitHub Secrets if using Terraform in CI/CD.

### Phase 3: Initial Deployment

#### 3.1 Deploy Backend API

```bash
cd apps/api

# First deployment
fly deploy --remote-only
```

After deployment, verify:
- Check logs: `fly logs --app emailgator-api`
- Test health endpoint: `curl https://emailgator-api.fly.dev/health`
- Run migrations manually if needed:
  ```bash
  fly ssh console --app emailgator-api -C "/app/bin/emailgator_api eval \"Emailgator.Release.migrate()\""
  ```

#### 3.2 Deploy Sidecar

```bash
cd sidecar

fly deploy --remote-only
```

Verify:
- Check logs: `fly logs --app emailgator-sidecar`
- Test health endpoint: `curl https://emailgator-sidecar.fly.dev/health`

#### 3.3 Deploy Frontend

The frontend will deploy automatically via GitHub Actions when you push to `main`, or you can trigger it manually:

1. Go to Vercel dashboard
2. Find your project
3. Click "Redeploy"

Or push to trigger GitHub Actions workflow.

### Phase 4: Verify Deployment

1. **Backend Health**: `curl https://emailgator-api.fly.dev/health`
2. **Sidecar Health**: `curl https://emailgator-sidecar.fly.dev/health`
3. **Frontend**: Visit your Vercel URL
4. **GraphQL Playground**: `https://emailgator-api.fly.dev/api/graphiql`

## CI/CD Workflows

The repository includes GitHub Actions workflows that automatically deploy on push to `main`:

- **`.github/workflows/api.yml`**: Tests, builds, and deploys backend
- **`.github/workflows/web.yml`**: Tests, builds, and deploys frontend
- **`.github/workflows/sidecar.yml`**: Tests and deploys sidecar

### Workflow Features

#### Backend Workflow (`api.yml`)
- Runs tests with PostgreSQL service
- Builds release
- Deploys to Fly.io
- Runs database migrations
- Performs health check

#### Frontend Workflow (`web.yml`)
- Installs dependencies
- Runs GraphQL codegen
- Builds Next.js application
- Deploys to Vercel (production)

#### Sidecar Workflow (`sidecar.yml`)
- Installs dependencies
- Verifies Docker build
- Deploys to Fly.io
- Performs health check

## Database Migrations

Migrations run automatically after backend deployment via GitHub Actions.

To run manually:

```bash
fly ssh console --app emailgator-api -C "/app/bin/emailgator_api eval \"Emailgator.Release.migrate()\""
```

## Monitoring and Debugging

### View Logs

```bash
# Backend
fly logs --app emailgator-api

# Sidecar
fly logs --app emailgator-sidecar

# Follow logs in real-time
fly logs --app emailgator-api -f
```

### SSH into Containers

```bash
# Backend
fly ssh console --app emailgator-api

# Sidecar
fly ssh console --app emailgator-sidecar
```

### Check App Status

```bash
fly status --app emailgator-api
fly status --app emailgator-sidecar
```

### View Secrets

```bash
fly secrets list --app emailgator-api
fly secrets list --app emailgator-sidecar
```

## Troubleshooting

### Backend Issues

**App won't start:**
- Check logs: `fly logs --app emailgator-api`
- Verify all secrets are set: `fly secrets list --app emailgator-api`
- Check DATABASE_URL is correct
- Verify SECRET_KEY_BASE is set

**Database connection errors:**
- Verify DATABASE_URL format
- Check if database is accessible from Fly.io region
- Try direct connection URL for migrations

**Health check failing:**
- Ensure health endpoint is accessible: `/health`
- Check if app is running: `fly status --app emailgator-api`
- Verify internal port is correct (4000)

### Frontend Issues

**Build fails:**
- Check if API is accessible for GraphQL codegen
- Verify `NEXT_PUBLIC_API_URL` is set correctly
- Check build logs in Vercel dashboard

**API connection errors:**
- Verify CORS is configured correctly
- Check `FRONTEND_URL` secret in backend matches Vercel URL
- Verify API health endpoint is accessible

### Sidecar Issues

**Authentication errors:**
- Verify `INTERNAL_TOKEN` matches `SIDECAR_TOKEN` in backend
- Check both secrets are set correctly

**Playwright issues:**
- Verify Dockerfile installs Chromium correctly
- Check logs for Playwright errors

### Database Issues

**Connection pooling:**
- Use pooled connection URL (port 6543) for application
- Use direct connection URL (port 5432) for migrations

**Migration failures:**
- Run migrations with direct connection URL
- Check database logs in Supabase dashboard

## Environment-Specific Configuration

### Development

- Use local PostgreSQL database
- Run `mix phx.server` locally
- Frontend connects to `http://localhost:4000`

### Production

- Use Supabase PostgreSQL
- Backend deployed to Fly.io
- Frontend deployed to Vercel
- All secrets managed via Fly.io and Vercel

## Security Best Practices

1. **Never commit secrets** to version control
2. **Use GitHub Secrets** for CI/CD tokens
3. **Use Fly.io Secrets** for application configuration
4. **Rotate secrets regularly**
5. **Enable Sentry** for error tracking (optional)
6. **Use connection pooling** for database (pooled URL)
7. **Keep dependencies updated**

## Scaling

### Fly.io Scaling

```bash
# Scale backend
fly scale count 2 --app emailgator-api

# Scale sidecar
fly scale count 2 --app emailgator-sidecar

# Set memory/CPU
fly scale vm shared-cpu-1x --memory 512 --app emailgator-api
```

### Database Scaling

- Upgrade Supabase plan for more resources
- Consider read replicas for high read workloads
- Monitor connection pool usage

## Backup and Recovery

### Database Backups

Supabase provides automatic backups. For manual backups:

1. Use Supabase dashboard → Database → Backups
2. Or use `pg_dump` via connection string

### Application State

- Database is the primary state store
- Oban jobs are stored in database
- User sessions stored in database

## Additional Resources

- [Fly.io Documentation](https://fly.io/docs)
- [Vercel Documentation](https://vercel.com/docs)
- [Supabase Documentation](https://supabase.com/docs)
- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
- [Terraform Supabase Provider](https://registry.terraform.io/providers/supabase/supabase/latest/docs)

## Support

For issues or questions:
1. Check logs using commands above
2. Review GitHub Actions workflow runs
3. Check Fly.io/Vercel dashboards for errors
4. Review this deployment guide
