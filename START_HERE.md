# Quick Start Guide

Follow these steps to get the app running locally.

## Step 1: Start PostgreSQL (Docker Compose)

```bash
# From project root
docker-compose up -d

# Verify it's running
docker ps | grep postgres
```

## Step 2: Run Database Migrations

```bash
cd apps/api

# This creates all tables (users, accounts, categories, emails, etc.)
mix ecto.migrate
```

You should see output like:
```
[info] == Running 20241101000001_create_users.up/0 forward
[info] == Running 20241101000002_create_accounts.up/0 forward
...
```

## Step 3: Verify Tables Created

```bash
# Connect to database
docker exec -it emailgator_postgres psql -U postgres -d emailgator_dev

# In psql, list tables:
\dt

# You should see:
# - schema_migrations
# - users
# - accounts
# - categories
# - emails
# - unsubscribe_attempts
# - oban_jobs

# Exit psql:
\q
```

## Step 4: Set Up Environment Variables

### Minimum Required (for development):

Create `apps/api/.env` (or export in your shell):

```bash
# Google OAuth (for user sign-in)
# Get these from: https://console.cloud.google.com/
GOOGLE_CLIENT_ID=your-client-id-here
GOOGLE_CLIENT_SECRET=your-client-secret-here
GOOGLE_OAUTH_REDIRECT_URL=http://localhost:4000/auth/google/callback

# OpenAI (for email classification)
OPENAI_API_KEY=your-openai-api-key-here

# Frontend URL (for OAuth redirect)
FRONTEND_URL=http://localhost:3000

# Sidecar (optional for now)
SIDECAR_URL=http://localhost:3001
SIDECAR_TOKEN=supersecret
```

### For Development (Quick Start):

You can start the app WITHOUT these, but OAuth and email classification won't work:

```bash
cd apps/api
mix phx.server
```

The app will start, but:
- Sign-in with Google won't work (needs `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`)
- Email classification won't work (needs `OPENAI_API_KEY`)

## Step 5: Start the Phoenix Server

```bash
cd apps/api
mix phx.server
```

You should see:
```
[info] Running EmailgatorWeb.Endpoint with cowboy 2.10.0 at http://localhost:4000
```

Visit: http://localhost:4000/api/graphiql (GraphQL playground)

## Step 6: Start Frontend (Next.js)

In a new terminal:

```bash
cd apps/web

# Install dependencies (first time only)
npm install
# or
pnpm install

# Create .env.local
echo "NEXT_PUBLIC_API_URL=http://localhost:4000" > .env.local

# Start dev server
npm run dev
# or
pnpm dev
```

Visit: http://localhost:3000

## Troubleshooting

### "Database doesn't exist"
```bash
cd apps/api
mix ecto.create
mix ecto.migrate
```

### "Connection refused" when starting server
- Make sure Docker Compose is running: `docker-compose ps`
- Check PostgreSQL is up: `docker-compose logs postgres`

### "Tables not found"
- Run migrations: `mix ecto.migrate`
- Check migrations status: `mix ecto.migrations`

### OAuth not working
- Make sure `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are set
- Verify redirect URI matches in Google Cloud Console
- Add your email as a test user in OAuth consent screen

## Next Steps

Once the app is running:
1. Set up Google OAuth in Google Cloud Console
2. Get OpenAI API key
3. Test the OAuth flow
4. Start building frontend UI

