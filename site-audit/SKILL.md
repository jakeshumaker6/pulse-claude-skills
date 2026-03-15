---
name: site-audit
version: 1.0.0
description: |
  Browser-powered website audit. Crawls pages via Puppeteer MCP, captures screenshots,
  evaluates SEO meta tags, accessibility basics, performance metrics, broken links,
  console errors, and mobile responsiveness. Outputs a scored report with evidence.
allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
  - AskUserQuestion
  - mcp__puppeteer__puppeteer_navigate
  - mcp__puppeteer__puppeteer_screenshot
  - mcp__puppeteer__puppeteer_click
  - mcp__puppeteer__puppeteer_evaluate
---

# /site-audit — Browser-Powered Website Audit

You are a web auditor. Crawl a website using Puppeteer MCP, evaluate it across multiple dimensions, capture evidence, and produce a scored report.

## Arguments

- `/site-audit <url>` — full audit of the given URL
- `/site-audit <url> --quick` — homepage-only quick check
- `/site-audit <url> --seo` — SEO-focused audit only
- `/site-audit <url> --accessibility` — accessibility-focused audit only
- `/site-audit <url> --pages N` — limit crawl to N pages (default: 10)

## Phase 1: Initialize

1. Parse the target URL from the user's input. If no URL provided, ask for one.
2. Create the output directory:
   ```bash
   REPORT_DIR=".pulse/site-audits"
   mkdir -p "$REPORT_DIR/screenshots"
   ```
3. Record the start time.

## Phase 2: Homepage Analysis

Navigate to the target URL and capture the initial state:

1. Use `puppeteer_navigate` to load the page
2. Use `puppeteer_screenshot` to capture the homepage (name: `homepage`, width: 1440, height: 900)
3. Use `puppeteer_evaluate` to extract page metadata:

```javascript
(() => {
  const meta = (name) => {
    const el = document.querySelector(`meta[name="${name}"], meta[property="${name}"]`);
    return el ? el.getAttribute('content') : null;
  };
  return {
    title: document.title,
    description: meta('description'),
    ogTitle: meta('og:title'),
    ogDescription: meta('og:description'),
    ogImage: meta('og:image'),
    canonical: document.querySelector('link[rel="canonical"]')?.href,
    viewport: meta('viewport'),
    robots: meta('robots'),
    h1Count: document.querySelectorAll('h1').length,
    h1Text: Array.from(document.querySelectorAll('h1')).map(h => h.textContent.trim()),
    imgCount: document.querySelectorAll('img').length,
    imgNoAlt: document.querySelectorAll('img:not([alt]), img[alt=""]').length,
    linkCount: document.querySelectorAll('a[href]').length,
    consoleErrors: [],
    lang: document.documentElement.lang,
    charset: document.characterSet
  };
})()
```

4. Use `puppeteer_evaluate` to collect internal links for crawling:

```javascript
(() => {
  const origin = window.location.origin;
  const links = Array.from(document.querySelectorAll('a[href]'))
    .map(a => a.href)
    .filter(href => href.startsWith(origin))
    .filter(href => !href.match(/\.(pdf|zip|png|jpg|jpeg|gif|svg|css|js)$/i))
    .filter(href => !href.includes('#'));
  return [...new Set(links)].slice(0, 50);
})()
```

## Phase 3: Page Crawl

For each internal page (up to the page limit, default 10):

1. `puppeteer_navigate` to the page
2. `puppeteer_screenshot` (name: page slug, width: 1440, height: 900)
3. `puppeteer_evaluate` to extract:
   - Title tag
   - Meta description
   - H1 count and text
   - Images missing alt text
   - Console errors (check `window.__consoleErrors` if injected)
   - Any broken images (`img` elements with `naturalWidth === 0`)

```javascript
(() => {
  return {
    url: window.location.href,
    title: document.title,
    description: document.querySelector('meta[name="description"]')?.content,
    h1Count: document.querySelectorAll('h1').length,
    h1Text: Array.from(document.querySelectorAll('h1')).map(h => h.textContent.trim()),
    imgNoAlt: document.querySelectorAll('img:not([alt]), img[alt=""]').length,
    brokenImages: Array.from(document.querySelectorAll('img')).filter(i => !i.naturalWidth && i.src).map(i => i.src),
    wordCount: document.body?.innerText?.split(/\s+/).length || 0,
    hasStructuredData: !!document.querySelector('script[type="application/ld+json"]')
  };
})()
```

**If `--quick` mode:** Skip this phase entirely.

## Phase 4: Mobile Responsiveness Check

For the homepage and up to 3 key pages:

1. `puppeteer_screenshot` at mobile width (name: `mobile-homepage`, width: 375, height: 812)
2. `puppeteer_evaluate` to check for horizontal overflow:

```javascript
(() => {
  return {
    hasHorizontalScroll: document.body.scrollWidth > window.innerWidth,
    viewportMeta: document.querySelector('meta[name="viewport"]')?.content,
    touchTargetsTooSmall: Array.from(document.querySelectorAll('a, button, input, select'))
      .filter(el => {
        const rect = el.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0 && (rect.width < 44 || rect.height < 44);
      }).length
  };
})()
```

## Phase 5: Performance Check

Use `puppeteer_evaluate` on the homepage:

```javascript
(() => {
  const perf = performance.getEntriesByType('navigation')[0];
  const paint = performance.getEntriesByType('paint');
  return {
    domContentLoaded: perf ? Math.round(perf.domContentLoadedEventEnd - perf.startTime) : null,
    loadComplete: perf ? Math.round(perf.loadEventEnd - perf.startTime) : null,
    firstPaint: paint.find(p => p.name === 'first-paint')?.startTime,
    firstContentfulPaint: paint.find(p => p.name === 'first-contentful-paint')?.startTime,
    resourceCount: performance.getEntriesByType('resource').length,
    totalTransferSize: performance.getEntriesByType('resource')
      .reduce((sum, r) => sum + (r.transferSize || 0), 0),
    largeResources: performance.getEntriesByType('resource')
      .filter(r => r.transferSize > 500000)
      .map(r => ({ name: r.name.split('/').pop(), size: Math.round(r.transferSize / 1024) + 'KB' }))
  };
})()
```

## Phase 6: Accessibility Basics

Use `puppeteer_evaluate` on the homepage:

```javascript
(() => {
  const issues = [];
  if (!document.documentElement.lang) issues.push('Missing lang attribute on <html>');
  if (!document.title) issues.push('Missing <title>');
  const imgNoAlt = document.querySelectorAll('img:not([alt])').length;
  if (imgNoAlt > 0) issues.push(`${imgNoAlt} images missing alt attribute`);
  const inputNoLabel = Array.from(document.querySelectorAll('input:not([type="hidden"]), select, textarea'))
    .filter(el => {
      const id = el.id;
      return !el.getAttribute('aria-label') && !el.getAttribute('aria-labelledby') &&
        !(id && document.querySelector(`label[for="${id}"]`));
    }).length;
  if (inputNoLabel > 0) issues.push(`${inputNoLabel} form inputs missing labels`);
  const emptyLinks = Array.from(document.querySelectorAll('a'))
    .filter(a => !a.textContent.trim() && !a.getAttribute('aria-label') && !a.querySelector('img[alt]')).length;
  if (emptyLinks > 0) issues.push(`${emptyLinks} links with no accessible text`);
  const noSkipLink = !document.querySelector('a[href="#main"], a[href="#content"], [role="main"]');
  if (noSkipLink) issues.push('No skip navigation link found');
  const lowContrast = document.querySelectorAll('[style*="color: #ccc"], [style*="color: #ddd"], [style*="color: #eee"]').length;
  if (lowContrast > 0) issues.push(`${lowContrast} elements with potentially low contrast (inline styles)`);
  return { issues, totalIssues: issues.length };
})()
```

## Phase 7: Link Check

Use `puppeteer_evaluate` to gather all links, then check a sample:

```javascript
(() => {
  const links = Array.from(document.querySelectorAll('a[href]'))
    .map(a => ({ href: a.href, text: a.textContent.trim().slice(0, 50) }))
    .filter(l => l.href.startsWith('http'));
  const external = links.filter(l => !l.href.startsWith(window.location.origin));
  const internal = links.filter(l => l.href.startsWith(window.location.origin));
  return { internal: internal.slice(0, 30), external: external.slice(0, 20), totalLinks: links.length };
})()
```

For internal links, navigate to each (up to 30) and check for 404s by evaluating:
```javascript
document.title.toLowerCase().includes('404') || document.body.innerText.includes('Page not found')
```

## Scoring Rubric

Each category scored 0-100, then weighted:

| Category | Weight | Scoring |
|----------|--------|---------|
| SEO | 25% | -10 missing title, -10 missing description, -5 missing og tags, -10 no canonical, -15 no H1 or multiple H1s, -5 per page missing description |
| Performance | 20% | FCP < 1.5s=100, < 3s=70, < 5s=40, > 5s=20. -10 per large resource |
| Accessibility | 20% | -15 per critical issue (no lang, no labels), -8 per major (no alt, empty links), -3 per minor |
| Mobile | 15% | -30 horizontal scroll, -20 no viewport meta, -5 per 10 small touch targets |
| Content | 10% | -10 per page with < 100 words, -5 duplicate titles |
| Links | 10% | -15 per broken internal link, -5 per broken external link |

**Overall score:** Weighted average rounded to nearest integer.

**Grade mapping:** A (90-100), B (80-89), C (70-79), D (60-69), F (< 60)

## Output Format

Write the report to `$REPORT_DIR/audit-{domain}-{YYYY-MM-DD}.md`:

```
==================================================================
SITE AUDIT REPORT
URL: https://example.com
Date: 2026-03-15
Pages crawled: 10
Overall Score: 74/100 (Grade: C)
==================================================================

## Score Breakdown

| Category | Score | Weight | Weighted |
|----------|-------|--------|----------|
| SEO | 65 | 25% | 16.3 |
| Performance | 80 | 20% | 16.0 |
| Accessibility | 70 | 20% | 14.0 |
| Mobile | 85 | 15% | 12.8 |
| Content | 90 | 10% | 9.0 |
| Links | 60 | 10% | 6.0 |
| **TOTAL** | | | **74.1** |

## Critical Issues (Fix Now)

1. **[SEO]** Homepage missing meta description
   - Impact: Search engines show auto-generated snippets
   - Fix: Add <meta name="description" content="..."> to <head>

2. **[Accessibility]** 12 images missing alt text
   - Pages: /about, /services, /team
   - Fix: Add descriptive alt attributes to all images

## Warnings (Fix Soon)

...

## Passed Checks

- ✓ Valid viewport meta tag
- ✓ All internal links responding
- ✓ Language attribute present
- ...

## Page-by-Page Summary

| Page | Title | H1 | Description | Images (no alt) | Issues |
|------|-------|----|-------------|-----------------|--------|
| / | Example Co | 1 | Yes | 3 | 2 |
| /about | About Us | 1 | No | 5 | 3 |

## Performance

- First Contentful Paint: 1.2s
- DOM Content Loaded: 890ms
- Total Resources: 45
- Transfer Size: 2.3 MB
- Large resources: hero-bg.jpg (850KB), bundle.js (620KB)

## Screenshots

Screenshots saved to: .pulse/site-audits/screenshots/
- homepage.png (desktop)
- mobile-homepage.png (mobile 375px)
- [page screenshots...]

==================================================================
```

## Important Rules

1. Never modify the target website — this is read-only analysis.
2. Capture at least one screenshot per page visited.
3. If Puppeteer MCP is unavailable, report the error and STOP.
4. Handle navigation failures gracefully — log the error, skip the page, continue.
5. Respect robots.txt intent — do not crawl pages marked as disallowed.
6. Limit crawl depth to 2 levels from homepage unless user specifies otherwise.
7. If a page requires authentication, ask the user before attempting login.
8. All scores must be evidence-based — cite the specific finding for each deduction.
