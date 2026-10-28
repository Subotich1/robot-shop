# Robot Shop Availability SLO and Error Budget Policy

**Service:** Robot Shop (customer-facing web shop)  **Owner:** Peter O. Ajiboye  **Review:** monthly

## SLI: what we measure
**Availability** = share of HTTP requests to the `web` front end that do **not** return a 5xx status.

```
SLI = 1 - ( sum(rate(http_server_request_duration_seconds_count{service_name="web", http_response_status_code=~"5.."}[w]))
          / sum(rate(http_server_request_duration_seconds_count{service_name="web"}[w])) )
```

- Measured at `web` because every customer request passes through it (pages and `/api/*` calls).
- Source: Grafana Beyla (eBPF), scraped by Prometheus every 15s. No application code changes.
- 4xx responses are excluded: they are client mistakes, not shop failures.

## SLO: the target
**99% of requests succeed, measured over a rolling 30 days.**

## Error budget
1% of requests may fail. At the load-gen's steady rate of about 10 requests per second, that is roughly 260,000 failed requests a month, or about **7 hours 12 minutes** of total outage (30 days x 1%).

| Budget used | What it means |
|---|---|
| 0 to 50% | Healthy. Ship features normally. |
| 50 to 75% | Caution. Every release needs a tested rollback plan. |
| 75 to 100% | Risky. Only fixes and low-risk changes. |
| Above 100% | **Feature freeze** (see policy). |

## Alerting
| Alert | Condition | Severity | Goes to |
|---|---|---|---|
| `RobotShopAvailabilitySLOBurn` | 5m error ratio above 5% for 2 minutes (budget burning 5x too fast) | critical | Slack |
| `RobotShopErrorBudgetFastBurn` | 1h and 5m error ratio above 14.4% (2% of monthly budget per hour) | critical | Slack |
| `RobotShopErrorBudgetSlowBurn` | 6h and 30m error ratio above 6% (5% of monthly budget in 6 hours) | warning | Slack |
| `RobotShopNoTraffic` | No requests seen at web for 5 minutes | warning | Slack |

Every alert links to the [runbook](runbook.md). Rules live in [`observability/alerts/robot-shop-slo.yaml`](../observability/alerts/robot-shop-slo.yaml) and are unit-tested with `promtool`.

## Error budget policy
1. **While budget remains**, the team ships at normal pace.
2. **When the budget is exhausted** (SLI below 99% over 30 days):
   - Feature releases stop until the 30-day SLI is back above 99%.
   - Only reliability fixes, security patches and rollbacks are deployed.
   - Engineering time goes to the top causes of budget burn from recent postmortems.
3. **A single incident that burns more than 20% of the budget** gets a blameless postmortem within 5 working days, with action items tracked to completion.
4. **Planned maintenance** that causes errors counts against the budget. Schedule it when budget is healthy.
5. **Disagreements** about whether an incident should count against the budget go to the service owner, and the decision is written in the postmortem.
6. **Review** this SLO monthly. If it is always met with large margin, consider tightening it; if it is impossible to meet, fix reliability or revisit the target with stakeholders.
