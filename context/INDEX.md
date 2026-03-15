# Pulse Integrated — Shared Context

This directory contains shared knowledge for the Pulse team. Claude Code reads these files to understand our clients, workflows, patterns, and culture. This context is loaded automatically when skills reference it.

## Team

- [team.md](team.md) — Team roster, roles, hiring plans
- [engineering-culture.md](engineering-culture.md) — Core values, engineering philosophy, what to optimize for

## Clients

- [S40S](clients/s40s.md) — Priority #1: WooCommerce website, Odoo ERP, 3D AI/AR room builder
- [SWG](clients/swg.md) — AI transformation roadmap: unified chat, tax tools, RMD agent
- [DCC Marketing](clients/dcc.md) — RFP proposal generation platform: Box→MongoDB ETL, Claude AI layer
- [GAAPP](clients/gaapp.md) — Patient advocacy: asthma care map, search web app, 3 chatbots, member org sites
- [National Concerts](clients/national-concerts.md) — Website redesign, digital sales room, Instantly cold email campaigns
- [Other Clients](clients/other-clients.md) — ANAD, Brelaw, Family Home & Patio, FEAST, Hungerford, Main Place RE, Premier Fund

## Workflows

- [Sprint Process](workflows/sprint-process.md) — Weekly sprints, Monday planning, daily standups, biweekly retros
- [PR and Git Flow](workflows/pr-process.md) — Feature branch → staging → main with team testing
- [Client Handoffs](workflows/client-handoffs.md) — Acceptance agreements, call cadence, communication channel guide

## Patterns

- [Client Scoping](patterns/client-scoping.md) — How we scope new engagements: discovery → process mapping → solution design
- [AI Transformation Roadmap](patterns/ai-transformation-roadmap.md) — Structuring year-long AI integrations: data inventory → ETL → unified chat
- [Project Kickoff](patterns/project-kickoff.md) — Scope → ClickUp user stories → engineer assignment → autonomous development
- [Discovery Calls](patterns/discovery-calls.md) — Trigger point → process walk → edge cases → flow charts
- [Deploy Platforms](patterns/deploy-platforms.md) — Render, Google Cloud, Odoo.sh, SiteGround, Lovable/Supabase
- [Odoo 19 Gotchas](patterns/odoo-19-gotchas.md) — XML syntax changes, payment provider inline forms

## Updating This Context

Anyone on the team can update these files:

1. Edit the relevant file in `context/`
2. If adding a new file, add a link to `context/INDEX.md`
3. Commit, push, and tell the team to `git pull` their skills repo

**Do not put credentials, API keys, or personal preferences here.** Those belong in your personal `~/.claude/` memory, not in the shared repo.
