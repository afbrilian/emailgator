# EmailGator First-Time Deployment Guide

This guide walks you through deploying EmailGator for the first time from scratch.

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] GitHub repository with your code pushed
- [ ] Fly.io account (sign up at [fly.io](https://fly.io))
- [ ] Vercel account (sign up at [vercel.com](https://vercel.com))
- [ ] Supabase account (sign up at [supabase.com](https://supabase.com))
- [ ] Google Cloud Platform account (for OAuth)
- [ ] OpenAI API key
- [ ] Terraform installed (`terraform --version`)
- [ ] Fly.io CLI installed (`fly version`)

## Step-by-Step Deployment

### Step 1: Infrastructure Setup (Terraform)

**1.1 Configure Terraform**

```bash
cd infra

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
supabase_api_key = "your-supabase-api-key"
supabase_org_id  = "your-organization-id"
project_name     = "emailgator"
database_password = "$(openssl rand -base64 32)"
region           = "us-east-1"
plan             = "free"
EOF
```

**Get Supabase credentials:**
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Navigate to Account Settings → Access Tokens
3. Generate a new token
4. Get Organization ID from dashboard URL or settings

**1.2 Initialize and Apply Terraform**

```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Apply configuration (type 'yes' when prompted)
terraform apply

# Save database URL for later
terraform output -raw database_url > /tmp/database_url.txt
echo "Database URL saved to /tmp/database_url.txt"
```

**Troubleshooting:**
- If provider authentication fails, verify API key and org ID
- If project creation fails, check if project name is unique
- If region is unavailable, try another region

**1.3 Verify Database**

```bash
# Test database connection
export DATABASE_URL=$(terraform output -raw database_url)
psql "$DATABASE_URL" -c "SELECT version();"
```

### Step 2: Create Fly.io Applications

**2.1 Install and Login**

```bash
# Install Fly.io CLI (if not installed)
curl -L https://fly.io/install.sh | sh

# Login to Fly.io
fly auth login
```

**2.2 Create Backend App**

```bash
cd apps/api

# Create the app
fly apps create emailgator-api

# Verify app was created
fly apps list
```

**2.3 Create Sidecar App**

```bash
cd ../../sidecar

# Create the app
fly apps create emailgator-sidecar

# Verify app was created
fly apps list
```

### Step 3: Configure Secrets

**3.1 Backend API Secrets**

```bash
cd ../../apps/api

# Database (from Terraform output)
fly secrets set DATABASE_URL="$(cd ../../infra && terraform output -raw database_url)" --app emailgator-api

# Generate and set secret key base
fly secrets set SECRET_KEY_BASE="$(mix phx.gen.secret)" --app emailgator-api

# Google OAuth (get from Google Cloud Console)
fly secrets set GOOGLE_CLIENT_ID="your-client-id.apps.googleusercontent.com" --app emailgator-api
fly secrets set GOOGLE_CLIENT_SECRET="your-client-secret" --app emailgator-api
fly secrets set GOOGLE_OAUTH_REDIRECT_URL="https://emailgator-api.fly.dev/auth/google/callback" --app emailgator-api

# OpenAI API key
fly secrets set OPENAI_API_KEY="your-openai-api-key" --app emailgator-api

# Generate sidecar token (save this!)
SIDECAR_TOKEN=$(openssl rand -base64 32)
echo "SIDECAR_TOKEN=$SIDECAR_TOKEN" >> /tmp/emailgator_secrets.txt
fly secrets set SIDECAR_TOKEN="$SIDECAR_TOKEN" --app emailgator-api
fly secrets set SIDECAR_URL="https://emailgator-sidecar.fly.dev" --app emailgator-api

# Frontend URL (will update after Vercel deployment)
fly secrets set FRONTEND_URL="https://your-app.vercel.app" --app emailgator-api

# Phoenix host
fly secrets set PHX_HOST="emailgator-api.fly.dev" --app emailgator-api
```

**3.2 Sidecar Secrets**

```bash
cd ../../sidecar

# Use the SIDECAR_TOKEN from above
# (Check /tmp/emailgator_secrets.txt or set manually)
fly secrets set INTERNAL_TOKEN="same-token-as-above" --app emailgator-sidecar
```

**3.3 Verify Secrets**

```bash
# Backend
fly secrets list --app emailgator-api

# Sidecar
fly secrets list --app emailgator-sidecar
```

### Step 4: Configure Google OAuth

**4.1 Create OAuth Credentials**

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Enable **Google+ API** and **Gmail API**
4. Go to **APIs & Services** → **Credentials**
5. Create **OAuth 2.0 Client ID** (Web application)
6. Add authorized redirect URIs:
   - `https://emailgator-api.fly.dev/auth/google/callback`
   - `https://emailgator-api.fly.dev/gmail/callback`
7. Copy **Client ID** and **Client Secret**

**4.2 Configure OAuth Consent Screen**

1. Go to **OAuth consent screen**
2. Choose **External** user type
3. Fill in required information
4. Add your email as a test user
5. Save and continue

### Step 5: Configure Vercel

**5.1 Create Vercel Project**

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Click **Add New** → **Project**
3. Import your GitHub repository
4. Configure project:
   - **Framework Preset**: Next.js
   - **Root Directory**: `apps/web`
   - **Build Command**: `npm run build`
   - **Output Directory**: `.next`
   - **Install Command**: `npm ci`
5. Click **Deploy** (will fail initially, that's OK)

**5.2 Configure Environment Variables**

1. Go to project settings → **Environment Variables**
2. Add:
   - `NEXT_PUBLIC_API_URL`: `https://emailgator-api.fly.dev`
3. Save and redeploy

**5.3 Get Vercel Project IDs**

1. Go to project settings → **General**
2. Note down:
   - **Organization ID**
   - **Project ID**
3. Save these for GitHub Secrets

**5.4 Get Vercel Token**

1. Go to Vercel → **Settings** → **Tokens**
2. Click **Create Token**
3. Name it "GitHub Actions"
4. Copy the token (save securely)

### Step 6: Configure GitHub Secrets

**6.1 Set Up Secrets**

1. Go to GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each:

```
FLY_API_TOKEN: $(fly auth token)
VERCEL_TOKEN: [from Vercel dashboard]
VERCEL_ORG_ID: [from Vercel project settings]
VERCEL_PROJECT_ID: [from Vercel project settings]
NEXT_PUBLIC_API_URL: https://emailgator-api.fly.dev
```

**6.2 Generate Fly.io Token**

```bash
fly auth token
```

Copy the output and paste into GitHub Secrets as `FLY_API_TOKEN`.

### Step 7: Initial Deployment

**7.1 Deploy Backend**

```bash
cd apps/api

# First deployment
fly deploy --remote-only

# Watch deployment logs
fly logs --app emailgator-api -f
```

**7.2 Run Database Migrations**

```bash
# Wait for deployment to complete, then run migrations
fly ssh console --app emailgator-api -C "/app/bin/emailgator_api eval \"Emailgator.Release.migrate()\""
```

**7.3 Verify Backend**

```bash
# Test health endpoint
curl https://emailgator-api.fly.dev/health

# Expected: {"status":"ok","timestamp":"..."}
```

**7.4 Deploy Sidecar**

```bash
cd ../../sidecar

# Deploy
fly deploy --remote-only

# Verify
curl https://emailgator-sidecar.fly.dev/health
```

**7.5 Deploy Frontend**

The frontend will deploy automatically via GitHub Actions when you push to `main`.

Alternatively, trigger manually in Vercel dashboard:
1. Go to project
2. Click **Redeploy**

### Step 8: Update Frontend URL in Backend

After Vercel deployment completes:

1. Get your Vercel URL (e.g., `https://emailgator.vercel.app`)
2. Update backend secret:

```bash
cd apps/api
fly secrets set FRONTEND_URL="https://your-vercel-url.vercel.app" --app emailgator-api
```

### Step 9: End-to-End Testing

**9.1 Test Health Endpoints**

```bash
# Backend
curl https://emailgator-api.fly.dev/health

# Sidecar
curl https://emailgator-sidecar.fly.dev/health
```

**9.2 Test OAuth Flow**

1. Visit your Vercel frontend URL
2. Click "Sign in with Google"
3. Complete OAuth flow
4. Verify redirect back to frontend
5. Check that you're signed in

**9.3 Test Gmail Connection**

1. In the frontend, click "Connect Gmail"
2. Complete OAuth flow
3. Verify Gmail account appears in "Email Accounts"
4. Check backend logs for polling jobs

**9.4 Test Email Polling**

1. Wait 2-3 minutes for polling cron to run
2. Check backend logs:
   ```bash
   fly logs --app emailgator-api | grep -i poll
   ```
3. Verify emails appear in categories in frontend

**9.5 Test Core Functionality**

1. Create a category
2. Verify emails are sorted into categories
3. Test bulk delete
4. Test unsubscribe (if test emails have unsubscribe links)

### Step 10: Post-Deployment Verification

**10.1 Check All Services**

- [ ] Backend health check returns OK
- [ ] Sidecar health check returns OK
- [ ] Frontend loads without errors
- [ ] GraphQL playground accessible
- [ ] OAuth sign-in works
- [ ] Gmail connection works
- [ ] Email polling is running
- [ ] Emails appear in categories

**10.2 Monitor Logs**

```bash
# Backend logs
fly logs --app emailgator-api -f

# Sidecar logs
fly logs --app emailgator-sidecar -f
```

Look for:
- No error messages
- PollCron jobs executing
- ImportEmail jobs processing
- Successful OAuth callbacks

**10.3 Check GitHub Actions**

1. Go to GitHub repository → **Actions**
2. Verify all workflows are passing
3. Check deployment status

## Troubleshooting Common Issues

### Backend Won't Start

**Check logs:**
```bash
fly logs --app emailgator-api
```

**Common causes:**
- Missing secrets (verify all are set)
- Invalid DATABASE_URL (test connection)
- Invalid SECRET_KEY_BASE

**Fix:**
1. Verify all secrets: `fly secrets list --app emailgator-api`
2. Test database connection
3. Regenerate SECRET_KEY_BASE if needed

### Database Connection Errors

**Test connection:**
```bash
export DATABASE_URL=$(terraform output -raw database_url)
psql "$DATABASE_URL" -c "SELECT 1;"
```

**If connection fails:**
- Check DATABASE_URL format
- Verify database is accessible from Fly.io region
- Check Supabase firewall settings

### OAuth Redirect Errors

**Verify redirect URIs:**
- Must match exactly in Google Cloud Console
- Must use HTTPS in production
- Check for trailing slashes

**Update redirect URIs:**
1. Google Cloud Console → APIs & Services → Credentials
2. Edit OAuth client
3. Add correct redirect URIs
4. Save

### Frontend Can't Connect to API

**Check CORS:**
- Verify FRONTEND_URL in backend matches Vercel URL
- Check backend logs for CORS errors
- Verify NEXT_PUBLIC_API_URL in Vercel

**Test API:**
```bash
curl -H "Origin: https://your-frontend.vercel.app" \
     -H "Access-Control-Request-Method: POST" \
     -X OPTIONS \
     https://emailgator-api.fly.dev/api/graphql
```

### Migrations Fail

**Run migrations manually:**
```bash
fly ssh console --app emailgator-api -C "/app/bin/emailgator_api eval \"Emailgator.Release.migrate()\""
```

**If migration fails:**
- Check database logs in Supabase
- Verify DATABASE_URL is correct
- Try using direct connection URL (port 5432) instead of pooled

### Sidecar Authentication Errors

**Verify tokens match:**
```bash
# Check backend token
fly secrets list --app emailgator-api | grep SIDECAR_TOKEN

# Check sidecar token
fly secrets list --app emailgator-sidecar | grep INTERNAL_TOKEN
```

They must be identical.

## Next Steps

After successful deployment:

1. **Set up monitoring:**
   - Configure Sentry (optional)
   - Set up Fly.io alerts
   - Enable Vercel analytics

2. **Custom domain (optional):**
   - See [DEPLOYMENT.md](./DEPLOYMENT.md) for custom domain setup

3. **Scaling:**
   - Monitor resource usage
   - Scale services as needed

4. **Backup strategy:**
   - Verify Supabase automatic backups
   - Test backup restoration

5. **Team access:**
   - Add team members to Fly.io org
   - Add team members to Vercel project
   - Set up proper access controls

## Support

If you encounter issues:

1. Check logs using commands above
2. Review [DEPLOYMENT.md](./DEPLOYMENT.md) troubleshooting section
3. Check GitHub Actions workflow runs
4. Review Fly.io and Vercel dashboards for errors

Congratulations! Your EmailGator deployment is complete. 🎉

