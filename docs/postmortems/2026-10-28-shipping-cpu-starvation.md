# Postmortem: Shipping starved of CPU, 7% of shop requests failed

> Blameless: we describe what the system and process allowed to happen, not who to blame.

| | |
|---|---|
| **Date** | 2026-10-28 |
| **Authors** | Peter O. Ajiboye |
| **Status** | Reviewed |
| **Severity** | SEV2 (shipping and checkout broken, browsing worked) |
| **Duration** | Started ~13:05, detected 13:33, mitigated 13:39, resolved 13:47 (UTC+1) |
| **Error budget burned** | Large share of the 30-day budget (7% errors vs 1% allowed while it lasted) |

## Summary
About 25 minutes after Robot Shop was deployed, the `shipping` service stopped answering requests. It was limited to 0.2 CPU cores, and under steady load-gen traffic its Java threads were starved. Its health check timed out, Kubernetes marked it NotReady, and `web` returned 502 for every `/api/shipping/*` request, about 7% of all shop traffic. The SLO alert fired in Slack, the dashboard and Prometheus pointed to `/api/shipping/codes`, and raising the CPU limit restored service.

## Impact
- Customers could browse and add to cart, but could not get shipping quotes or check out.
- Peak error ratio at `web`: **7.16%** (SLO allows 1%).
- The failure was silent for about 25 minutes because monitoring was being installed at the time.

## Timeline (UTC+1)
| Time | Event |
|---|---|
| 12:55 | Robot Shop installed with the upstream Helm chart (shipping CPU limit 200m) |
| ~13:05 | Shipping logs `HikariPool-1 - Thread starvation or clock leap detected (housekeeper delta=1m6s)`. Readiness probe starts timing out. Pod becomes NotReady. |
| 13:30 | Monitoring stack installed. Dashboard shows availability 92.8%, error ratio 7.2%, errors only on `web` |
| 13:33 | `RobotShopAvailabilitySLOBurn` fires in Slack with runbook link |
| 13:34 | Investigation starts. Prometheus query by route: all 5xx are `502` on `//api/shipping/codes` |
| 13:36 | `kubectl get pods`: `shipping` is `0/1 Running`, 0 restarts, age 41m |
| 13:37 | Logs and events: thread starvation, then `Readiness probe failed: context deadline exceeded` |
| 13:39 | **Mitigation:** `kubectl set resources deploy/shipping` to 1 CPU limit, 250m request; new pod ready |
| 13:47 | Error ratio back under 1%. Slack shows `[RESOLVED]` |
| 13:51 | Permanent fix committed to the Helm chart |

## Detection
- The SLO alert worked as designed: it fired within about 3 minutes of monitoring coming online and linked to the runbook.
- The 25-minute blind spot before that existed only because monitoring was installed after the app. In normal operation the alert would have fired within about 4 minutes of the failure.

## Root cause
The upstream chart gives `shipping` (Spring Boot on Java 8, heap up to 768 MB) a CPU **limit of 200m**. Java needs far more CPU than that for garbage collection and request threads under concurrent load. The container was CPU-throttled until threads stalled for over a minute, so `/health` could not answer within the probe's 1-second timeout. With no liveness probe, Kubernetes never restarted it; the readiness probe only removed it from the Service, so `web` (nginx) had no upstream and returned 502.

Contributing factors:
- Readiness probe timeout of 1 second, too tight for a throttled JVM.
- No liveness probe to restart a hung container.
- No per-service availability alert for services that Beyla does not instrument (shipping, user, ratings), so the dashboard showed the symptom at `web`, not the cause.

## Mitigation and resolution
- **Mitigation:** raised the CPU limit to 1 core and the request to 250m with `kubectl set resources`, which rolled out a healthy pod.
- **Resolution:** the same values are now in `K8s/helm/templates/shipping-deployment.yaml`, plus a 3-second readiness timeout and a liveness probe, so a reinstall cannot bring the bug back.

## What went well
- The alert fired, reached Slack, and linked to the runbook.
- Grouping web 5xx by `http_route` in Prometheus found the failing endpoint in one query.
- Following the runbook order (mitigate, then investigate) restored service quickly.

## What went wrong
- Default resource limits from the upstream chart were trusted without checking them against real load.
- The app ran unmonitored for its first 35 minutes.

## Where we got lucky
- It happened during setup, not during the instructor's drill or the demo.

## Action items
| Action | Type | Status |
|---|---|---|
| Raise shipping CPU limit and request in the Helm chart | prevent | Done |
| Add liveness probe and 3s readiness timeout to shipping | mitigate | Done |
| Install monitoring before (or together with) the application | detect | Done (install order documented) |
| Alert on pods NotReady for more than 5 minutes in `robot-shop` | detect | Open |
| Review CPU and memory limits of the other upstream services under load | prevent | Open |
| Raise load-gen memory limit from 200Mi to 512Mi (it was OOMKilled under 15 users) | prevent | Done |

## Evidence
- `screenshots/` Slack alert, dashboard at 7.16% errors, Prometheus query showing 502 on `//api/shipping/codes`, `kubectl get pods` with shipping `0/1`.
