# Google OAuth Setup Guide

## Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click **"Create Project"** (or select existing project)
3. Name it (e.g., "EmailGator")
4. Click **"Create"**

## Step 2: Enable Google+ API

1. In the project, go to **"APIs & Services" > "Library"**
2. Search for **"Google+ API"** and click **Enable**
3. (Optional but recommended) Search for **"Gmail API"** and click **Enable**

## Step 3: Create OAuth 2.0 Credentials

1. Go to **"APIs & Services" > "Credentials"**
2. Click **"+ CREATE CREDENTIALS" > "OAuth client ID"**
3. If prompted, configure the OAuth consent screen first:
   - Choose **"External"** (for testing/demo)
   - Fill in required fields:
     - App name: `EmailGator`
     - User support email: Your email
     - Developer contact: Your email
   - Click **"Save and Continue"**
   - Scopes: Add `email`, `profile`, `https://www.googleapis.com/auth/gmail.readonly`, `https://www.googleapis.com/auth/gmail.modify`
   - Test users: **ADD YOUR EMAIL ADDRESS** (and any reviewer emails)
   - Click **"Save and Continue"** through the rest
4. Back to credentials:
   - Application type: **"Web application"**
   - Name: `EmailGator Local Dev` (or any name)
   - **Authorized redirect URIs**: 
     - Add: `http://localhost:4000/auth/google/callback`
     - Add: `http://localhost:4000/gmail/callback` (for Gmail account connection)
   - Click **"Create"**
5. **Copy the Client ID and Client Secret** (you'll need these)

## Step 4: Set Environment Variables

### Option A: Create `.env` file in `apps/api/` (recommended for local dev)

```bash
cd apps/api
cat > .env << 'EOF'
GOOGLE_CLIENT_ID=your-client-id-here.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret-here
GOOGLE_OAUTH_REDIRECT_URL=http://localhost:4000/auth/google/callback
EOF
```

### Option B: Export in your shell (temporary)

```bash
export GOOGLE_CLIENT_ID="your-client-id-here.apps.googleusercontent.com"
export GOOGLE_CLIENT_SECRET="your-client-secret-here"
export GOOGLE_OAUTH_REDIRECT_URL="http://localhost:4000/auth/google/callback"
```

## Step 5: Load Environment Variables

If you used `.env` file, you need to load it. Phoenix doesn't auto-load `.env` files, so:

**Option 1: Use `dotenv` package** (recommended)

```bash
cd apps/api
# Add to mix.exs deps:
# {:dotenv, "~> 3.0"}
mix deps.get
```

Then in `config/dev.exs`, add at the top:
```elixir
Code.ensure_loaded?(Dotenv) && Dotenv.load()
```

**Option 2: Export manually before starting server**

```bash
export $(cat apps/api/.env | xargs)
cd apps/api
mix phx.server
```

**Option 3: Use direnv** (if installed)

Create `.envrc` in `apps/api/`:
```
dotenv
```

## Step 6: Restart Phoenix Server

```bash
cd apps/api
# Stop current server (Ctrl+C)
mix phx.server
```

## Important Notes

⚠️ **Test Users**: Since this is an unverified app, you MUST add yourself (and reviewers) as test users in the OAuth consent screen. Otherwise, only you can sign in.

⚠️ **Redirect URIs**: Make sure the redirect URIs match exactly:
- `http://localhost:4000/auth/google/callback` (user sign-in)
- `http://localhost:4000/gmail/callback` (Gmail account connection)

⚠️ **Security**: Never commit `.env` files or credentials to git. They should already be in `.gitignore`.

## Verification

After setting up, try the OAuth flow again. You should see:
1. Google OAuth consent screen (not an error page)
2. Your email in the test users list
3. Permission to access your Google account
4. Successful redirect back to your app

## Production Setup

For production, you'll need:
- A verified OAuth app (takes days/weeks)
- Production redirect URIs (e.g., `https://yourdomain.com/auth/google/callback`)
- Add production URLs to authorized redirect URIs in Google Cloud Console

