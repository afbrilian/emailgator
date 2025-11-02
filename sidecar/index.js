// Load environment variables from .env file
require('dotenv').config();

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

// Log token info on startup (for debugging)
console.log(`Sidecar: Token loaded - length: ${TOKEN.length}, first 4 chars: ${TOKEN.substring(0, 4)}...`);

app.post('/run', async (req, res) => {
  const requestStartTime = Date.now();
  console.log(`[${new Date().toISOString()}] Sidecar: Received POST /run request`);
  console.log(`[${new Date().toISOString()}] Sidecar: Request headers:`, Object.keys(req.headers));
  
  try {
    // Check authentication
    const receivedToken = req.headers['x-internal'];
    console.log(`[${new Date().toISOString()}] Sidecar: Checking authentication...`);
    
    if (receivedToken !== TOKEN) {
      console.error(`[${new Date().toISOString()}] Sidecar: Token mismatch! Expected length: ${TOKEN.length}, Received length: ${receivedToken?.length || 0}`);
      console.error(`[${new Date().toISOString()}] Sidecar: Expected first 4: ${TOKEN.substring(0, 4)}, Received first 4: ${receivedToken?.substring(0, 4) || 'undefined'}`);
      return res.status(403).json({ ok: false, error: 'forbidden' });
    }

    console.log(`[${new Date().toISOString()}] Sidecar: Authentication passed`);
    const { url, email } = req.body;
    console.log(`[${new Date().toISOString()}] Sidecar: Request body:`, { 
      url: url ? url.substring(0, 100) + '...' : 'missing',
      email: email ? email : 'not provided'
    });
    
    if (!url) {
      console.error(`[${new Date().toISOString()}] Sidecar: Missing URL in request body`);
      return res.status(400).json({ ok: false, error: 'url required' });
    }
    
    console.log(`[${new Date().toISOString()}] Sidecar: Processing unsubscribe for URL: ${url}`);

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
    console.log(`[${new Date().toISOString()}] Sidecar: Launching browser...`);
    const browser = await chromium.launch({ headless: true });
    console.log(`[${new Date().toISOString()}] Sidecar: Browser launched`);
    const context = await browser.newContext();
    console.log(`[${new Date().toISOString()}] Sidecar: Browser context created`);
    const page = await context.newPage();
    console.log(`[${new Date().toISOString()}] Sidecar: New page created`);

    try {
      console.log(`[${new Date().toISOString()}] Sidecar: Navigating to URL (timeout: 60s)...`);
      await page.goto(url, { 
        timeout: 60000, 
        waitUntil: 'domcontentloaded' 
      });
      console.log(`[${new Date().toISOString()}] Sidecar: Page navigation completed`);

      // Wait for page to load
      console.log(`[${new Date().toISOString()}] Sidecar: Waiting 2s for page to fully load...`);
      await page.waitForTimeout(2000);
      console.log(`[${new Date().toISOString()}] Sidecar: Page load wait completed`);

      let status = 'visited';
      let actions = [];

      // Step 1: Check if this is a BambooHR unsubscribe page
      let isBambooHRHandled = false;
      try {
        console.log(`[${new Date().toISOString()}] Sidecar: Checking if this is a BambooHR unsubscribe page...`);
        const pageUrl = page.url();
        const pageTitle = await page.title();
        const isBambooHRPage = 
          pageUrl.includes('bamboohr.com/unsubscribe') ||
          pageTitle.toLowerCase().includes('bamboohr unsubscribe');
        
        if (isBambooHRPage) {
          console.log(`[${new Date().toISOString()}] Sidecar: Detected BambooHR unsubscribe page, using BambooHR-specific logic...`);
          
          // Wait for Marketo form to load (forms are loaded dynamically)
          console.log(`[${new Date().toISOString()}] Sidecar: Waiting for Marketo form to load...`);
          try {
            // Wait for form or email input to appear
            await page.waitForSelector('input[name="Email"], input[type="email"], form.mktoForm', { timeout: 10000 });
            console.log(`[${new Date().toISOString()}] Sidecar: Form detected, proceeding...`);
            await page.waitForTimeout(1000); // Extra wait for form to fully initialize
          } catch (waitError) {
            console.log(`[${new Date().toISOString()}] Sidecar: Form not detected within timeout, continuing anyway...`);
          }
          
          // Fill email field (from request body, URL, or placeholder)
          let emailValue = email || null;
          if (!emailValue) {
            // Try to extract from URL
            const emailMatch = url.match(/[?&]email=([^&]+)/);
            emailValue = emailMatch ? decodeURIComponent(emailMatch[1]) : 'user@example.com';
          }
          console.log(`[${new Date().toISOString()}] Sidecar: Using email value: ${emailValue}`);
          
          // Try multiple approaches to find and fill email field
          const emailSelectors = [
            'input[name="Email"]',
            'input[type="email"]',
            'input[id*="Email"]',
            'input.mktoField[type="email"]'
          ];
          
          let emailFilled = false;
          for (const selector of emailSelectors) {
            try {
              console.log(`[${new Date().toISOString()}] Sidecar: Trying email selector: ${selector}`);
              const emailInput = await page.$(selector);
              if (emailInput) {
                const isVisible = await emailInput.isVisible();
                console.log(`[${new Date().toISOString()}] Sidecar: Email input found, visible: ${isVisible}`);
                if (isVisible) {
                  // Clear any existing value first
                  await emailInput.clear({ timeout: 2000 }).catch(() => {});
                  await emailInput.fill(emailValue, { timeout: 5000 });
                  // Verify it was filled
                  const filledValue = await emailInput.inputValue();
                  console.log(`[${new Date().toISOString()}] Sidecar: Email field filled, current value: ${filledValue}`);
                  if (filledValue === emailValue || filledValue.includes(emailValue.split('@')[0])) {
                    actions.push(`bamboohr_email_filled: ${emailValue}`);
                    status = 'form_interacted';
                    emailFilled = true;
                    console.log(`[${new Date().toISOString()}] Sidecar: Successfully filled email field`);
                    await page.waitForTimeout(500);
                    break;
                  }
                }
              } else {
                console.log(`[${new Date().toISOString()}] Sidecar: Email input not found with selector: ${selector}`);
              }
            } catch (e) {
              console.log(`[${new Date().toISOString()}] Sidecar: Error with email selector ${selector}:`, e.message);
            }
          }
          
          // Check the unsubscribe checkbox
          const checkboxSelectors = [
            'input[name="Unsubscribed"][type="checkbox"]',
            'input[id*="Unsubscribed"][type="checkbox"]',
            'input[type="checkbox"][id*="mktoCheckbox"]',
            'input.mktoCheckboxList[type="checkbox"]'
          ];
          
          let checkboxChecked = false;
          for (const selector of checkboxSelectors) {
            try {
              console.log(`[${new Date().toISOString()}] Sidecar: Trying checkbox selector: ${selector}`);
              const checkbox = await page.$(selector);
              if (checkbox) {
                const isVisible = await checkbox.isVisible();
                console.log(`[${new Date().toISOString()}] Sidecar: Checkbox found, visible: ${isVisible}`);
                if (isVisible) {
                  const isChecked = await checkbox.isChecked();
                  console.log(`[${new Date().toISOString()}] Sidecar: Checkbox checked state: ${isChecked}`);
                  if (!isChecked) {
                    // Try multiple methods to check
                    try {
                      await checkbox.check({ timeout: 5000 });
                    } catch (checkError) {
                      // Fallback: click the checkbox or its label
                      try {
                        await checkbox.click({ timeout: 5000 });
                      } catch (clickError) {
                        // Try clicking label
                        const checkboxId = await checkbox.getAttribute('id');
                        if (checkboxId) {
                          const label = await page.$(`label[for="${checkboxId}"]`);
                          if (label) await label.click({ timeout: 5000 });
                        }
                      }
                    }
                    // Verify it's checked
                    const nowChecked = await checkbox.isChecked();
                    if (nowChecked) {
                      actions.push('bamboohr_checkbox_checked');
                      status = 'form_interacted';
                      checkboxChecked = true;
                      console.log(`[${new Date().toISOString()}] Sidecar: Successfully checked unsubscribe checkbox`);
                      await page.waitForTimeout(500);
                      break;
                    }
                  } else {
                    checkboxChecked = true; // Already checked
                    actions.push('bamboohr_checkbox_already_checked');
                    console.log(`[${new Date().toISOString()}] Sidecar: Checkbox already checked`);
                    break;
                  }
                }
              } else {
                console.log(`[${new Date().toISOString()}] Sidecar: Checkbox not found with selector: ${selector}`);
              }
            } catch (e) {
              console.log(`[${new Date().toISOString()}] Sidecar: Error with checkbox selector ${selector}:`, e.message);
            }
          }
          
          // Select a radio button for unsubscribe reason
          // Try "Other" first, then try any available option
          const radioSelectors = [
            'input[name="UnsubscribedReason"][value="[OTHER]"]',
            'input[name="UnsubscribedReason"][value*="OTHER"]',
            'input[name="UnsubscribedReason"][type="radio"]'
          ];
          
          let radioSelected = false;
          for (const selector of radioSelectors) {
            try {
              console.log(`[${new Date().toISOString()}] Sidecar: Trying radio selector: ${selector}`);
              const radios = await page.$$(selector);
              console.log(`[${new Date().toISOString()}] Sidecar: Found ${radios.length} radio button(s)`);
              if (radios.length > 0) {
                // Try to select the first visible radio (prefer "Other" if available)
                for (const radio of radios) {
                  const isVisible = await radio.isVisible();
                  if (isVisible) {
                    const value = await radio.getAttribute('value');
                    console.log(`[${new Date().toISOString()}] Sidecar: Found visible radio with value: ${value}`);
                    // Prefer "Other" but accept any if it's the first one
                    if (selector.includes('OTHER') || radios.length === 1 || !radioSelected) {
                      await radio.check({ timeout: 5000 });
                      const nowChecked = await radio.isChecked();
                      if (nowChecked) {
                        actions.push(`bamboohr_radio_selected: ${value || 'unknown'}`);
                        status = 'form_interacted';
                        radioSelected = true;
                        console.log(`[${new Date().toISOString()}] Sidecar: Successfully selected radio button with value: ${value || 'unknown'}`);
                        await page.waitForTimeout(500);
                        if (selector.includes('OTHER')) break; // If we found "Other", stop
                      }
                    }
                  }
                }
                if (radioSelected) break;
              }
            } catch (e) {
              console.log(`[${new Date().toISOString()}] Sidecar: Error with radio selector ${selector}:`, e.message);
            }
          }
          
          // Click submit button - try multiple approaches
          console.log(`[${new Date().toISOString()}] Sidecar: Looking for submit button...`);
          
          // First, try to find button by class and text
          let submitClicked = false;
          try {
            const mktoButtons = await page.$$('button.mktoButton, button[type="submit"]');
            console.log(`[${new Date().toISOString()}] Sidecar: Found ${mktoButtons.length} potential submit button(s)`);
            for (const btn of mktoButtons) {
              const isVisible = await btn.isVisible();
              const buttonText = await btn.textContent();
              console.log(`[${new Date().toISOString()}] Sidecar: Button text: "${buttonText}", visible: ${isVisible}`);
              if (isVisible && buttonText && (buttonText.includes('Confirm') || buttonText.includes('Preferences'))) {
                await btn.click({ timeout: 5000 });
                actions.push('bamboohr_submit_clicked');
                status = 'submitted';
                submitClicked = true;
                console.log(`[${new Date().toISOString()}] Sidecar: Clicked submit button: ${buttonText}`);
                await page.waitForTimeout(3000); // Wait for form submission
                break;
              }
            }
          } catch (e) {
            console.log(`[${new Date().toISOString()}] Sidecar: Error clicking submit buttons:`, e.message);
          }
          
          // Try text-based search for submit button as fallback
          if (!submitClicked) {
            try {
              console.log(`[${new Date().toISOString()}] Sidecar: Trying text-based button search...`);
              const allButtons = await page.$$('button');
              for (const button of allButtons) {
                const buttonText = (await button.textContent() || '').trim();
                const isVisible = await button.isVisible();
                console.log(`[${new Date().toISOString()}] Sidecar: Checking button: "${buttonText}", visible: ${isVisible}`);
                if (isVisible && buttonText && (buttonText.toLowerCase().includes('confirm') || buttonText.toLowerCase().includes('preferences'))) {
                  await button.click({ timeout: 5000 });
                  actions.push('bamboohr_submit_clicked_text');
                  status = 'submitted';
                  submitClicked = true;
                  console.log(`[${new Date().toISOString()}] Sidecar: Clicked submit button (text match): ${buttonText}`);
                  await page.waitForTimeout(3000);
                  break;
                }
              }
            } catch (textSearchError) {
              console.error(`[${new Date().toISOString()}] Sidecar: Error in text-based button search:`, textSearchError);
            }
          }
          
          // If we interacted with BambooHR elements, mark as handled
          if (emailFilled || checkboxChecked || radioSelected || submitClicked) {
            console.log(`[${new Date().toISOString()}] Sidecar: Completed BambooHR-specific unsubscribe actions (email: ${emailFilled}, checkbox: ${checkboxChecked}, radio: ${radioSelected}, submit: ${submitClicked})`);
            isBambooHRHandled = true;
          } else {
            console.log(`[${new Date().toISOString()}] Sidecar: Failed to interact with BambooHR form elements`);
          }
        }
      } catch (bamboohrError) {
        console.error(`[${new Date().toISOString()}] Sidecar: Error in BambooHR-specific handling:`, bamboohrError);
        console.error(`[${new Date().toISOString()}] Sidecar: Error stack:`, bamboohrError.stack);
      }

      // Step 2: Check if this is an Alibaba email preferences page
      let isAlibabaHandled = false;
      try {
        console.log(`[${new Date().toISOString()}] Sidecar: Checking if this is an Alibaba email preferences page...`);
        const pageUrl = page.url();
        const pageTitle = await page.title();
        const isAlibabaPage = 
          pageUrl.includes('alibaba.com') || 
          pageUrl.includes('alicdn.com') ||
          pageTitle.toLowerCase().includes('email preferences');
        
        if (isAlibabaPage) {
          console.log(`[${new Date().toISOString()}] Sidecar: Detected Alibaba email preferences page, using Alibaba-specific logic...`);
          
          // First, try to find and click "Unsubscribe from all" link/div
          const unsubscribeAllSelectors = [
            '.pc-main--unsubscribeAll--1_Of15J', // Specific Alibaba class
            'div:has-text("Unsubscribe from all")',
            'a:has-text("Unsubscribe from all")',
            '[class*="unsubscribeAll"]',
            'div[class*="unsubscribe"]'
          ];
          
          let unsubscribeAllClicked = false;
          for (const selector of unsubscribeAllSelectors) {
            try {
              const unsubscribeAllElement = await page.$(selector);
              if (unsubscribeAllElement) {
                const isVisible = await unsubscribeAllElement.isVisible();
                if (isVisible) {
                  await unsubscribeAllElement.click({ timeout: 5000 });
                  actions.push('alibaba_unsubscribe_all_clicked');
                  status = 'form_interacted';
                  unsubscribeAllClicked = true;
                  console.log(`[${new Date().toISOString()}] Sidecar: Clicked "Unsubscribe from all" element`);
                  await page.waitForTimeout(1500); // Wait for any modal or confirmation
                  break;
                }
              }
            } catch (e) {
              // Continue trying other selectors
              console.log(`[${new Date().toISOString()}] Sidecar: Error with selector ${selector}:`, e.message);
            }
          }
          
          // Handle Alibaba toggle switches (mt-switch)
          const switches = await page.$$('.mt-switch.mt-switch--checked');
          console.log(`[${new Date().toISOString()}] Sidecar: Found ${switches.length} Alibaba toggle switch(es) in checked state`);
          
          for (const switchElement of switches) {
            try {
              // Click the switch to toggle it off
              await switchElement.click({ timeout: 5000 });
              actions.push('alibaba_switch_toggled_off');
              status = 'form_interacted';
              console.log(`[${new Date().toISOString()}] Sidecar: Toggled off Alibaba switch`);
              await page.waitForTimeout(500);
            } catch (switchError) {
              console.log(`[${new Date().toISOString()}] Sidecar: Failed to toggle switch:`, switchError.message);
              // Try JavaScript fallback
              try {
                await switchElement.evaluate(el => {
                  el.click();
                });
                actions.push('alibaba_switch_toggled_off_js');
                status = 'form_interacted';
                console.log(`[${new Date().toISOString()}] Sidecar: Toggled switch via JavaScript`);
              } catch (jsError) {
                console.error(`[${new Date().toISOString()}] Sidecar: Failed to toggle switch via JS:`, jsError.message);
              }
            }
          }
          
          // Handle Alibaba checkboxes (mt-checkbox-container with selected state)
          const alibabaCheckboxes = await page.$$('.mt-checkbox-circle.mt-checkbox-circle--selected');
          console.log(`[${new Date().toISOString()}] Sidecar: Found ${alibabaCheckboxes.length} Alibaba checkbox(es) in selected state`);
          
          for (const checkboxCircle of alibabaCheckboxes) {
            try {
              // Find the parent checkbox container and click it
              const checkboxContainerHandle = await checkboxCircle.evaluateHandle(el => {
                return el.closest('.mt-checkbox-container');
              });
              
              const container = checkboxContainerHandle.asElement();
              if (container) {
                await container.click({ timeout: 5000 });
                actions.push('alibaba_checkbox_unchecked');
                status = 'form_interacted';
                console.log(`[${new Date().toISOString()}] Sidecar: Unchecked Alibaba checkbox`);
                await page.waitForTimeout(500);
              } else {
                // Fallback: click the circle directly
                await checkboxCircle.click({ timeout: 5000 });
                actions.push('alibaba_checkbox_unchecked_direct');
                status = 'form_interacted';
                console.log(`[${new Date().toISOString()}] Sidecar: Unchecked Alibaba checkbox (direct click)`);
                await page.waitForTimeout(500);
              }
            } catch (checkboxError) {
              console.log(`[${new Date().toISOString()}] Sidecar: Failed to uncheck Alibaba checkbox:`, checkboxError.message);
              // Try JavaScript fallback
              try {
                await checkboxCircle.evaluate(el => {
                  const container = el.closest('.mt-checkbox-container');
                  if (container) {
                    container.click();
                  } else {
                    el.click();
                  }
                });
                actions.push('alibaba_checkbox_unchecked_js');
                status = 'form_interacted';
                console.log(`[${new Date().toISOString()}] Sidecar: Unchecked checkbox via JavaScript`);
              } catch (jsError) {
                console.error(`[${new Date().toISOString()}] Sidecar: Failed to uncheck checkbox via JS:`, jsError.message);
              }
            }
          }
          
          // Look for "Save preferences" button
          const saveButtonSelectors = [
            '.pc-main--formButton--2yvWfqu', // Specific Alibaba class
            'div:has-text("Save preferences")',
            'button:has-text("Save preferences")',
            '[class*="formButton"]:has-text("Save")',
            'div[class*="button"]:has-text("Save preferences")'
          ];
          
          let saveButtonClicked = false;
          for (const selector of saveButtonSelectors) {
            try {
              const saveButton = await page.$(selector);
              if (saveButton) {
                const isVisible = await saveButton.isVisible();
                if (isVisible) {
                  await saveButton.click({ timeout: 5000 });
                  actions.push('alibaba_save_preferences_clicked');
                  status = 'submitted';
                  saveButtonClicked = true;
                  console.log(`[${new Date().toISOString()}] Sidecar: Clicked "Save preferences" button`);
                  await page.waitForTimeout(2000); // Wait for form submission
                  break;
                }
              }
            } catch (e) {
              console.log(`[${new Date().toISOString()}] Sidecar: Error with save button selector ${selector}:`, e.message);
            }
          }
          
          // Try text-based search for save button as fallback
          if (!saveButtonClicked) {
            try {
              const allDivs = await page.$$('div');
              for (const div of allDivs) {
                const text = (await div.textContent() || '').toLowerCase().trim();
                if (text === 'save preferences' || text.includes('save preferences')) {
                  const isVisible = await div.isVisible();
                  if (isVisible) {
                    await div.click({ timeout: 5000 });
                    actions.push('alibaba_save_preferences_clicked_text');
                    status = 'submitted';
                    saveButtonClicked = true;
                    console.log(`[${new Date().toISOString()}] Sidecar: Clicked "Save preferences" button (text match)`);
                    await page.waitForTimeout(2000);
                    break;
                  }
                }
              }
            } catch (textSearchError) {
              console.error(`[${new Date().toISOString()}] Sidecar: Error in text-based button search:`, textSearchError);
            }
          }
          
          // If we interacted with Alibaba elements, mark as handled
          if (unsubscribeAllClicked || switches.length > 0 || alibabaCheckboxes.length > 0 || saveButtonClicked) {
            console.log(`[${new Date().toISOString()}] Sidecar: Completed Alibaba-specific unsubscribe actions`);
            isAlibabaHandled = true;
          }
        }
      } catch (alibabaError) {
        console.error(`[${new Date().toISOString()}] Sidecar: Error in Alibaba-specific handling:`, alibabaError);
      }

      // Step 2: Check if there's a form that needs filling (skip if Alibaba already handled)
      console.log(`[${new Date().toISOString()}] Sidecar: Checking for forms on page...`);
      const forms = await page.$$('form');
      console.log(`[${new Date().toISOString()}] Sidecar: Found ${forms.length} form(s) on page`);
      if (forms.length > 0 && !isAlibabaHandled && !isBambooHRHandled) {
        actions.push('form_detected');
        console.log(`[${new Date().toISOString()}] Sidecar: Form detected, processing...`);
        
        // Try to find and interact with unsubscribe-related form elements
        try {
          // Look for checkboxes
          console.log(`[${new Date().toISOString()}] Sidecar: Looking for checkboxes...`);
          const checkboxes = await page.$$('input[type="checkbox"]');
          console.log(`[${new Date().toISOString()}] Sidecar: Found ${checkboxes.length} checkbox(es)`);
          
          if (checkboxes.length >= 2) {
            console.log(`[${new Date().toISOString()}] Sidecar: Multiple checkboxes detected, analyzing labels...`);
            // Multiple checkboxes - likely a subscription preferences form
            // Strategy: Check labels to see if they're subscription categories vs unsubscribe checkboxes
            
            let unsubscribeCheckboxes = 0;
            let categoryCheckboxes = 0;
            
            // Analyze checkbox labels to determine type
            for (const checkbox of checkboxes) {
              const label = await checkbox.evaluate(el => {
                let lbl = '';
                
                // 1. Check if label wraps the checkbox (parent label)
                const wrappingLabel = el.closest('label');
                if (wrappingLabel) {
                  lbl = wrappingLabel.textContent || '';
                } else {
                  // 2. Find label by 'for' attribute matching checkbox id
                  const id = el.getAttribute('id');
                  if (id) {
                    const labelElement = document.querySelector(`label[for="${id}"]`);
                    if (labelElement) {
                      lbl = labelElement.textContent || '';
                    }
                  }
                  
                  // 3. Fallback to aria-label or title
                  if (!lbl) {
                    lbl = el.getAttribute('aria-label') || el.getAttribute('title') || '';
                  }
                  
                  // 4. Try to find adjacent label (sibling)
                  if (!lbl) {
                    let sibling = el.nextElementSibling;
                    while (sibling && !lbl) {
                      if (sibling.tagName === 'LABEL') {
                        lbl = sibling.textContent || '';
                        break;
                      }
                      sibling = sibling.nextElementSibling;
                    }
                  }
                }
                
                return (lbl || '').toLowerCase().trim();
              });
              
              // Check if this is an unsubscribe checkbox (should be checked)
              const isUnsubscribeCheckbox = 
                label.includes('unsubscribe') ||
                label.includes('opt-out') ||
                label.includes('opt out') ||
                label.includes('berhenti');
              
              // Check if this is a subscription category (Program, Promo, Jobs, etc.)
              const isCategoryCheckbox = 
                label.includes('program') ||
                label.includes('promo') ||
                label.includes('newsletter') ||
                label.includes('marketing') ||
                label.includes('updates') ||
                label.includes('events') ||
                label.includes('jobs') ||
                label.includes('lowongan') ||
                label.includes('pekerjaan') ||
                label.includes('academy') ||
                label.includes('challenge') ||
                label.includes('product') ||
                label.includes('announcement') ||
                label.includes('langganan') || // Indonesian: subscription
                label.includes('email langganan') || // Indonesian: email subscription
                label.includes('tipe informasi') || // Indonesian: information type
                label.includes('informasi'); // Indonesian: information
              
              if (isUnsubscribeCheckbox) {
                unsubscribeCheckboxes++;
              } else if (isCategoryCheckbox || (label.length > 0 && !isUnsubscribeCheckbox)) {
                categoryCheckboxes++;
              }
            }
            
            // If we have more category checkboxes than unsubscribe checkboxes, treat as preferences form
            // Uncheck ALL checkboxes (this unsubscribes from all categories)
            console.log(`[${new Date().toISOString()}] Sidecar: Category checkboxes: ${categoryCheckboxes}, Unsubscribe checkboxes: ${unsubscribeCheckboxes}`);
            
            // Also check if form title/heading suggests subscription preferences
            const pageTitle = await page.title();
            const headingText = await page.evaluate(() => {
              const h1 = document.querySelector('h1, h2, h3, h4');
              return h1 ? h1.textContent.toLowerCase() : '';
            });
            const isSubscriptionPreferencesPage = 
              pageTitle.toLowerCase().includes('subscription') ||
              pageTitle.toLowerCase().includes('preferences') ||
              pageTitle.toLowerCase().includes('langganan') ||
              headingText.includes('langganan') ||
              headingText.includes('email langganan') ||
              headingText.includes('tipe informasi');
            
            if (categoryCheckboxes > unsubscribeCheckboxes || categoryCheckboxes >= 2 || (isSubscriptionPreferencesPage && checkboxes.length >= 2)) {
              console.log(`[${new Date().toISOString()}] Sidecar: Detected preferences form (categories: ${categoryCheckboxes}, unsubscribe: ${unsubscribeCheckboxes}, page title suggests preferences: ${isSubscriptionPreferencesPage}) - unchecking all checkboxes...`);
              let uncheckedCount = 0;
              for (const checkbox of checkboxes) {
                const isChecked = await checkbox.isChecked();
                console.log(`[${new Date().toISOString()}] Sidecar: Checkbox checked state: ${isChecked}`);
                if (isChecked) {
                  try {
                    // First try to uncheck directly with force (bypasses pointer interception)
                    await checkbox.uncheck({ force: true, timeout: 5000 });
                    uncheckedCount++;
                    console.log(`[${new Date().toISOString()}] Sidecar: Successfully unchecked checkbox via force`);
                  } catch (uncheckError) {
                    console.log(`[${new Date().toISOString()}] Sidecar: Force uncheck failed, trying to click label...`);
                    // If uncheck fails, try clicking the associated label
                    try {
                      const checkboxId = await checkbox.getAttribute('id');
                      if (checkboxId) {
                        const label = await page.$(`label[for="${checkboxId}"]`);
                        if (label) {
                          await label.click({ timeout: 5000 });
                          // Wait a bit and verify it's unchecked
                          await page.waitForTimeout(500);
                          const nowChecked = await checkbox.isChecked();
                          if (!nowChecked) {
                            uncheckedCount++;
                            console.log(`[${new Date().toISOString()}] Sidecar: Successfully unchecked via label click`);
                          } else {
                            console.log(`[${new Date().toISOString()}] Sidecar: Label click didn't uncheck, checkbox still checked`);
                          }
                        } else {
                          throw new Error('Label not found');
                        }
                      } else {
                        throw new Error('Checkbox has no id');
                      }
                    } catch (labelError) {
                      console.log(`[${new Date().toISOString()}] Sidecar: Label click failed, trying JavaScript evaluation...`);
                      // Last resort: Use JavaScript to directly set checked = false
                      try {
                        await checkbox.evaluate(el => {
                          el.checked = false;
                          // Trigger change event
                          el.dispatchEvent(new Event('change', { bubbles: true }));
                          el.dispatchEvent(new Event('click', { bubbles: true }));
                        });
                        uncheckedCount++;
                        console.log(`[${new Date().toISOString()}] Sidecar: Successfully unchecked via JavaScript`);
                      } catch (jsError) {
                        console.error(`[${new Date().toISOString()}] Sidecar: All methods failed to uncheck checkbox:`, jsError.message);
                      }
                    }
                  }
                }
              }
              console.log(`[${new Date().toISOString()}] Sidecar: Unchecked ${uncheckedCount} checkbox(es) out of ${checkboxes.length} total`);
              if (uncheckedCount > 0) {
                actions.push(`unchecked_${uncheckedCount}_preferences`);
                status = 'form_interacted';
                
                // After unchecking, try to find and click submit button
                console.log(`[${new Date().toISOString()}] Sidecar: Looking for submit/save button...`);
                const submitSelectors = [
                  'button[type="submit"]',
                  'input[type="submit"]',
                  'button:has-text("save")',
                  'button:has-text("Save")',
                  'button:has-text("update")',
                  'button:has-text("Update")',
                  'button:has-text("ubah")', // Indonesian: change
                  'button:has-text("Ubah")',
                  'button:has-text("change")',
                  'button:has-text("Change")',
                  'button:has-text("langganan")', // Indonesian: subscription
                  'button:has-text("Langganan")',
                  'button.dcd-btn-primary', // Dicoding's primary button class
                  'button.btn-primary'
                ];
                
                // First try CSS selectors
                for (const selector of submitSelectors) {
                  try {
                    const submitButton = await page.$(selector);
                    if (submitButton) {
                      const isVisible = await submitButton.isVisible();
                      const buttonText = await submitButton.textContent();
                      console.log(`[${new Date().toISOString()}] Sidecar: Found submit button with selector "${selector}", text: "${buttonText}", visible: ${isVisible}`);
                      if (isVisible) {
                        await submitButton.click();
                        actions.push(`submit_button_clicked: ${buttonText}`);
                        status = 'submitted';
                        console.log(`[${new Date().toISOString()}] Sidecar: Clicked submit button`);
                        await page.waitForTimeout(2000); // Wait for form submission
                        break;
                      }
                    }
                  } catch (submitError) {
                    // Continue trying other selectors
                    console.log(`[${new Date().toISOString()}] Sidecar: Error with selector ${selector}:`, submitError.message);
                  }
                }
                
                // If no button found by selector, try finding by text content (case-insensitive)
                if (status === 'form_interacted') {
                  console.log(`[${new Date().toISOString()}] Sidecar: Trying to find submit button by text content...`);
                  try {
                    const allButtons = await page.$$('button, input[type="submit"]');
                    for (const button of allButtons) {
                      const buttonText = (await button.textContent() || '').toLowerCase().trim();
                      const isVisible = await button.isVisible();
                      console.log(`[${new Date().toISOString()}] Sidecar: Button text: "${buttonText}", visible: ${isVisible}`);
                      
                      if (isVisible && (
                        buttonText.includes('save') ||
                        buttonText.includes('update') ||
                        buttonText.includes('change') ||
                        buttonText.includes('ubah') ||
                        buttonText.includes('submit') ||
                        buttonText.includes('confirm') ||
                        buttonText.includes('langganan') ||
                        buttonText.includes('unsubscribe')
                      )) {
                        await button.click();
                        actions.push(`submit_button_clicked_via_text: ${buttonText}`);
                        status = 'submitted';
                        console.log(`[${new Date().toISOString()}] Sidecar: Clicked submit button via text matching`);
                        await page.waitForTimeout(2000);
                        break;
                      }
                    }
                  } catch (textMatchError) {
                    console.error(`[${new Date().toISOString()}] Sidecar: Error finding button by text:`, textMatchError);
                  }
                }
              }
            } else {
              // Normal unsubscribe form - check unsubscribe-related checkboxes
              for (const checkbox of checkboxes) {
                const label = await checkbox.evaluate(el => {
                  const lbl = el.closest('label')?.textContent || 
                             el.getAttribute('aria-label') || 
                             el.getAttribute('title') || '';
                  return lbl.toLowerCase();
                });
                
                if (label.includes('unsubscribe') || 
                    label.includes('opt-out') || 
                    label.includes('opt out') ||
                    label.includes('berhenti')) {
                  const isChecked = await checkbox.isChecked();
                  if (!isChecked) {
                    await checkbox.check();
                    actions.push('checkbox_checked');
                    status = 'form_interacted';
                  }
                }
              }
            }
          } else if (checkboxes.length === 1) {
            // Single checkbox - check if it's unsubscribe-related
            const checkbox = checkboxes[0];
            const label = await checkbox.evaluate(el => {
              const lbl = el.closest('label')?.textContent || 
                         el.getAttribute('aria-label') || 
                         el.getAttribute('title') || '';
              return lbl.toLowerCase();
            });
            
            if (label.includes('unsubscribe') || 
                label.includes('opt-out') || 
                label.includes('opt out') ||
                label.includes('berhenti')) {
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

          // Fill email/text input fields (like email confirmation)
          // Get email value from request body, URL, or placeholder
          let emailValue = email || null;
          if (!emailValue) {
            // Try to extract from URL
            const emailMatch = url.match(/[?&]email=([^&]+)/);
            emailValue = emailMatch ? decodeURIComponent(emailMatch[1]) : null;
          }
          
          if (emailValue) {
            console.log(`[${new Date().toISOString()}] Sidecar: Found email value to fill: ${emailValue}`);
          }
          
          const textInputs = await page.$$('input[type="text"], input[type="email"], input:not([type])');
          console.log(`[${new Date().toISOString()}] Sidecar: Found ${textInputs.length} text/email input(s)`);
          
          for (const input of textInputs) {
            try {
              const placeholder = await input.getAttribute('placeholder') || '';
              const name = await input.getAttribute('name') || '';
              const id = await input.getAttribute('id') || '';
              const type = await input.getAttribute('type') || '';
              
              // Get label text if available
              let labelText = '';
              try {
                const inputId = await input.getAttribute('id');
                if (inputId) {
                  const labelElement = await page.$(`label[for="${inputId}"]`);
                  if (labelElement) {
                    labelText = (await labelElement.textContent() || '').toLowerCase().trim();
                  }
                }
                // Also check if wrapped in label
                const wrappingLabel = await input.evaluateHandle(el => el.closest('label'));
                if (wrappingLabel && (await wrappingLabel.asElement())) {
                  const wrapLabelText = await wrappingLabel.asElement().then(l => l ? l.textContent() : null);
                  if (wrapLabelText) {
                    labelText = wrapLabelText.toLowerCase().trim();
                  }
                }
              } catch (labelError) {
                // Ignore label errors
              }
              
              const lowerPlaceholder = placeholder.toLowerCase();
              const lowerName = name.toLowerCase();
              const lowerId = id.toLowerCase();
              const lowerLabel = labelText;
              
              // Skip if already has value
              const currentValue = await input.inputValue();
              if (currentValue) {
                console.log(`[${new Date().toISOString()}] Sidecar: Input already has value, skipping: ${name || id || 'unnamed'}`);
                continue;
              }
              
              // Check if this looks like an email field
              const looksLikeEmailField = 
                type === 'email' ||
                lowerPlaceholder.includes('email') || 
                lowerName.includes('email') || 
                lowerId.includes('email') ||
                lowerLabel.includes('email') ||
                lowerName.includes('e-mail') ||
                lowerId.includes('e-mail');
              
              // Also check for generic "email address" or "email" text patterns
              const genericEmailPatterns = [
                'email address',
                'e-mail address',
                'your email',
                'email id',
                'mail'
              ];
              const hasGenericEmailPattern = genericEmailPatterns.some(pattern => 
                lowerPlaceholder.includes(pattern) || 
                lowerName.includes(pattern) || 
                lowerId.includes(pattern) ||
                lowerLabel.includes(pattern)
              );
              
              if (looksLikeEmailField || (hasGenericEmailPattern && emailValue)) {
                console.log(`[${new Date().toISOString()}] Sidecar: Found email field: name="${name}", id="${id}", placeholder="${placeholder}", label="${labelText}"`);
                
                if (emailValue) {
                  try {
                    await input.fill(emailValue, { timeout: 5000 });
                    actions.push(`email_filled: ${name || id || 'field'}`);
                    status = 'form_interacted';
                    console.log(`[${new Date().toISOString()}] Sidecar: Filled email field with: ${emailValue}`);
                    await page.waitForTimeout(300); // Small delay after filling
                  } catch (fillError) {
                    console.log(`[${new Date().toISOString()}] Sidecar: Failed to fill email field: ${fillError.message}`);
                  }
                } else {
                  console.log(`[${new Date().toISOString()}] Sidecar: Email field detected but no email value available to fill`);
                }
              }
            } catch (inputError) {
              console.log(`[${new Date().toISOString()}] Sidecar: Error processing input field: ${inputError.message}`);
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
      console.log(`[${new Date().toISOString()}] Sidecar: Looking for unsubscribe buttons/links...`);
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
      console.log(`[${new Date().toISOString()}] Sidecar: Trying ${unsubscribeSelectors.length} selectors...`);
      for (const selector of unsubscribeSelectors) {
        try {
          // Wait a bit for element to be available
          await page.waitForSelector(selector, { timeout: 3000 }).catch(() => null);
          const element = await page.$(selector);
          
          if (element) {
            const isVisible = await element.isVisible();
            if (isVisible) {
              console.log(`[${new Date().toISOString()}] Sidecar: Found visible element with selector: ${selector}, clicking...`);
              await element.click({ timeout: 5000 });
              clicked = true;
              actions.push('button_clicked');
              status = 'submitted';
              console.log(`[${new Date().toISOString()}] Sidecar: Element clicked, waiting 3s...`);
              
              // Wait for navigation or form submission
              await page.waitForTimeout(3000);
              
              // Check if we navigated or if form was submitted
              try {
                console.log(`[${new Date().toISOString()}] Sidecar: Checking for navigation...`);
                await page.waitForNavigation({ timeout: 3000 });
                status = 'navigated';
                console.log(`[${new Date().toISOString()}] Sidecar: Navigation detected`);
                actions.push('navigation_detected');
              } catch (navError) {
                // No navigation, might be AJAX form submit
                console.log(`[${new Date().toISOString()}] Sidecar: No navigation detected (might be AJAX)`);
                status = 'form_submitted';
              }
              
              break;
            }
          }
        } catch (e) {
          // Continue to next selector
          console.log(`[${new Date().toISOString()}] Sidecar: Selector failed: ${e.message}`);
          continue;
        }
      }
      
      if (!clicked) {
        console.log(`[${new Date().toISOString()}] Sidecar: No unsubscribe button/link found after trying all selectors`);
      }

      // If no button was clicked but form was interacted with, try to submit the form
      if (!clicked && forms.length > 0 && status === 'form_interacted') {
        try {
          // Look for submit button
          const submitButtons = await page.$$('button[type="submit"], input[type="submit"], button:not([type])');
          for (const submitBtn of submitButtons) {
            const text = await submitBtn.textContent();
            const value = await submitBtn.getAttribute('value');
            
            // Prefer unsubscribe-related submit buttons or preference form buttons
            const buttonTextLower = text?.toLowerCase() || '';
            const buttonValueLower = value?.toLowerCase() || '';
            
            if (buttonTextLower.includes('unsubscribe') || 
                buttonTextLower.includes('confirm') ||
                buttonTextLower.includes('submit') ||
                buttonTextLower.includes('ubah') ||
                buttonTextLower.includes('save') ||
                buttonTextLower.includes('update') ||
                buttonTextLower.includes('change') ||
                buttonTextLower.includes('langganan') ||
                buttonValueLower.includes('unsubscribe')) {
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
      console.log(`[${new Date().toISOString()}] Sidecar: Taking screenshot...`);
      const screenshot = await page.screenshot({ type: 'png' });
      console.log(`[${new Date().toISOString()}] Sidecar: Screenshot captured (${screenshot.length} bytes)`);

      console.log(`[${new Date().toISOString()}] Sidecar: Closing browser...`);
      await browser.close();
      console.log(`[${new Date().toISOString()}] Sidecar: Browser closed`);

      const responseTime = Date.now() - requestStartTime;
      console.log(`[${new Date().toISOString()}] Sidecar: Request completed in ${responseTime}ms. Status: ${status}, Actions: ${actions.length}`);

      return res.json({
        ok: true,
        status: status,
        actions: actions,
        screenshot_b64: screenshot.toString('base64')
      });
    } catch (error) {
      console.error(`[${new Date().toISOString()}] Sidecar: Error during page interaction:`, error);
      console.error(`[${new Date().toISOString()}] Sidecar: Error stack:`, error.stack);
      await browser.close();
      throw error;
    }
  } catch (e) {
    const errorTime = Date.now() - requestStartTime;
    console.error(`[${new Date().toISOString()}] Sidecar: Request failed after ${errorTime}ms`);
    console.error(`[${new Date().toISOString()}] Sidecar: Error:`, e);
    console.error(`[${new Date().toISOString()}] Sidecar: Error stack:`, e.stack);
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

