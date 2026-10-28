# Incident Drill Rehearsal

Practise these before the instructor's drill. For each: break it, watch the alert, follow the [runbook](runbook.md), fix it, time yourself.

| # | Break it | What you should see | Fix |
|---|---|---|---|
| 1 | `kubectl -n robot-shop set env deploy/load ERROR=1` | payment 5xx climbs, web error ratio above 5%, Slack alert in about 3 to 5 min, `level=error` logs from payment | `kubectl -n robot-shop set env deploy/load ERROR=0` |
| 2 | `kubectl -n robot-shop scale deploy/catalogue --replicas=0` | catalogue requests fail at web, product pages break | `kubectl -n robot-shop scale deploy/catalogue --replicas=1` |
| 3 | `kubectl -n robot-shop scale deploy/mysql --replicas=0` | shipping and ratings errors; logs show connection refused | scale back to 1, then `rollout restart deploy/shipping deploy/ratings` |
| 4 | `kubectl -n robot-shop set image deploy/payment payment=robotshop/rs-payment:does-not-exist` | new pod in ImagePullBackOff; old pod keeps serving (no alert) | `kubectl -n robot-shop rollout undo deploy/payment` |
| 5 | `kubectl -n robot-shop scale deploy/load --replicas=0` | `RobotShopNoTraffic` after 5 min | scale back to 1 |

## During the real drill
1. **Acknowledge** in Slack: "Looking at it" and the time.
2. **Mitigate first** using the runbook table. Restoring service beats finding the cause.
3. **Then investigate:** dashboard (which service?), Loki (what error?), Jaeger (which call?), `kubectl get events`.
4. **Write the timeline as you go** (time + what you saw/did). It becomes the postmortem.
5. **Postmortem** from [the template](postmortem-template.md), blameless.

## Rehearsal log

### 2026-10-28: scenarios 1 and 2
| Time (UTC+1) | Event |
|---|---|
| 15:25 | Scenario 1: `load` set to `ERROR=1` (bad payment requests) |
| 15:25 to 15:36 | Web error ratio settles at **4.5 to 5%**. Alert goes `pending` briefly around 15:29 to 15:31 but never holds above 5% for 2 minutes, so **no page**. Correct: this is a minor, steady error rate, not an outage. |
| 15:34 | Scenario 1 reverted (`ERROR=0`). Scenario 2: `catalogue` scaled to 0 |
| 15:38 | `RobotShopAvailabilitySLOBurn` **fires in Slack** (error ratio climbing toward 40%) |
| ~15:44 | Mitigation per runbook: `catalogue` scaled back to 1 |
| ~15:49 | Alert **resolved** in Slack |

**Results**
- **Time to detect:** about 4 minutes from the break to Slack (5-minute rate window, 2-minute `for`, 30-second Alertmanager grouping).
- **Time to resolve:** about 5 minutes after mitigation. The 5-minute window has to clear the bad data before the alert resolves.
- **Alert precision:** it stayed quiet at 4 to 5% errors and fired on a 40% outage. No false page.

**Lessons**
- The alert is tuned for real outages, not low-level noise. Slow, steady burns are covered by `RobotShopErrorBudgetSlowBurn`.
- During an incident, the dashboard shows recovery before Slack does. Use the dashboard to confirm the fix worked; the RESOLVED message follows a few minutes later.
- Scenario 1 showed that `ERROR=1` alone is not strong enough to rehearse paging. Use scenario 2 or 3 to practise the full alert loop.
