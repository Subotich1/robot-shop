# Postmortem: <short title>

> Blameless: we describe what the system and process allowed to happen, not who to blame.

| | |
|---|---|
| **Date** | YYYY-MM-DD |
| **Authors** | Peter O. Ajiboye |
| **Status** | Draft / Reviewed / Action items complete |
| **Severity** | SEV1 (shop down) / SEV2 (major feature down) / SEV3 (degraded) |
| **Duration** | Detected HH:MM, mitigated HH:MM, resolved HH:MM (UTC+1) |
| **Error budget burned** | X% of the 30-day budget |

## Summary
Two or three sentences: what happened, who was affected, how it was fixed.

## Impact
- Customers affected and how (could not pay, pages slow, ...)
- Peak error ratio: X% (SLO allows 1%)
- Requests failed: approx. N

## Timeline (UTC+1)
| Time | Event |
|---|---|
| HH:MM | Change or fault begins |
| HH:MM | Alert `RobotShopAvailabilitySLOBurn` fires in Slack |
| HH:MM | Engineer acknowledges, opens dashboard |
| HH:MM | Mitigation applied: ... |
| HH:MM | Error ratio back under 1%, alert resolved |
| HH:MM | Root cause confirmed |

## Detection
How did we find out? Did the alert fire quickly enough? Did the runbook help?

## Root cause
What actually broke, and why. Use the evidence: dashboard screenshot, log query, trace.

## Mitigation and resolution
What stopped the bleeding, and what fixed it for good.

## What went well
-

## What went wrong
-

## Where we got lucky
-

## Action items
| Action | Type (prevent / detect / mitigate) | Owner | Due |
|---|---|---|---|
| | | | |

## Evidence
Screenshots: alert in Slack, dashboard during the incident, log query, trace.
