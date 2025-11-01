# Setup Instructions

## Prerequisites

1. **Install Elixir/Erlang**:
   ```bash
   brew install elixir
   ```

2. **Install Phoenix archive**:
   ```bash
   mix archive.install hex phx_new
   ```

3. **Start PostgreSQL with Docker**:
   ```bash
   docker-compose up -d
   ```

## Backend Setup

1. **Navigate to API directory**:
   ```bash
   cd apps/api
   ```

2. **Install dependencies**:
   ```bash
   mix deps.get
   ```

3. **Create database**:
   ```bash
   mix ecto.create
   ```

4. **Run migrations**:
   ```bash
   mix ecto.migrate
   ```

5. **Generate secret keys** (for production):
   ```bash
   mix phx.gen.secret  # Use this for SECRET_KEY_BASE
   ```

6. **Set up environment variables**:
   Copy `.env.example` to `.env` and fill in your values:
   - `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` from Google Cloud Console
   - `OPENAI_API_KEY` from OpenAI

7. **Start the server**:
   ```bash
   mix phx.server
   ```

API will run on `http://localhost:4000`

## Frontend Setup

1. **Navigate to web directory**:
   ```bash
   cd apps/web
   ```

2. **Install dependencies**:
   ```bash
   npm install
   # or if you have pnpm:
   pnpm install
   ```

3. **Set up environment**:
   Create `.env.local`:
   ```
   NEXT_PUBLIC_API_URL=http://localhost:4000
   ```

4. **Start development server**:
   ```bash
   npm run dev
   # or
   pnpm dev
   ```

Frontend will run on `http://localhost:3000`

## Sidecar Setup

1. **Navigate to sidecar directory**:
   ```bash
   cd sidecar
   ```

2. **Install dependencies**:
   ```bash
   npm install
   # or
   pnpm install
   ```

3. **Install Playwright browsers**:
   ```bash
   npx playwright install chromium
   ```

4. **Start service**:
   ```bash
   npm start
   # or
   pnpm start
   ```

Sidecar will run on `http://localhost:3001`

## Google OAuth Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or use existing)
3. Enable **Gmail API**
4. Go to **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
5. Application type: **Web application**
6. Authorized redirect URIs:
   - `http://localhost:4000/auth/google/callback` (for local dev)
   - `https://your-api-domain.com/auth/google/callback` (for production)
7. **Important**: Add your email (and reviewer's email) as **Test users** in OAuth consent screen
8. Copy `Client ID` and `Client Secret` to your `.env` file

Required OAuth scopes:
- `https://www.googleapis.com/auth/gmail.readonly`
- `https://www.googleapis.com/auth/gmail.modify`

## First Run

1. Start all services:
   - Docker Compose (PostgreSQL)
   - Backend API (`mix phx.server` in `apps/api`)
   - Frontend (`npm run dev` in `apps/web`)
   - Sidecar (`npm start` in `sidecar`)

2. Visit `http://localhost:3000`
3. Click "Sign in with Google"
4. After OAuth, you'll be redirected back
5. Create your first category
6. Connect a Gmail account (you'll need to handle OAuth for Gmail separately or extend the existing flow)

## Troubleshooting

### Elixir not found
- Make sure Elixir is installed: `brew install elixir`
- Check PATH: `which elixir`

### Database connection error
- Make sure Docker Compose is running: `docker-compose ps`
- Check PostgreSQL is accessible: `psql -h localhost -U postgres -d emailgator_dev`

### OAuth errors
- Verify redirect URI matches exactly in Google Console
- Make sure you're added as a test user
- Check that Gmail API is enabled

### Oban jobs not running
- Make sure Oban is started with the application
- Check logs for errors: `mix phx.server` will show Oban logs
- Verify database migrations ran: `mix ecto.migrations`

