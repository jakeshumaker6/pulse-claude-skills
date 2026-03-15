# Pulse Branding Reference

Used by `/report` to generate client-ready HTML reports with correct Pulse branding.

## Colors (from pulsemarketing.co)

| Token | Hex | Usage |
|-------|-----|-------|
| Primary | `#ef6552` | Coral — buttons, accents, metric values |
| Background | `#292929` | Dark page background |
| Card | `#303030` | Card/surface backgrounds |
| Foreground | `#f8f6f1` | Warm white — body text, headings |
| Secondary | `#a46f6a` | Muted coral — footer text, subdued elements |
| Muted FG | `#e0bbb8` | Muted foreground — labels, table headers |
| Accent | `#ffe3e0` | Light pink — accent backgrounds |
| Destructive | `#ef4343` | Red — errors, critical badges |
| Border | `#404040` | Subtle borders and dividers |

## Fonts

- **Headings:** Space Grotesk (500, 600, 700)
- **Body:** Inter (400, 500, 600)

Google Fonts import:
```
https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Space+Grotesk:wght@500;600;700&display=swap
```

## Logo

PNG logo hosted at: `https://pulsemarketing.co/assets/PulseLogo-CxebLJwD.png`

For self-contained HTML reports, read the full base64 data URI from `report/logo-base64.txt` (sibling file). This embeds the logo directly in the HTML so reports work offline with no network dependency.

## Website

- URL: https://pulsemarketing.co
- Tagline: "Built for what comes next."
- Services: AI Transformation. Engineering. Marketing.
