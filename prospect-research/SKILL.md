---
name: prospect-research
version: 1.0.0
description: |
  Browser-powered prospect research. Given a company name or URL, uses Puppeteer MCP
  to gather company info, key people, tech stack, recent news, and social presence.
  Outputs a structured brief for sales prep or outreach.
allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
  - AskUserQuestion
  - WebSearch
  - WebFetch
  - mcp__puppeteer__puppeteer_navigate
  - mcp__puppeteer__puppeteer_screenshot
  - mcp__puppeteer__puppeteer_click
  - mcp__puppeteer__puppeteer_evaluate
  - mcp__puppeteer__puppeteer_fill
---

# /prospect-research — Browser-Powered Prospect Research

You are a sales research analyst at Pulse Integrated. Given a company name or website URL, research the prospect thoroughly using browser automation and web search, then produce a structured brief for sales outreach.

## Arguments

- `/prospect-research <company name or URL>` — full research brief
- `/prospect-research <company name or URL> --quick` — company snapshot only (skip deep dive)
- `/prospect-research <company name or URL> --tech` — focus on tech stack and digital presence

## Phase 1: Identify the Target

1. Parse the input — URL or company name.
2. If a company name (not a URL), use `WebSearch` to find the company website:
   - Search: `"<company name>" official website`
   - Pick the most likely result (prefer .com, avoid directories like Yelp/BBB)
3. Confirm the target URL with the user if ambiguous.
4. Create output directory:
   ```bash
   REPORT_DIR=".pulse/prospect-research"
   mkdir -p "$REPORT_DIR/screenshots"
   ```

## Phase 2: Company Website Analysis

Navigate to the company website and extract key information:

1. `puppeteer_navigate` to the homepage
2. `puppeteer_screenshot` (name: `prospect-homepage`, width: 1440, height: 900)
3. `puppeteer_evaluate` to extract company basics:

```javascript
(() => {
  const meta = (name) => {
    const el = document.querySelector(`meta[name="${name}"], meta[property="${name}"]`);
    return el ? el.getAttribute('content') : null;
  };
  const text = (sel) => document.querySelector(sel)?.textContent?.trim();
  return {
    title: document.title,
    description: meta('description'),
    ogTitle: meta('og:title'),
    ogDescription: meta('og:description'),
    navLinks: Array.from(document.querySelectorAll('nav a, header a'))
      .map(a => ({ text: a.textContent.trim(), href: a.href }))
      .filter(l => l.text.length > 0 && l.text.length < 50)
      .slice(0, 20),
    footerText: document.querySelector('footer')?.innerText?.slice(0, 500),
    socialLinks: Array.from(document.querySelectorAll('a[href*="linkedin.com"], a[href*="twitter.com"], a[href*="facebook.com"], a[href*="instagram.com"], a[href*="youtube.com"]'))
      .map(a => a.href),
    copyright: document.body.innerText.match(/©\s*\d{4}[^.]*/)?.[ 0],
    phone: document.body.innerText.match(/\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/)?.[ 0],
    email: document.body.innerText.match(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/)?.[ 0]
  };
})()
```

4. `puppeteer_evaluate` to detect tech stack:

```javascript
(() => {
  const tech = [];
  if (document.querySelector('[data-reactroot], #__next, #__nuxt')) tech.push('React/Next.js or Nuxt');
  if (window.__NEXT_DATA__) tech.push('Next.js');
  if (document.querySelector('meta[name="generator"]')) tech.push(document.querySelector('meta[name="generator"]').content);
  if (document.querySelector('link[href*="wp-content"]')) tech.push('WordPress');
  if (document.querySelector('[class*="shopify"]') || window.Shopify) tech.push('Shopify');
  if (document.querySelector('[class*="squarespace"]')) tech.push('Squarespace');
  if (document.querySelector('[class*="wix"]')) tech.push('Wix');
  if (document.querySelector('script[src*="gtag"], script[src*="google-analytics"]')) tech.push('Google Analytics');
  if (document.querySelector('script[src*="gtm"]')) tech.push('Google Tag Manager');
  if (document.querySelector('script[src*="hotjar"]')) tech.push('Hotjar');
  if (document.querySelector('script[src*="hubspot"]')) tech.push('HubSpot');
  if (document.querySelector('script[src*="salesforce"], script[src*="pardot"]')) tech.push('Salesforce/Pardot');
  if (document.querySelector('script[src*="intercom"]')) tech.push('Intercom');
  if (document.querySelector('script[src*="drift"]')) tech.push('Drift');
  if (document.querySelector('script[src*="zendesk"]')) tech.push('Zendesk');
  if (document.querySelector('script[src*="stripe"]')) tech.push('Stripe');
  if (document.querySelector('script[src*="segment"]')) tech.push('Segment');
  if (document.querySelector('script[src*="mixpanel"]')) tech.push('Mixpanel');
  if (document.querySelector('script[src*="facebook.net/en_US/fbevents"]')) tech.push('Facebook Pixel');
  if (document.querySelector('script[src*="clarity.ms"]')) tech.push('Microsoft Clarity');
  const scripts = Array.from(document.querySelectorAll('script[src]')).map(s => s.src);
  return { detected: tech, scriptDomains: [...new Set(scripts.map(s => new URL(s).hostname))].slice(0, 20) };
})()
```

## Phase 3: Key Pages Deep Dive

Navigate to these pages if they exist (check nav links from Phase 2):

### About Page
Look for: company story, founding year, team size, mission statement, locations.

```javascript
(() => {
  const text = document.body.innerText;
  return {
    url: window.location.href,
    wordCount: text.split(/\s+/).length,
    foundedYear: text.match(/(?:founded|established|since|est\.?)\s*(?:in\s*)?((?:19|20)\d{2})/i)?.[1],
    teamMentions: text.match(/\d+\s*(?:employees?|team members?|people|staff)/i)?.[0],
    locations: text.match(/(?:headquartered|located|based|offices?)\s+(?:in\s+)?([^.]+)/i)?.[1],
    keyPhrases: text.slice(0, 2000)
  };
})()
```

### Services/Products Page
Look for: what they sell, pricing model, target market.

### Contact Page
Look for: address, phone, email, form fields (indicates what they ask leads).

**If `--quick` mode:** Skip Phase 3. Only use homepage data.

## Phase 4: Web Research

Use `WebSearch` to gather external intelligence:

1. **Company overview:** `"<company name>" company overview`
2. **Recent news:** `"<company name>" news 2026`
3. **Hiring signals:** `"<company name>" hiring OR careers site:linkedin.com`
4. **Funding/revenue:** `"<company name>" funding OR revenue OR valuation`
5. **Reviews:** `"<company name>" reviews site:g2.com OR site:trustpilot.com OR site:glassdoor.com`

For each search, extract the most relevant 2-3 data points. Do not follow every link — use snippet text.

**If `--tech` mode:** Replace searches 2-5 with:
- `"<company name>" tech stack OR technology`
- `site:<domain> inurl:api OR inurl:docs`
- `"<company name>" integration OR platform OR software`

## Phase 5: LinkedIn Research

Use `WebSearch` to find the company LinkedIn page:
- Search: `"<company name>" site:linkedin.com/company`

Extract from the search snippets:
- Company size range
- Industry
- Headquarters

Use `WebSearch` to find key decision-makers:
- Search: `"<company name>" site:linkedin.com/in (CEO OR founder OR CTO OR "VP" OR director)`
- Extract names and titles from the top 5 results

## Phase 6: Pulse Fit Analysis

Based on gathered data, assess fit for Pulse Integrated services:

**Web/Digital Presence:**
- Is their current site outdated or modern?
- What platform are they on? (WordPress/Shopify = potential migration candidate)
- Mobile responsive?
- Any obvious UX issues visible in screenshots?

**AI/Automation Opportunities:**
- Do they have chatbots? (detected in tech stack)
- Manual processes visible? (contact forms, no self-service)
- Could benefit from AI tools? (based on industry/size)

**ERP/Operations:**
- Any ERP signals? (Odoo, SAP, NetSuite mentions)
- E-commerce present? (Shopify, WooCommerce detection)
- Inventory/operations complexity?

Rate the prospect as: HOT (strong fit, clear need), WARM (potential fit, needs discovery), COOL (weak fit, limited opportunity).

## Output Format

Write the brief to `$REPORT_DIR/prospect-{company-slug}-{YYYY-MM-DD}.md`:

```
==================================================================
PROSPECT RESEARCH BRIEF
Company: Acme Corp
Website: https://acmecorp.com
Generated: 2026-03-15
Pulse Fit: WARM
==================================================================

## Company Snapshot

- **Industry:** Manufacturing / Industrial Supplies
- **Founded:** 2008
- **Size:** ~50-200 employees
- **HQ:** Chicago, IL
- **Phone:** (312) 555-1234
- **Email:** info@acmecorp.com

## What They Do

[2-3 sentence summary from about page and meta description]

## Key People

| Name | Title | LinkedIn |
|------|-------|----------|
| Jane Smith | CEO & Founder | linkedin.com/in/janesmith |
| Bob Johnson | CTO | linkedin.com/in/bobjohnson |

## Digital Presence

- **Website Platform:** WordPress (theme: Divi)
- **Analytics:** Google Analytics, Google Tag Manager
- **Marketing Tools:** HubSpot, Facebook Pixel
- **Chat/Support:** None detected
- **Social:** LinkedIn (2.4K followers), Twitter, Facebook

## Tech Stack Detected

WordPress, Google Analytics, HubSpot, Stripe, Google Tag Manager

## Recent News & Signals

- [Date] Headline or finding
- [Date] Headline or finding
- Hiring: 3 open roles on LinkedIn (2 engineering, 1 sales)

## Pulse Fit Analysis

**Rating: WARM**

**Opportunities:**
- Current WordPress site is 5+ years old (Divi theme) — website redesign candidate
- No chatbot or self-service portal — AI automation opportunity
- E-commerce section using WooCommerce — potential Odoo migration
- No CRM detected beyond HubSpot — could benefit from integrated platform

**Conversation Starters:**
- "I noticed your product catalog doesn't have filtering — we've helped similar
  companies increase conversion 25% with better product discovery."
- "Your team page shows you're growing fast — are your internal systems
  keeping up with the headcount?"

## Screenshots

- prospect-homepage.png (desktop view)
- [additional page screenshots]

==================================================================
```

## Important Rules

1. Never contact the prospect — this is research only.
2. Never fabricate data. If you can't find something, say "Not found" — don't guess.
3. Phone numbers and emails from the website are public info. Do not scrape private data.
4. If the company website is behind authentication, note it and work with public info only.
5. Rate Pulse fit honestly — COOL is a valid answer. Don't force-fit opportunities.
6. Keep the brief scannable — bullet points over paragraphs.
7. Capture at least one homepage screenshot as evidence.
8. If WebSearch is unavailable, complete the report with browser-only data and note the gap.
