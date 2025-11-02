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

      let status = 'visited';
      let actions = [];

      // Step 1: Check if there's a form that needs filling
      const forms = await page.$$('form');
      if (forms.length > 0) {
        actions.push('form_detected');
        
        // Try to find and interact with unsubscribe-related form elements
        try {
          // Look for checkboxes related to unsubscribe
          const checkboxes = await page.$$('input[type="checkbox"]');
          for (const checkbox of checkboxes) {
            const label = await checkbox.evaluate(el => {
              const lbl = el.closest('label')?.textContent || 
                         el.getAttribute('aria-label') || 
                         el.getAttribute('title') || '';
              return lbl.toLowerCase();
            });
            
            // Check if it's unsubscribe-related
            if (label.includes('unsubscribe') || 
                label.includes('opt-out') || 
                label.includes('opt out') ||
                label.includes('email preferences')) {
              const isChecked = await checkbox.isChecked();
              if (!isChecked) {
                await checkbox.check();
                actions.push('checkbox_checked');
                status = 'form_interacted';
              }
            }
          }

          // Look for radio buttons
          const radios = await page.$$('input[type="radio"]');
          for (const radio of radios) {
            const name = await radio.getAttribute('name');
            const value = await radio.getAttribute('value');
            const label = await radio.evaluate(el => {
              const lbl = el.closest('label')?.textContent || '';
              return lbl.toLowerCase();
            });
            
            // Check if it's unsubscribe-related
            if (label.includes('unsubscribe') || 
                label.includes('opt-out') || 
                value?.toLowerCase().includes('unsubscribe')) {
              await radio.check();
              actions.push('radio_selected');
              status = 'form_interacted';
              break; // Only select one radio in a group
            }
          }

          // Fill text inputs that might be needed (like email confirmation)
          const textInputs = await page.$$('input[type="text"], input[type="email"]');
          for (const input of textInputs) {
            const placeholder = await input.getAttribute('placeholder') || '';
            const name = await input.getAttribute('name') || '';
            const id = await input.getAttribute('id') || '';
            
            const lowerPlaceholder = placeholder.toLowerCase();
            const lowerName = name.toLowerCase();
            const lowerId = id.toLowerCase();
            
            // Skip if already has value
            const currentValue = await input.inputValue();
            if (currentValue) continue;
            
            // Try to extract email from URL or use a placeholder
            if (lowerPlaceholder.includes('email') || 
                lowerName.includes('email') || 
                lowerId.includes('email')) {
              // Try to extract email from URL query params
              const emailMatch = url.match(/[?&]email=([^&]+)/);
              const email = emailMatch ? decodeURIComponent(emailMatch[1]) : '';
              
              if (email) {
                await input.fill(email);
                actions.push('email_filled');
                status = 'form_interacted';
              }
            }
          }

          // Fill textareas if needed
          const textareas = await page.$$('textarea');
          for (const textarea of textareas) {
            const placeholder = await textarea.getAttribute('placeholder') || '';
            const name = await textarea.getAttribute('name') || '';
            
            const lowerPlaceholder = placeholder.toLowerCase();
            const lowerName = name.toLowerCase();
            
            // Check if it's a reason field or similar
            if ((lowerPlaceholder.includes('reason') || 
                 lowerName.includes('reason') ||
                 lowerPlaceholder.includes('why') ||
                 lowerName.includes('why')) && 
                !(await textarea.inputValue())) {
              await textarea.fill('No longer needed');
              actions.push('textarea_filled');
              status = 'form_interacted';
            }
          }

          // Handle select dropdowns
          const selects = await page.$$('select');
          for (const select of selects) {
            const name = await select.getAttribute('name') || '';
            const lowerName = name.toLowerCase();
            
            if (lowerName.includes('reason') || 
                lowerName.includes('preference') ||
                lowerName.includes('option')) {
              // Try to find an unsubscribe-related option
              const options = await select.$$('option');
              for (const option of options) {
                const text = await option.textContent();
                const value = await option.getAttribute('value');
                
                if (text?.toLowerCase().includes('unsubscribe') || 
                    value?.toLowerCase().includes('unsubscribe') ||
                    text?.toLowerCase().includes('opt-out')) {
                  await select.selectOption({ value: value || text });
                  actions.push('select_changed');
                  status = 'form_interacted';
                  break;
                }
              }
            }
          }

          // Wait a bit after form interactions
          if (actions.length > 1) {
            await page.waitForTimeout(1000);
          }
        } catch (formError) {
          console.error('Error interacting with form:', formError);
          actions.push(`form_error: ${formError.message}`);
        }
      }

      // Step 2: Try to find and click unsubscribe buttons/links
      const unsubscribeSelectors = [
        'button:has-text("unsubscribe")',
        'button:has-text("Unsubscribe")',
        'button:has-text("opt out")',
        'button:has-text("Opt Out")',
        'a:has-text("unsubscribe")',
        'a:has-text("Unsubscribe")',
        '[href*="unsubscribe"]',
        'text=/^unsubscribe$/i',
        'text=/^opt.?out$/i',
        'input[type="submit"][value*="unsubscribe" i]',
        'input[type="button"][value*="unsubscribe" i]'
      ];

      let clicked = false;
      for (const selector of unsubscribeSelectors) {
        try {
          // Wait a bit for element to be available
          await page.waitForSelector(selector, { timeout: 3000 }).catch(() => null);
          const element = await page.$(selector);
          
          if (element) {
            const isVisible = await element.isVisible();
            if (isVisible) {
              await element.click({ timeout: 5000 });
              clicked = true;
              actions.push('button_clicked');
              status = 'submitted';
              
              // Wait for navigation or form submission
              await page.waitForTimeout(3000);
              
              // Check if we navigated or if form was submitted
              try {
                await page.waitForNavigation({ timeout: 3000 });
                status = 'navigated';
                actions.push('navigation_detected');
              } catch (navError) {
                // No navigation, might be AJAX form submit
                status = 'form_submitted';
              }
              
              break;
            }
          }
        } catch (e) {
          // Continue to next selector
          continue;
        }
      }

      // If no button was clicked but form was interacted with, try to submit the form
      if (!clicked && forms.length > 0 && status === 'form_interacted') {
        try {
          // Look for submit button
          const submitButtons = await page.$$('button[type="submit"], input[type="submit"], button:not([type])');
          for (const submitBtn of submitButtons) {
            const text = await submitBtn.textContent();
            const value = await submitBtn.getAttribute('value');
            
            // Prefer unsubscribe-related submit buttons
            if (text?.toLowerCase().includes('unsubscribe') || 
                text?.toLowerCase().includes('confirm') ||
                text?.toLowerCase().includes('submit') ||
                value?.toLowerCase().includes('unsubscribe')) {
              await submitBtn.click();
              actions.push('form_submitted');
              status = 'submitted';
              await page.waitForTimeout(3000);
              
              // Check for navigation
              try {
                await page.waitForNavigation({ timeout: 3000 });
                status = 'navigated';
                actions.push('navigation_detected');
              } catch (navError) {
                // No navigation
              }
              break;
            }
          }
          
          // If no submit button found, try submitting the first form directly
          if (status === 'form_interacted') {
            await forms[0].evaluate(form => form.submit());
            actions.push('form_auto_submitted');
            status = 'submitted';
            await page.waitForTimeout(3000);
          }
        } catch (submitError) {
          console.error('Error submitting form:', submitError);
          actions.push(`submit_error: ${submitError.message}`);
        }
      }

      // Take screenshot as evidence
      const screenshot = await page.screenshot({ type: 'png' });

      await browser.close();

      return res.json({
        ok: true,
        status: status,
        actions: actions,
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

