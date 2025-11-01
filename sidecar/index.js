const express = require('express');
const { chromium } = require('playwright');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3001;
const ALLOWLIST = new Set(
  (process.env.ALLOWLIST_DOMAINS || '')
    .split(',')
    .map(s => s.trim())
    .filter(Boolean)
);
const TOKEN = process.env.INTERNAL_TOKEN || 'supersecret';

app.post('/run', async (req, res) => {
  try {
    // Check authentication
    if (req.headers['x-internal'] !== TOKEN) {
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    const { url } = req.body;
    if (!url) {
      return res.status(400).json({ ok: false, error: 'url required' });
    }

    // Validate domain (if allowlist is set)
    if (ALLOWLIST.size > 0) {
      const host = new URL(url).hostname.replace(/^www\./, '');
      const allowed = Array.from(ALLOWLIST).some(domain => host.endsWith(domain));
      
      if (!allowed) {
        return res.status(400).json({ 
          ok: false, 
          error: 'domain_not_allowed',
          domain: host 
        });
      }
    }

    // Launch browser and attempt unsubscribe
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext();
    const page = await context.newPage();

    try {
      await page.goto(url, { 
        timeout: 60000, 
        waitUntil: 'domcontentloaded' 
      });

      // Wait for page to load
      await page.waitForTimeout(2000);

      // Try to find and click unsubscribe elements
      const unsubscribeSelectors = [
        'text=/unsubscribe/i',
        'text=/opt.?out/i',
        'text=/manage preferences/i',
        '[href*="unsubscribe"]',
        'button:has-text("unsubscribe")',
        'a:has-text("unsubscribe")'
      ];

      let clicked = false;
      for (const selector of unsubscribeSelectors) {
        try {
          const element = await page.$(selector);
          if (element) {
            await element.click();
            clicked = true;
            await page.waitForTimeout(2000);
            break;
          }
        } catch (e) {
          // Continue to next selector
        }
      }

      // Take screenshot as evidence
      const screenshot = await page.screenshot({ type: 'png' });

      await browser.close();

      return res.json({
        ok: true,
        status: clicked ? 'clicked' : 'visited',
        screenshot_b64: screenshot.toString('base64')
      });
    } catch (error) {
      await browser.close();
      throw error;
    }
  } catch (e) {
    return res.status(500).json({ 
      ok: false, 
      error: String(e.message || e) 
    });
  }
});

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'sidecar' });
});

app.listen(PORT, () => {
  console.log(`Sidecar service running on port ${PORT}`);
});

