const request = require('supertest');
const express = require('express');

// Create a testable app wrapper
function createTestApp() {
  const app = express();
  app.use(express.json());

  const TOKEN = process.env.INTERNAL_TOKEN || 'supersecret';
  const ALLOWLIST = new Set(
    (process.env.ALLOWLIST_DOMAINS || '')
      .split(',')
      .map(s => s.trim())
      .filter(Boolean)
  );

  // Health check
  app.get('/health', (req, res) => {
    res.json({ ok: true, service: 'sidecar' });
  });

  // Run endpoint (simplified for testing)
  app.post('/run', async (req, res) => {
    // Check authentication
    const receivedToken = req.headers['x-internal'];
    
    if (receivedToken !== TOKEN) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    const { url, email } = req.body;
    
    if (!url) {
      return res.status(400).json({ ok: false, error: 'url required' });
    }

    // Validate domain (if allowlist is set)
    if (ALLOWLIST.size > 0) {
      try {
        const host = new URL(url).hostname.replace(/^www\./, '');
        const allowed = Array.from(ALLOWLIST).some(domain => host.endsWith(domain));
        
        if (!allowed) {
          return res.status(400).json({ 
            ok: false, 
            error: 'domain_not_allowed',
            domain: host 
          });
        }
      } catch (e) {
        return res.status(400).json({ ok: false, error: 'invalid_url' });
      }
    }

    // For testing, we return a mock response instead of launching browser
    res.json({
      ok: true,
      status: 'visited',
      screenshot_b64: 'test-screenshot',
      actions: []
    });
  });

  return app;
}

describe('Sidecar API', () => {
  let app;
  
  beforeEach(() => {
    // Reset environment
    process.env.INTERNAL_TOKEN = 'test-token';
    process.env.ALLOWLIST_DOMAINS = '';
    app = createTestApp();
  });

  describe('GET /health', () => {
    it('should return health status', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body).toEqual({
        ok: true,
        service: 'sidecar'
      });
    });
  });

  describe('POST /run', () => {
    it('should require authentication', async () => {
      const response = await request(app)
        .post('/run')
        .send({ url: 'https://example.com/unsubscribe' })
        .expect(403);

      expect(response.body).toEqual({
        ok: false,
        error: 'forbidden'
      });
    });

    it('should require x-internal header with correct token', async () => {
      const response = await request(app)
        .post('/run')
        .set('x-internal', 'wrong-token')
        .send({ url: 'https://example.com/unsubscribe' })
        .expect(403);

      expect(response.body.error).toBe('forbidden');
    });

    it('should reject requests without URL', async () => {
      const response = await request(app)
        .post('/run')
        .set('x-internal', 'test-token')
        .send({})
        .expect(400);

      expect(response.body).toEqual({
        ok: false,
        error: 'url required'
      });
    });

    it('should accept valid request with correct token', async () => {
      const response = await request(app)
        .post('/run')
        .set('x-internal', 'test-token')
        .send({ url: 'https://example.com/unsubscribe' })
        .expect(200);

      expect(response.body.ok).toBe(true);
      expect(response.body.status).toBe('visited');
      expect(response.body.actions).toEqual([]);
    });

    it('should accept email in request body', async () => {
      const response = await request(app)
        .post('/run')
        .set('x-internal', 'test-token')
        .send({ 
          url: 'https://example.com/unsubscribe',
          email: 'test@example.com'
        })
        .expect(200);

      expect(response.body.ok).toBe(true);
    });

    it('should validate domain when allowlist is set', async () => {
      process.env.ALLOWLIST_DOMAINS = 'example.com,test.com';
      app = createTestApp();

      // Allowed domain
      const response1 = await request(app)
        .post('/run')
        .set('x-internal', 'test-token')
        .send({ url: 'https://example.com/unsubscribe' })
        .expect(200);

      expect(response1.body.ok).toBe(true);

      // Allowed domain with www prefix
      const response2 = await request(app)
        .post('/run')
        .set('x-internal', 'test-token')
        .send({ url: 'https://www.example.com/unsubscribe' })
        .expect(200);

      expect(response2.body.ok).toBe(true);

      // Disallowed domain
      const response3 = await request(app)
        .post('/run')
        .set('x-internal', 'test-token')
        .send({ url: 'https://blocked.com/unsubscribe' })
        .expect(400);

      expect(response3.body.error).toBe('domain_not_allowed');
      expect(response3.body.domain).toBe('blocked.com');
    });

    it('should allow all domains when allowlist is empty', async () => {
      process.env.ALLOWLIST_DOMAINS = '';
      app = createTestApp();

      const response = await request(app)
        .post('/run')
        .set('x-internal', 'test-token')
        .send({ url: 'https://any-domain.com/unsubscribe' })
        .expect(200);

      expect(response.body.ok).toBe(true);
    });

    it('should reject invalid URLs', async () => {
      process.env.ALLOWLIST_DOMAINS = 'example.com';
      app = createTestApp();

      const response = await request(app)
        .post('/run')
        .set('x-internal', 'test-token')
        .send({ url: 'not-a-valid-url' })
        .expect(400);

      expect(response.body.error).toBe('invalid_url');
    });
  });
});

