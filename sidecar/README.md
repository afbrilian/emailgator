# EmailGator Sidecar Service

The sidecar is a Node.js service that handles complex unsubscribe flows using Playwright. It runs as a separate service that the Phoenix API calls when HTTP-based unsubscribe fails or requires browser automation.

## Local Development Setup

### 1. Install Dependencies (and Browsers Automatically)

```bash
cd sidecar
npm install
```

The `postinstall` script will automatically install Chromium browsers - no separate step needed!

### 2. Start the Sidecar Service

```bash
npm start
```

The service will run on `http://localhost:3001` by default.

### Environment Variables

- `PORT` - Port to run on (default: 3001)
- `INTERNAL_TOKEN` - Token for authentication (default: "supersecret")
- `ALLOWLIST_DOMAINS` - Comma-separated list of allowed domains (optional, empty means all domains allowed)

The `.env` file is already configured with the default token. To override:

Example:
```bash
PORT=3001 INTERNAL_TOKEN=your-custom-token npm start
```

## Testing Unsubscribe

### 1. Start the Sidecar

In a separate terminal:
```bash
cd sidecar
npm install
npx playwright install chromium
npm start
```

### 2. Verify Sidecar is Running

```bash
curl http://localhost:3001/health
```

Should return:
```json
{"ok":true,"service":"sidecar"}
```

### 3. Test Unsubscribe from Frontend

1. Navigate to an email that has unsubscribe URLs (in the category detail page or email detail page)
2. Click "Unsubscribe Selected" or the individual unsubscribe button
3. The Phoenix API will:
   - First try HTTP GET on the unsubscribe URL
   - If that fails or needs browser automation, it will call the sidecar service
   - The sidecar will use Playwright to navigate to the URL and attempt to find/click unsubscribe elements

### 4. Check Unsubscribe Attempts

You can check the database for `unsubscribe_attempts` table to see:
- Which method was used (HTTP or Playwright)
- Whether it succeeded or failed
- Screenshots from Playwright attempts

## How It Works

1. **HTTP First**: The Phoenix API tries a simple HTTP GET request on the unsubscribe URL
2. **Playwright Fallback**: If HTTP fails (returns 405/400, needs forms, etc.), it calls the sidecar
3. **Sidecar Process**:
   - Launches a headless Chromium browser
   - Navigates to the unsubscribe URL
   - Tries multiple selectors to find unsubscribe elements
   - Clicks if found
   - Takes a screenshot as evidence
   - Returns status to the API

## Production Deployment

The sidecar should be deployed as a separate service. Here's where the commands run:

### Environment Breakdown

**Local Development:**
- Run `npm install` in the `sidecar/` directory
- Browsers install automatically via `postinstall` script
- Start with `npm start`

**CI/CD Pipeline:**
- Run `npm ci` (or `npm install`) in the build step
- Browsers install automatically via `postinstall` script
- Build Docker image or deploy to platform

**Production Deployment:**
- If using Docker: Browsers are baked into the image during build
- If using platform-as-a-service: Browsers install during build/deploy step
- No manual steps needed - it's automated!

### Deployment Options

#### Option 1: Docker (Recommended)

Build and run:
```bash
cd sidecar
docker build -t emailgator-sidecar .
docker run -p 3001:3001 \
  -e PORT=3001 \
  -e INTERNAL_TOKEN=your-secret-token \
  -e ALLOWLIST_DOMAINS= \
  emailgator-sidecar
```

#### Option 2: Fly.io

```bash
cd sidecar
fly launch
fly secrets set INTERNAL_TOKEN=your-secret-token
fly deploy
```

The `fly.toml` is already configured. Playwright browsers install automatically during deployment.

#### Option 3: Railway / Render / Heroku

1. Connect your repository
2. Set build command: `npm install` (browsers install via postinstall)
3. Set start command: `npm start`
4. Set environment variables:
   - `PORT` (auto-set by platform usually)
   - `INTERNAL_TOKEN`
   - `ALLOWLIST_DOMAINS` (optional)

### Update Phoenix API Config

After deploying, set these environment variables in your Phoenix API:

```bash
export SIDECAR_URL=https://your-sidecar-service.com  # or http://localhost:3001 for local
export SIDECAR_TOKEN=your-secret-token
```

## Troubleshooting

- **Connection refused**: Make sure the sidecar is running on the expected port
- **403 Forbidden**: Check that `INTERNAL_TOKEN` matches in both services
- **Domain not allowed**: Set `ALLOWLIST_DOMAINS` or leave it empty to allow all domains
- **Playwright errors**: Make sure Chromium is installed (`npx playwright install chromium`)

