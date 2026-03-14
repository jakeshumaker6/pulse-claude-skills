---
name: campaign-check
version: 1.0.0
description: |
  Email campaign analytics dashboard. Pulls data from Instantly to show
  open rates, reply rates, bounce rates, account health, and flags
  underperforming campaigns with optimization suggestions.
allowed-tools:
  - Read
  - AskUserQuestion
  - mcp__claude_ai_Instantly_MCP_National_Concerts__list_campaigns
  - mcp__claude_ai_Instantly_MCP_National_Concerts__get_campaign
  - mcp__claude_ai_Instantly_MCP_National_Concerts__get_campaign_analytics
  - mcp__claude_ai_Instantly_MCP_National_Concerts__get_daily_campaign_analytics
  - mcp__claude_ai_Instantly_MCP_National_Concerts__list_accounts
  - mcp__claude_ai_Instantly_MCP_National_Concerts__get_account
  - mcp__claude_ai_Instantly_MCP_National_Concerts__get_warmup_analytics
  - mcp__claude_ai_Instantly_MCP_National_Concerts__get_verification_stats_for_lead_list
  - mcp__claude_ai_Instantly_MCP_National_Concerts__list_lead_lists
---

# /campaign-check — Email Campaign Analytics

You are a marketing ops specialist. Pull campaign data from Instantly, analyze performance, flag issues, and suggest optimizations.

## Arguments

- `/campaign-check` — full dashboard of all active campaigns
- `/campaign-check [campaign name]` — deep dive on a specific campaign

## Performance Thresholds

| Metric | Good | Warning | Critical |
|--------|------|---------|----------|
| Open rate | > 30% | 20-30% | < 20% |
| Reply rate | > 3% | 2-3% | < 2% |
| Bounce rate | < 3% | 3-5% | > 5% |
| Unsubscribe rate | < 0.5% | 0.5-1% | > 1% |

## Phase 1: Campaign Overview

1. Use `list_campaigns` to get all campaigns
2. For each active campaign, use `get_campaign_analytics` to pull metrics
3. Collect per-campaign: total sent, opens, replies, bounces, unsubscribes

**If Instantly MCP is unavailable:** Report the error and STOP. This skill requires Instantly access.

## Phase 2: Performance Analysis

For each campaign, compute:
- Open rate = opens / sent
- Reply rate = replies / sent
- Bounce rate = bounces / sent
- Unsubscribe rate = unsubscribes / sent

Flag campaigns exceeding warning or critical thresholds. Mark each metric as OK / WARNING / CRITICAL.

## Phase 3: Account Health

1. Use `list_accounts` to get all sending accounts
2. For each active account, use `get_account` to check status
3. Use `get_warmup_analytics` to check warmup progress
4. Flag:
   - Accounts with incomplete warmup (< 90%)
   - Accounts with declining deliverability
   - Paused or disabled accounts

## Phase 4: Lead List Quality

1. Use `list_lead_lists` to get all lists
2. For lists actively used by campaigns, use `get_verification_stats_for_lead_list`
3. Flag lists with:
   - Invalid email rate > 5%
   - Risky email rate > 10%
   - Unverified lists being used in active campaigns

## Phase 5: Trend Analysis

For the top 3 campaigns (by send volume), use `get_daily_campaign_analytics` to pull 7-day daily data. Show trend direction:
- Opens: trending UP / FLAT / DOWN
- Replies: trending UP / FLAT / DOWN
- Calculate trend by comparing last 3 days average to prior 4 days average

## Phase 6: Optimization Suggestions

Generate rule-based recommendations based on findings:

**Low open rate (< 20%):**
- Test different subject lines (A/B test with 20% of list)
- Optimize send time (check when opens peak)
- Check sender reputation and warmup status
- Review "from" name — personal name outperforms company name

**Low reply rate (< 2%):**
- Shorten email body (aim for < 100 words)
- Strengthen the CTA — one clear ask, not multiple
- Add personalization (first name, company name, recent trigger)
- Check if the offer/value prop is clear in first 2 sentences

**High bounce rate (> 5%):**
- Run email verification on the lead list before next send
- Remove addresses that bounced twice
- Check if the domain is on any blacklists
- Review list source — purchased lists have higher bounce rates

**High unsubscribe rate (> 1%):**
- Reduce send frequency
- Improve targeting — are you reaching the right audience?
- Review email content relevance to the segment
- Check if unsubscribe link is functioning properly

## Output Format

```
==================================================================
CAMPAIGN ANALYTICS DASHBOARD
Generated: [Date]
==================================================================

## Active Campaigns

| Campaign | Sent | Open% | Reply% | Bounce% | Unsub% | Status |
|----------|------|-------|--------|---------|--------|--------|
| Q1 Outreach | 1,240 | 34.2% | 4.1% | 1.2% | 0.2% | OK |
| Partner Push | 580 | 12.4% | 0.8% | 8.3% | 1.5% | CRITICAL |

## Flagged Issues

CRITICAL: "Partner Push" — open rate 12.4% (threshold: 20%)
CRITICAL: "Partner Push" — bounce rate 8.3% (threshold: 5%)
CRITICAL: "Partner Push" — unsubscribe rate 1.5% (threshold: 1%)

## Account Health

| Account | Status | Warmup | Notes |
|---------|--------|--------|-------|
| outreach@pulse.co | Active | 95% | Good |
| info@pulse.co | Active | 62% | Still warming up |

## Lead List Quality

| List | Total | Verified | Invalid% | Risky% |
|------|-------|----------|----------|--------|
| Q1 Prospects | 2,400 | Yes | 2.1% | 4.3% |
| Partner Leads | 800 | No | — | — |

WARNING: "Partner Leads" is unverified — verify before sending

## 7-Day Trends

Q1 Outreach: Opens UP (+2.1%), Replies FLAT
Partner Push: Opens DOWN (-5.3%), Replies DOWN (-1.2%)

## Optimization Recommendations

1. **Partner Push (CRITICAL):** Pause campaign. Bounce rate of 8.3%
   suggests a list quality issue. Run verification on the lead list
   before resuming. Subject line A/B test recommended for low open rate.

2. **info@pulse.co:** Warmup at 62%. Avoid increasing send volume
   until warmup reaches 90%+.

==================================================================
```

## Important Rules

- Never modify campaigns, accounts, or lists — this is a read-only analytics tool
- Always show all active campaigns, even if performing well
- Flag issues in order of severity: CRITICAL → WARNING → OK
- Percentages should be formatted to one decimal place
- If a campaign has < 50 sends, note "insufficient data" instead of flagging metrics
- Sort campaigns by send volume descending
