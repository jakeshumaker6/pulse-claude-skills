# S40S — Meeting Log

Auto-generated from Grain recordings. Do not edit manually — this file is updated by `scripts/sync-grain.sh`.

<!-- last_synced: 2026-03-14 -->

---

### Kate / Ashley / Jake
**Date:** 2026-03-12
**Attendees:** Jake Shumaker, Kate Olson, Ashley Engels

**Key Decisions:**
- Staged migration away from GoDaddy — evaluate full Microsoft 365 vs keeping GoDaddy hosting with DNS pointed to Pulse servers
- Google Cloud CDN for performance and resilience
- Minimal pre-launch website changes: remove large banner, restore subcategory structure

**Action Items:**
- [ ] Jake — Open GoDaddy support ticket and schedule 9 AM Pacific call with access code
- [ ] Jake — Coordinate DNS/A-record for safe cutover
- [ ] Kate — Compile feedback on product sheets and category structure
- [ ] Kate — Run major change pushback with Ashley and Jim

**Context & Notes:**
Migration planning session. Evaluating risks around domain transfer, email history, licensing, and timing during acquisition. Also covered shop page readability tweaks, backend invoice/zip-code handling, and hardware testing readiness for upcoming show.

---

### Kate / Jake
**Date:** 2026-03-11
**Attendees:** Jake Shumaker, Kate Olson

**Key Decisions:**
- Migrate Microsoft 365 off GoDaddy to dedicated tenant with step-by-step playbook
- Written authorization required before any publish
- Pomaro site: transfer domain from GoDaddy to Pulse server (transfer code + Ashley approval needed)

**Action Items:**
- [ ] Jake — Provide hands-on migration support over next few days
- [ ] Jake — Coordinate with Sean for ongoing managed IT
- [ ] Kate — Define variables, responsibilities, scope, costs, and timeline
- [ ] Kate — Schedule short follow-up to finalize items

**Context & Notes:**
Focused on avoiding email downtime or loss of history during M365 migration. Domain transfer timing could be minutes to 48 hours. Short-term email/cloud setup proposed while leaving room for future managed services.
