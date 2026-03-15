# DCC Marketing

RFP management platform — AI-powered proposal generation for public sector bids.

DCC Marketing bids on public sector RFPs (energy, manufacturing, etc.) with 100-page sales proposals. Pulse is building a platform to reduce 120-hour proposals to minimal time.

## Current Phase (ends beginning of April 2026)

- **ETL Pipeline:** Box.com → MongoDB (vector database)
- **AI Layer:** Claude (Anthropic) on top of the vector DB
- **Integrations:** HubSpot, BidPrime, GovWin
- **Deploy target:** Cloud Run via Cloud Build
- **Stack:** TypeScript/React

## Future Phases (through 2026)

- Chat application on top of the proposal generation tool
- Full internal operations infrastructure
- Evolving toward AI transformation roadmap similar to SWG
