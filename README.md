# EmailGator - AI Email Sorting App

AI-powered email sorting application built with Phoenix/Elixir, Next.js, and OpenAI.

## Features

- Google OAuth sign-in
- Multi-Gmail account support
- AI-powered email classification and summarization
- Custom categories with descriptions
- Automatic email archiving
- Bulk email management (delete, unsubscribe)
- Automated unsubscribe agent

## Tech Stack

- **Backend**: Phoenix 1.7+ (Elixir) with Absinthe GraphQL
- **Frontend**: Next.js 14 (App Router) with TypeScript
- **Database**: PostgreSQL 15 (Docker Compose local, Supabase production)
- **Queue**: Oban 2.17
- **Auth**: Assent (Google OAuth)
- **LLM**: OpenAI GPT-4o-mini
- **Deployment**: Fly.io (backend) + Vercel (frontend)

## Prerequisites

1. **Install Elixir/Erlang**:
   ```bash
   brew install elixir
   ```

2. **Install Phoenix archive**:
   ```bash
   mix archive.install hex phx_new
   ```

3. **Install Docker Desktop** (for local PostgreSQL):
   ```bash
   brew install --cask docker
   ```

4. **Node.js/npm** (already installed via nvm)

## Local Development Setup

### 1. Start PostgreSQL (Docker Compose)

```bash
docker-compose up -d
```

### 2. Backend (Phoenix API)

```bash
cd apps/api
mix deps.get
mix ecto.create
mix ecto.migrate
mix phx.server
```

API runs on `http://localhost:4000`

### 3. Frontend (Next.js)

```bash
cd apps/web
pnpm install
pnpm dev
```

Frontend runs on `http://localhost:3000`

### 4. Sidecar (Unsubscribe Agent)

```bash
cd sidecar
pnpm install
pnpm start
```

Sidecar runs on `http://localhost:3001`

## Environment Variables

### Backend (`apps/api/.env` or `apps/api/config/runtime.exs`)

```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/emailgator_dev
SECRET_KEY_BASE=<generate with: mix phx.gen.secret>
HOST=localhost
COOKIE_SIGN_SALT=<generate>
COOKIE_ENC_SALT=<generate>
GOOGLE_CLIENT_ID=<your-google-client-id>
GOOGLE_CLIENT_SECRET=<your-google-client-secret>
GOOGLE_OAUTH_REDIRECT_URL=http://localhost:4000/auth/google/callback
OPENAI_API_KEY=<your-openai-api-key>
SIDECAR_URL=http://localhost:3001
SIDECAR_TOKEN=supersecret
SENTRY_DSN=<optional>
```

### Frontend (`apps/web/.env.local`)

```bash
NEXT_PUBLIC_API_URL=http://localhost:4000
```

### Sidecar (`sidecar/.env`)

```bash
PORT=3001
ALLOWLIST_DOMAINS=mailchimp.com,hubspot.com,sendgrid.net,customer.io
INTERNAL_TOKEN=supersecret
```

## Gmail OAuth Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project
3. Enable Gmail API
4. Create OAuth 2.0 credentials
5. Add redirect URI: `http://localhost:4000/auth/google/callback`
6. **Add test users**: Add your email (and reviewer's email) to test users list (unverified app)

Required scopes:
- `https://www.googleapis.com/auth/gmail.readonly`
- `https://www.googleapis.com/auth/gmail.modify`

## Code Formatting

Elixir has a built-in formatter. To format all code:

```bash
cd apps/api
mix format
```

The formatter configuration is in `apps/api/.formatter.exs`.

## Testing

```bash
# Backend tests
cd apps/api
mix test

# Frontend tests (when added)
cd apps/web
pnpm test
```

## Deployment

See `infra/` directory for Terraform configuration.

Production environments:
- Backend: Fly.io
- Frontend: Vercel
- Database: Supabase (provisioned via Terraform)

## Notes

- **Gmail Polling**: Currently uses polling every 2 minutes. Push notifications via Google Cloud Pub/Sub are production-preferred but require additional setup.
- **Unsubscribe Automation**: Hybrid approach - attempts HTTP unsubscribe first, uses Playwright sidecar for complex forms.

## Project Structure

```
emailgator/
├── apps/
│   ├── api/          # Phoenix/Absinthe backend
│   ├── web/           # Next.js frontend
│   └── sidecar/       # Node.js unsubscribe agent
├── infra/             # Terraform infrastructure
└── docker-compose.yml # Local PostgreSQL
```

