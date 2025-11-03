# Manual Environment Variables Setup

Guide for setting environment variables manually in Fly.io and Vercel (without GitHub Secrets).

## Overview

Yes, manual setup is perfectly fine! Our setup is designed to work both ways:
- **Automated**: GitHub Actions fetches from Terraform outputs and sets secrets automatically
- **Manual**: You copy values from Supabase/Terraform and set them in Fly.io/Vercel dashboards

## Important: Use Pooled Connection

Your Terraform output uses **Supabase's pooled connection** (port 6543), which is IPv4-compatible and works with Vercel, GitHub Actions, and all major platforms.

✅ **Use this format:**
```
postgresql://postgres.[PROJECT_ID]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres?pgbouncer=true
```

❌ **Don't use direct connection:**
```
postgresql://postgres:[PASSWORD]@db.[PROJECT_REF].supabase.co:5432/postgres
```

## Step-by-Step Manual Setup

### Step 1: Get Your Database Connection String

After running Terraform, get your connection string:

#### Option A: From Terraform Output
```bash
cd infra
terraform output -raw database_url
```

This outputs something like:
```
postgresql://postgres.abcdef123456:YourGeneratedPassword@aws-0-us-east-1.pooler.supabase.com:6543/postgres?pgbouncer=true
```

#### Option B: From Supabase Dashboard

Based on the screenshot you shared:

1. Go to your Supabase project dashboard
2. Click **Settings** → **Database**
3. Find the connection string section
4. **Important**: Select these settings:
   - Type: **URI**
   - Source: **Primary Database**
   - **Method: Session Pooler** (this is IPv4-compatible!)

The Session Pooler connection string will look like:
```
postgresql://postgres.[REF].pooler.supabase.com:6543/postgres?pgbouncer=true
```

5. Copy the entire connection string
6. Replace `[YOUR-PASSWORD]` with your actual database password

### Step 2: Set Fly.io Secrets

#### For Backend API

```bash
cd apps/api

# Database (use the pooled connection from above)
fly secrets set DATABASE_URL="postgresql://postgres.xxxxx:your-password@aws-0-us-east-1.pooler.supabase.com:6543/postgres?pgbouncer=true" --app emailgator-api

# Generate secret key base
fly secrets set SECRET_KEY_BASE="$(mix phx.gen.secret)" --app emailgator-api

# Google OAuth (get from Google Cloud Console)
fly secrets set GOOGLE_CLIENT_ID="your-client-id" --app emailgator-api
fly secrets set GOOGLE_CLIENT_SECRET="your-client-secret" --app emailgator-api
fly secrets set GOOGLE_OAUTH_REDIRECT_URL="https://emailgator-api.fly.dev/auth/google/callback" --app emailgator-api

# OpenAI
fly secrets set OPENAI_API_KEY="your-openai-api-key" --app emailgator-api

# Sidecar configuration (generate a token first)
SIDECAR_TOKEN=$(openssl rand -base64 32)
echo "Save this SIDECAR_TOKEN: $SIDECAR_TOKEN"

fly secrets set SIDECAR_URL="https://emailgator-sidecar.fly.dev" --app emailgator-api
fly secrets set SIDECAR_TOKEN="$SIDECAR_TOKEN" --app emailgator-api

# Frontend URL (update after Vercel deployment)
fly secrets set FRONTEND_URL="https://your-vercel-app.vercel.app" --app emailgator-api

# Phoenix host
fly secrets set PHX_HOST="emailgator-api.fly.dev" --app emailgator-api
```

#### For Sidecar

```bash
cd sidecar

# Use the same SIDECAR_TOKEN you saved above
fly secrets set INTERNAL_TOKEN="paste-same-token-here" --app emailgator-sidecar

# Optional: Domain allowlist
fly secrets set ALLOWLIST_DOMAINS="example.com,another-domain.com" --app emailgator-sidecar
```

#### Verify Fly.io Secrets

```bash
# Check backend secrets
fly secrets list --app emailgator-api

# Check sidecar secrets
fly secrets list --app emailgator-sidecar
```

### Step 3: Set Vercel Environment Variables

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Select your project
3. Go to **Settings** → **Environment Variables**
4. Add the following:

| Variable Name | Value | Environment |
|--------------|-------|-------------|
| `NEXT_PUBLIC_API_URL` | `https://emailgator-api.fly.dev` | Production, Preview, Development |
| (Add any other Next.js env vars you need) | | |

5. Click **Save**

#### Verify Vercel Variables

```bash
# Install Vercel CLI if not already installed
npm i -g vercel

# Check environment variables
vercel env ls
```

### Step 4: Alternative - Set via Vercel CLI

If you prefer command line:

```bash
cd apps/web

# Add environment variable
vercel env add NEXT_PUBLIC_API_URL production

# When prompted, enter: https://emailgator-api.fly.dev

# Pull environment variables locally (optional)
vercel env pull .env.local
```

## Troubleshooting

### Issue: "Not IPv4 compatible" Error

**Problem**: You used a direct connection string instead of pooled connection.

**Solution**: Use the **Session Pooler** connection string:
```
❌ postgresql://postgres:[PASSWORD]@db.xxx.supabase.co:5432/postgres
✅ postgresql://postgres.xxx:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres?pgbouncer=true
```

**How to get it from Supabase Dashboard**:
1. Go to Settings → Database → Connection String
2. Set Method to **Session Pooler** (not Direct connection)
3. Copy that connection string

### Issue: Fly.io can't connect to database

**Check**: Is your DATABASE_URL using the pooled connection?
```bash
fly secrets list --app emailgator-api | grep DATABASE_URL
```

Should show something like:
```
DATABASE_URL = postgresql://postgres.xxx:xxx@aws-0-us-east-1.pooler.supabase.com:6543/postgres?pgbouncer=true
```

### Issue: Vercel build fails

**Check**: Did you set `NEXT_PUBLIC_API_URL` in Vercel?
1. Go to Vercel Dashboard → Your Project → Settings → Environment Variables
2. Verify `NEXT_PUBLIC_API_URL` is set
3. Redeploy after adding variables

### Issue: "Connection refused" or "Host not found"

**Possible causes**:
1. Wrong region in connection string
2. Password with special characters not URL-encoded
3. Using direct connection instead of pooled connection

**Solution**: 
1. Double-check the connection string format
2. Ensure you're using port **6543** (pooled), not **5432** (direct)
3. Try regenerating the connection string from Supabase dashboard with Session Pooler selected

## Comparing Manual vs Automated Setup

| Aspect | Manual Setup | Automated (GitHub Actions) |
|--------|-------------|---------------------------|
| **Speed** | Faster initial setup | Slower, requires GitHub Secrets |
| **Control** | Full control over each value | Values pulled from Terraform |
| **Updates** | Must manually update each place | Auto-updates on terraform apply |
| **Team Use** | Everyone needs to know values | Secrets stored centrally |
| **CI/CD** | Works perfectly | Works perfectly |
| **IPv4 Support** | ✅ Yes (use pooled connection) | ✅ Yes (Terraform outputs pooled) |

**Recommendation**: For solo development, manual setup is fine. For teams or production, consider the automated approach with GitHub Secrets.

## Security Best Practices

1. ✅ **Never commit** connection strings or passwords to git
2. ✅ **Use pooled connections** for IPv4 compatibility
3. ✅ **Rotate secrets** periodically (especially database password)
4. ✅ **Use different passwords** for different environments
5. ✅ **Limit access** to Fly.io secrets (use team permissions)

## Quick Reference: Connection String Formats

### ❌ Direct Connection (IPv6 only, not compatible with Vercel/GitHub Actions)
```
postgresql://postgres:[PASSWORD]@db.[PROJECT_REF].supabase.co:5432/postgres
```

### ✅ Pooled Connection (IPv4 compatible, recommended)
```
postgresql://postgres.[PROJECT_ID]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres?pgbouncer=true
```

### ✅ Transaction Pooler (Alternative if Session doesn't work)
```
postgresql://postgres.[PROJECT_ID]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres?pgbouncer=true&pg_bouncer_mode=transaction
```

## Where to Get Each Part

| Part | Where to Find |
|------|---------------|
| `[PROJECT_ID]` | Terraform output: `terraform output project_id` or Supabase URL |
| `[PASSWORD]` | From `terraform.tfvars` or Supabase Dashboard Settings |
| `[REGION]` | From your Terraform configuration (e.g., `us-east-1`) |
| Full Connection String | Terraform output: `terraform output -raw database_url` |

## Need Help?

- **Terraform Output**: Run `cd infra && terraform output` to see all available values
- **Supabase Dashboard**: Settings → Database → Connection String
- **Fly.io**: `fly secrets list --app emailgator-api` to verify secrets
- **Vercel**: Dashboard → Project → Settings → Environment Variables

## Next Steps

After setting variables manually:
1. ✅ Deploy backend API to Fly.io
2. ✅ Deploy frontend to Vercel
3. ✅ Verify connections work
4. ✅ Run health checks
5. ✅ See [DEPLOYMENT.md](./DEPLOYMENT.md) Phase 4 for verification steps

---

**Your setup is already configured for manual variable management!** The Terraform outputs provide all the values you need, and the pooled connection is IPv4-compatible for all platforms. 🎉

