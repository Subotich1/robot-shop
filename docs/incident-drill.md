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
