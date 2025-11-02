# Environment Variables Guide

This project supports multiple environments: **local**, **dev**, and **production**. All environment-specific values are controlled via environment variables.

## Environment Strategy

### Local Development
- Uses `.env` files (loaded automatically via `dotenv` for backend, Next.js for frontend)
- Sensible defaults for localhost
- No external dependencies required

### Dev/Staging
- Environment variables set in deployment platform (Fly.io, Vercel)
- Separate databases and API endpoints
- Uses same codebase, different config

### Production
- Environment variables set in deployment platform
- Production databases (Supabase)
- Production API endpoints
- All secrets secured

## Frontend Environment Variables

**Location**: `apps/web/.env.local` (local), Vercel Environment Variables (deployed)

### Required

```bash
# Backend API URL (used for GraphQL, OAuth redirects, all API calls)
NEXT_PUBLIC_API_URL=http://localhost:4000
```

**Environment-specific values:**
- **Local**: `http://localhost:4000`
- **Dev**: `https://api-dev.yourdomain.com`
- **Prod**: `https://api.yourdomain.com`

**Where it's used:**
- `src/lib/config.ts` - Centralized API configuration
- `src/lib/apollo.ts` - GraphQL client
- `codegen.config.js` - GraphQL code generation
- All API endpoint links (auth, gmail, etc.)

### Optional

```bash
# Only needed if different from default
# NEXT_PUBLIC_API_URL already has localhost:4000 as default
```

## Backend Environment Variables

**Location**: `apps/api/.env` (local), Fly.io Secrets (deployed)

### Required for Production

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:5432/dbname
POOL_SIZE=10  # Optional, defaults to 10

# Phoenix
SECRET_KEY_BASE=<generate with: mix phx.gen.secret>
PHX_HOST=api.yourdomain.com  # Optional, defaults to example.com
PORT=4000  # Optional, defaults to 4000

# Google OAuth
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_OAUTH_REDIRECT_URL=https://api.yourdomain.com/auth/google/callback

# OpenAI
OPENAI_API_KEY=sk-...
OPENAI_BASE_URL=https://api.openai.com/v1  # Optional

# Sidecar
SIDECAR_URL=http://localhost:3001
SIDECAR_TOKEN=supersecret

# Frontend URL (for OAuth redirects)
FRONTEND_URL=https://app.yourdomain.com  # Optional, defaults to localhost:3000
```

### Local Development Defaults

The following have defaults in `config/dev.exs`:

```bash
# Optional - only set if different from defaults
GOOGLE_CLIENT_ID=dev-client-id  # Default if not set
GOOGLE_CLIENT_SECRET=dev-client-secret  # Default if not set
GOOGLE_OAUTH_REDIRECT_URL=http://localhost:4000/auth/google/callback  # Default

FRONTEND_URL=http://localhost:3000  # Default

# Database uses config/dev.exs defaults:
# - hostname: localhost
# - username: postgres
# - password: postgres
# - database: emailgator_dev
```

### Environment-Specific Examples

#### Local Development

```bash
# apps/api/.env
GOOGLE_CLIENT_ID=your-real-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-real-client-secret
# Other vars use defaults from config/dev.exs

# apps/web/.env.local
NEXT_PUBLIC_API_URL=http://localhost:4000
```

#### Dev/Staging Environment

**Backend (Fly.io secrets):**
```bash
DATABASE_URL=postgresql://user:pass@dev-db.supabase.co:5432/emailgator_dev
SECRET_KEY_BASE=<generated-secret>
GOOGLE_CLIENT_ID=<dev-oauth-client-id>
GOOGLE_CLIENT_SECRET=<dev-oauth-secret>
GOOGLE_OAUTH_REDIRECT_URL=https://api-dev.yourdomain.com/auth/google/callback
FRONTEND_URL=https://app-dev.yourdomain.com
OPENAI_API_KEY=sk-...
```

**Frontend (Vercel environment variables):**
```
NEXT_PUBLIC_API_URL=https://api-dev.yourdomain.com
```

#### Production Environment

**Backend (Fly.io secrets):**
```bash
DATABASE_URL=postgresql://user:pass@prod-db.supabase.co:5432/emailgator_prod
SECRET_KEY_BASE=<generated-secret>
GOOGLE_CLIENT_ID=<prod-oauth-client-id>
GOOGLE_CLIENT_SECRET=<prod-oauth-secret>
GOOGLE_OAUTH_REDIRECT_URL=https://api.yourdomain.com/auth/google/callback
FRONTEND_URL=https://app.yourdomain.com
OPENAI_API_KEY=sk-...
```

**Frontend (Vercel environment variables):**
```
NEXT_PUBLIC_API_URL=https://api.yourdomain.com
```

## Codegen Environment Variables

GraphQL code generation uses `NEXT_PUBLIC_API_URL`:

```bash
# Local (default)
cd apps/web
npm run codegen

# Dev environment
NEXT_PUBLIC_API_URL=https://api-dev.yourdomain.com npm run codegen

# Production
NEXT_PUBLIC_API_URL=https://api.yourdomain.com npm run codegen
```

**Note**: Codegen reads from the running API server, so ensure the API is running at the specified URL before running codegen.

## Setting Environment Variables

### Local Development

**Frontend (Next.js):**
```bash
cd apps/web
echo "NEXT_PUBLIC_API_URL=http://localhost:4000" > .env.local
```

**Backend (Phoenix):**
```bash
cd apps/api
cp .env.example .env
# Edit .env with your values
```

### Fly.io (Backend)

```bash
fly secrets set DATABASE_URL="postgresql://..."
fly secrets set GOOGLE_CLIENT_ID="..."
fly secrets set GOOGLE_CLIENT_SECRET="..."
# ... etc
```

### Vercel (Frontend)

1. Go to Vercel Dashboard > Project > Settings > Environment Variables
2. Add variables:
   - `NEXT_PUBLIC_API_URL` (for each environment: development, preview, production)
3. Redeploy

## Verification

### Check if environment variables are loaded:

**Frontend:**
```bash
cd apps/web
node -e "console.log(process.env.NEXT_PUBLIC_API_URL)"
```

**Backend:**
```bash
cd apps/api
iex -S mix
iex> System.get_env("GOOGLE_CLIENT_ID")
```

## Security Notes

- ✅ `.env` and `.env.local` files are in `.gitignore`
- ✅ Never commit environment variables to git
- ✅ Use `.env.example` as template (without real values)
- ✅ Production secrets should be set via deployment platform secrets management
- ✅ `NEXT_PUBLIC_*` variables are exposed to browser (only use for non-sensitive values)

