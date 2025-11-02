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

#### Generate GraphQL Types

After the backend API is running, generate TypeScript types from the GraphQL schema:

```bash
cd apps/web
npm run codegen
```

**Important**: 
- The Phoenix API must be running (`mix phx.server`) for codegen to work, as it introspects the GraphQL schema from the running server.
- Codegen uses `NEXT_PUBLIC_API_URL` environment variable (defaults to `http://localhost:4000`)
- For different environments, set the variable before running:
  ```bash
  # Local (default)
  npm run codegen
  
  # Dev environment
  NEXT_PUBLIC_API_URL=https://api-dev.example.com npm run codegen
  
  # Production
  NEXT_PUBLIC_API_URL=https://api.example.com npm run codegen
  ```

This generates TypeScript types and React hooks in `src/gql/` from your GraphQL queries.

**Note**: The `src/gql/` directory is **generated code** and is **ignored by git** (see `.gitignore`). It is automatically generated during the build process via the `prebuild` hook in `package.json`. 

- **Local development**: Run `npm run codegen` manually after starting the API server
- **Production builds**: Codegen runs automatically via `prebuild` hook before `npm run build`
- **CI/CD**: No extra steps needed - codegen runs as part of the build process

**Automatic Fix**: A post-generation script automatically removes duplicate DocumentNode exports that codegen sometimes generates. The `postcodegen` npm hook runs this automatically after each codegen run, so you don't need to worry about duplicates.

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
# Backend API URL (used for all API calls, OAuth redirects, and GraphQL)
NEXT_PUBLIC_API_URL=http://localhost:4000
```

**Note**: 
- The frontend uses `src/lib/config.ts` to centralize all API endpoints
- All hardcoded URLs have been replaced with environment variables
- GraphQL codegen also uses `NEXT_PUBLIC_API_URL` for multi-environment support
- See [`ENV_VARIABLES.md`](./ENV_VARIABLES.md) for complete environment variable documentation

### Sidecar (`sidecar/.env`)

```bash
PORT=3001
ALLOWLIST_DOMAINS=mailchimp.com,hubspot.com,sendgrid.net,customer.io
INTERNAL_TOKEN=supersecret
```

## Gmail OAuth Setup

⚠️ **Required**: You must set up Google OAuth credentials before the app will work. See detailed instructions in [`GOOGLE_OAUTH_SETUP.md`](./GOOGLE_OAUTH_SETUP.md).

### Quick Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable **Google+ API** (required for OAuth)
4. Enable **Gmail API** (for email access)
5. Create OAuth 2.0 credentials (Web application)
6. Add redirect URIs:
   - `http://localhost:4000/auth/google/callback` (user sign-in)
   - `http://localhost:4000/gmail/callback` (Gmail account connection)
7. **Configure OAuth consent screen** (External, add yourself as test user)
8. **Copy Client ID and Client Secret**
9. Create `apps/api/.env` file:
   ```bash
   GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET=your-client-secret
   GOOGLE_OAUTH_REDIRECT_URL=http://localhost:4000/auth/google/callback
   ```
10. Restart Phoenix server

Required scopes:
- `email` and `profile` (user sign-in)
- `https://www.googleapis.com/auth/gmail.readonly`
- `https://www.googleapis.com/auth/gmail.modify`

**See [`GOOGLE_OAUTH_SETUP.md`](./GOOGLE_OAUTH_SETUP.md) for step-by-step instructions with screenshots.**

## Code Formatting

### Backend (Elixir/Phoenix)

Elixir has a built-in formatter. To format all code:

```bash
cd apps/api
mix format
```

The formatter configuration is in `apps/api/.formatter.exs`.

### Frontend (Next.js/TypeScript)

The frontend uses ESLint and Prettier for linting and formatting:

```bash
cd apps/web

# Check for linting errors
npm run lint

# Auto-fix linting errors
npm run lint:fix

# Format all code with Prettier
npm run format

# Check formatting without making changes
npm run format:check
```

**Auto-formatting in VS Code**: The project includes `.vscode/settings.json` to automatically format on save using Prettier and fix ESLint errors.

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

