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

**Choose your approach:**
- **Recommended**: Automated via GitHub Actions CI/CD - See [INFRA_CICD_SETUP.md](./INFRA_CICD_SETUP.md)
- **Manual**: Local Terraform deployment - See instructions below

#### 1.1 Provision Database with Terraform

**For GitHub Actions CI/CD** (recommended):
👉 See [INFRA_CICD_SETUP.md](./INFRA_CICD_SETUP.md) for complete step-by-step instructions.

**For manual deployment:**

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
   - Build Command: `npm run build:with-codegen`
   - Output Directory: `.next`
4. Save project (deployment will be configured via GitHub Actions later)

**Note**: The build command includes GraphQL codegen. For first deployment before the API is live, the frontend will use existing generated types from the repository. After the backend is deployed, codegen will run against the live API.

### Phase 2: Configure Secrets

**Choose your approach:**
- **Recommended**: Manual setup via Fly.io/Vercel dashboards - See [MANUAL_VARIABLES_SETUP.md](./MANUAL_VARIABLES_SETUP.md)
- **Alternative**: Use the commands below to set secrets via CLI (requires terraform output)

#### 2.1 Fly.io Secrets (Backend API)

Set all required secrets for the backend:

**Quick Manual Setup:** See [MANUAL_VARIABLES_SETUP.md](./MANUAL_VARIABLES_SETUP.md) for step-by-step instructions using dashboards.

**CLI Method** (requires Terraform to be set up locally):

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

**Manual Setup:** See [MANUAL_VARIABLES_SETUP.md](./MANUAL_VARIABLES_SETUP.md) for detailed dashboard instructions.

**Quick Setup:**

1. Go to your Vercel project settings
2. Navigate to Environment Variables
3. Add:
   - `NEXT_PUBLIC_API_URL`: `https://emailgator-api.fly.dev`
   - Any other environment variables needed

#### 2.4 GitHub Secrets

GitHub Secrets are required for CI/CD workflows to deploy your applications automatically. These secrets are stored securely and never exposed in logs.

**If you're using Infrastructure CI/CD** (see [INFRA_CICD_SETUP.md](./INFRA_CICD_SETUP.md)), you've already configured some of these secrets in Step 3 of that guide.

**Setting up GitHub Secrets:**

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each secret below

**Required Secrets:**

| Secret Name | Description | How to Get |
|------------|-------------|------------|
| `FLY_API_TOKEN` | Fly.io API token for deploying backend and sidecar | Run: `fly auth token` |
| `VERCEL_TOKEN` | Vercel API token for deploying frontend | Vercel Dashboard → Settings → Tokens → Create Token |
| `VERCEL_ORG_ID` | Vercel organization ID | Vercel Project Settings → General → Organization ID |
| `VERCEL_PROJECT_ID` | Vercel project ID | Vercel Project Settings → General → Project ID |
| `NEXT_PUBLIC_API_URL` | Production API URL for GraphQL codegen and frontend | `https://emailgator-api.fly.dev` (or your custom domain) |

**Infrastructure CI/CD Secrets** (if using GitHub Actions for Terraform):

| Secret Name | Description | How to Get |
|------------|-------------|------------|
| `SUPABASE_API_KEY` | Supabase API token for Terraform | Supabase Dashboard → Account Settings → Access Tokens |
| `SUPABASE_ORG_ID` | Supabase organization ID | Supabase Dashboard → Organization settings |
| `DATABASE_PASSWORD` | Secure password for database | Generate: `openssl rand -base64 32` |

**Optional Secrets:**

| Secret Name | Description | When to Use |
|------------|-------------|-------------|
| `DATABASE_URL` | Database connection string for CI tests | Only if running database tests in CI |
| `SECRET_KEY_BASE` | Phoenix secret key for CI builds | Only if building releases in CI (uses dummy value) |
| `TERRAFORM_PROJECT_NAME` | Override default Terraform project name | Default: `emailgator` |
| `TERRAFORM_REGION` | Override default AWS region | Default: `us-east-1` |
| `TERRAFORM_PLAN` | Override default Supabase plan | Default: `free` |

**Detailed Setup Instructions:**

##### FLY_API_TOKEN

```bash
# Install Fly.io CLI if not already installed
curl -L https://fly.io/install.sh | sh

# Login to Fly.io
fly auth login

# Generate token
fly auth token
```

Copy the output and paste it into GitHub Secrets as `FLY_API_TOKEN`.

##### VERCEL_TOKEN

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Click your profile icon → **Settings**
3. Go to **Tokens** section
4. Click **Create Token**
5. Give it a name (e.g., "GitHub Actions")
6. Set expiration (recommended: 1 year or no expiration)
7. Copy the token and paste it into GitHub Secrets as `VERCEL_TOKEN`

**Important**: Store this token securely. It provides full access to your Vercel projects.

##### VERCEL_ORG_ID and VERCEL_PROJECT_ID

1. Go to your Vercel project
2. Click **Settings** → **General**
3. Find **Organization ID** and **Project ID** in the overview section
4. Copy each and add to GitHub Secrets

Alternatively, you can find these in the Vercel API:
- Organization ID: Found in project API responses
- Project ID: Visible in project settings URL: `vercel.com/[org]/[project]`

##### NEXT_PUBLIC_API_URL

Set this to your production API URL. After deploying the backend, use:
- Default: `https://emailgator-api.fly.dev`
- Custom domain: `https://api.yourdomain.com` (if configured)

**Important Notes:**

- GitHub Secrets are encrypted and only accessible to GitHub Actions
- Secrets are not exposed in logs (GitHub automatically masks them)
- Never commit secrets to your repository
- Rotate secrets periodically for security
- If using Terraform in CI/CD, add `SUPABASE_API_KEY` as a secret

**Verifying Secrets:**

After setting secrets, you can verify they're working by:
1. Pushing to the `main` branch
2. Checking the GitHub Actions workflow runs
3. Looking for successful deployments (not authentication errors)

If deployment fails with authentication errors, double-check:
- Secret names match exactly (case-sensitive)
- Token values are correct and not expired
- Required secrets are set for all workflows

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

#### 4.1 Post-Deployment Verification

After deploying all services, verify everything is working:

**Health Check Endpoints:**

```bash
# Backend health
curl https://emailgator-api.fly.dev/health
# Expected: {"status":"ok","timestamp":"..."}

# Sidecar health
curl https://emailgator-sidecar.fly.dev/health
# Expected: {"status":"ok"}
```

**Database Connectivity:**

```bash
# SSH into backend and verify database connection
fly ssh console --app emailgator-api -C "/app/bin/emailgator_api eval \"Emailgator.Repo.query_one(\\\"SELECT 1\\\", [])\""
```

**OAuth Flow Test:**

1. Visit your frontend URL
2. Click "Sign in with Google"
3. Verify redirect to Google OAuth
4. Complete OAuth flow
5. Verify successful redirect back to frontend
6. Check that user session is created

**Email Polling Verification:**

1. Connect a Gmail account via the frontend
2. Check backend logs: `fly logs --app emailgator-api`
3. Verify `PollCron` job is running (check every 2 minutes)
4. Verify `PollInbox` jobs are queued
5. Check that emails appear in categories after polling

**Unsubscribe Functionality Test:**

1. Find an email with an unsubscribe link
2. Click unsubscribe in the frontend
3. Check backend logs for unsubscribe job execution
4. Verify sidecar logs: `fly logs --app emailgator-sidecar`
5. Check unsubscribe attempt record in database

**Error Logging Verification (if Sentry is configured):**

1. Trigger a test error (e.g., invalid API call)
2. Check Sentry dashboard for error reports
3. Verify error context and stack traces are captured

**Frontend Verification:**

1. Visit your Vercel deployment URL
2. Verify all pages load correctly
3. Test GraphQL queries (open browser console)
4. Verify API calls are using correct endpoint
5. Check for CORS errors in browser console

**GraphQL Playground:**

Visit: `https://emailgator-api.fly.dev/api/graphiql`

Test a query:
```graphql
query {
  me {
    id
    email
    name
  }
}
```

**Service Integration Test:**

1. Sign in to frontend
2. Create a category
3. Connect Gmail account
4. Wait for email polling (2 minutes)
5. Verify emails appear in categories
6. Test bulk actions (delete, unsubscribe)

If all checks pass, your deployment is successful!

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

## Monitoring and Alerting Setup

### Sentry Error Tracking

Sentry provides real-time error tracking and performance monitoring.

**Setup:**

1. Create account at [sentry.io](https://sentry.io)
2. Create a new project (Phoenix/Elixir)
3. Get your DSN from project settings
4. Set as Fly.io secret:
   ```bash
   fly secrets set SENTRY_DSN="your-sentry-dsn" --app emailgator-api
   ```

**Features:**
- Automatic error capture
- Stack traces with source maps
- Performance monitoring
- Release tracking
- User context tracking

**Access Sentry:**
- Dashboard: [sentry.io](https://sentry.io)
- Set up alerts for critical errors
- Configure notification channels (Slack, email, etc.)

### Fly.io Metrics and Alerts

**View Metrics:**

1. Go to Fly.io dashboard
2. Select your app
3. Navigate to **Metrics** tab

**Available Metrics:**
- CPU usage
- Memory usage
- Request rate
- Response times
- Error rates

**Set up Alerts:**

1. In Fly.io dashboard → **Alerts**
2. Create alert rules:
   - High error rate (> 5% errors)
   - High memory usage (> 80%)
   - App not responding
   - Health check failures

**Monitor via CLI:**
```bash
# View metrics
fly metrics --app emailgator-api

# Watch metrics in real-time
fly monitor --app emailgator-api
```

### Vercel Analytics

Vercel provides built-in analytics for Next.js applications.

**Enable:**

1. Go to Vercel project settings
2. Navigate to **Analytics** tab
3. Enable **Web Analytics**
4. Enable **Speed Insights** (optional)

**View Analytics:**
- Vercel Dashboard → Your Project → Analytics
- Track page views, performance, and user behavior

### Database Monitoring (Supabase)

**Monitor in Supabase Dashboard:**

1. Go to Supabase project dashboard
2. Navigate to **Database** → **Performance**
3. Monitor:
   - Query performance
   - Connection pool usage
   - Database size
   - Slow queries

**Set up Alerts:**

1. Supabase Dashboard → **Settings** → **Alerts**
2. Configure alerts for:
   - High connection count
   - Slow queries
   - Disk space usage
   - Failed connections

### Oban Job Monitoring

Monitor background jobs via Phoenix Live Dashboard or direct queries:

**Via Phoenix Live Dashboard:**
- Access at: `https://emailgator-api.fly.dev/dashboard`
- Navigate to **Oban** section
- Monitor job queues, failures, and execution times

**Via Database Queries:**

```bash
# SSH into backend
fly ssh console --app emailgator-api

# Query Oban jobs
/app/bin/emailgator_api remote
> import Ecto.Query
> from(j in Oban.Job, where: j.state == "discarded") |> Emailgator.Repo.all() |> length()
```

**Set up Alerts for Job Failures:**

Monitor `oban_jobs` table for:
- High number of discarded jobs
- Stuck executing jobs
- Jobs exceeding max attempts

### Log Aggregation (Optional)

For better log management, consider:
- **Fly.io Log Drains**: Send logs to external services (Datadog, Logtail, etc.)
- **Vercel Log Drains**: Similar functionality for frontend logs

**Setup Fly.io Log Drain:**

```bash
fly log-drain add <service-url> --app emailgator-api
```

### Health Check Monitoring

Set up external monitoring services:
- **Uptime Robot**: Monitor health endpoints
- **Pingdom**: Track service availability
- **StatusCake**: Multi-location monitoring

**Monitor endpoints:**
- Backend: `https://emailgator-api.fly.dev/health`
- Sidecar: `https://emailgator-sidecar.fly.dev/health`

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

## Custom Domain Setup

### Fly.io Custom Domain (Backend)

1. **Add domain to Fly.io:**
   ```bash
   fly certs add api.yourdomain.com --app emailgator-api
   ```

2. **Update DNS records:**
   - Fly.io will provide DNS configuration
   - Add CNAME or A record as instructed
   - Wait for DNS propagation (usually 5-60 minutes)

3. **Verify SSL certificate:**
   ```bash
   fly certs show api.yourdomain.com --app emailgator-api
   ```

4. **Update secrets:**
   ```bash
   fly secrets set PHX_HOST="api.yourdomain.com" --app emailgator-api
   fly secrets set GOOGLE_OAUTH_REDIRECT_URL="https://api.yourdomain.com/auth/google/callback" --app emailgator-api
   ```

5. **Update OAuth redirect URIs in Google Cloud Console:**
   - Add `https://api.yourdomain.com/auth/google/callback`
   - Add `https://api.yourdomain.com/gmail/callback`

### Vercel Custom Domain (Frontend)

1. **Add domain in Vercel:**
   - Go to project settings → Domains
   - Add your domain (e.g., `yourdomain.com`)
   - Add `www.yourdomain.com` if needed

2. **Configure DNS:**
   - Vercel provides DNS records to add
   - Add A or CNAME records as instructed
   - Wait for DNS propagation

3. **SSL Certificate:**
   - Vercel automatically provisions SSL certificates
   - Usually takes a few minutes after DNS propagation

4. **Update environment variables:**
   - Update `NEXT_PUBLIC_API_URL` in Vercel to point to your custom API domain
   - Update `FRONTEND_URL` in Fly.io backend secrets

### CORS Configuration

If using custom domains, ensure CORS is configured:

1. **Update backend CORS settings:**
   - In `apps/api/lib/emailgator_web/router.ex` or CORS plug configuration
   - Add frontend domain to allowed origins

2. **Verify CORS headers:**
   ```bash
   curl -H "Origin: https://yourdomain.com" \
        -H "Access-Control-Request-Method: POST" \
        -H "Access-Control-Request-Headers: Content-Type" \
        -X OPTIONS \
        https://api.yourdomain.com/api/graphql
   ```

### DNS Configuration Examples

**For API subdomain:**
```
Type: CNAME
Name: api
Value: emailgator-api.fly.dev
```

**For main domain:**
```
Type: A
Name: @
Value: [Vercel IP addresses]
```

**For www subdomain:**
```
Type: CNAME
Name: www
Value: cname.vercel-dns.com
```

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

## Rollback Procedures

If a deployment causes issues, follow these rollback procedures:

### Database Migration Rollback

**If a migration causes issues:**

1. Identify the problematic migration version
2. SSH into the backend:
   ```bash
   fly ssh console --app emailgator-api
   ```
3. Rollback to previous version:
   ```bash
   /app/bin/emailgator_api eval "Emailgator.Release.rollback(Emailgator.Repo, <version>)"
   ```
   Replace `<version>` with the migration version number

**Emergency rollback:**

If you need to rollback multiple migrations:
```bash
fly ssh console --app emailgator-api -C "/app/bin/emailgator_api eval \"Ecto.Migrator.with_repo(Emailgator.Repo, &Ecto.Migrator.run(&1, :down, to: <version>))\""
```

### Application Rollback (Fly.io)

**Rollback to previous release:**

```bash
# List releases
fly releases --app emailgator-api

# Rollback to specific release
fly releases rollback <release-id> --app emailgator-api
```

**Rollback backend to previous image:**

```bash
# Deploy previous version
fly deploy --app emailgator-api --image <previous-image-hash>
```

You can find image hashes in:
- Fly.io dashboard → App → Releases
- Or via: `fly releases list --app emailgator-api`

**Rollback sidecar:**

Same procedure:
```bash
fly releases rollback <release-id> --app emailgator-sidecar
```

### Frontend Rollback (Vercel)

1. Go to Vercel dashboard
2. Select your project
3. Go to **Deployments** tab
4. Find the previous working deployment
5. Click **⋯** (three dots) → **Promote to Production**

Or via Vercel CLI:
```bash
vercel rollback
```

### Emergency Procedures

**If services are completely down:**

1. **Stop problematic deployments:**
   ```bash
   fly apps pause emailgator-api
   fly apps pause emailgator-sidecar
   ```

2. **Rollback all services to last known good state**

3. **Restore database from backup:**
   - Use Supabase dashboard → Database → Backups
   - Restore to point before problematic deployment

4. **Verify rollback:**
   - Check health endpoints
   - Test critical functionality
   - Monitor logs for errors

5. **Resume services:**
   ```bash
   fly apps resume emailgator-api
   fly apps resume emailgator-sidecar
   ```

**If database is corrupted:**

1. Restore from Supabase backup
2. Verify data integrity
3. Redeploy applications with correct database URL

**Preventing Rollback Issues:**

- Always test migrations locally first
- Use feature flags for risky changes
- Deploy to staging environment first
- Keep database backups before major deployments
- Monitor deployments closely for the first 15 minutes

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
