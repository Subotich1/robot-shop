# Robot Shop Runbook

Linked from every Robot Shop alert. **Mitigate first, investigate second.**

Quick access (run each in its own terminal, then open localhost in a browser):
```bash
kubectl -n monitoring port-forward svc/kps-grafana 3000:80          # dashboards + logs (Explore > Loki)
kubectl -n monitoring port-forward svc/jaeger 16686:16686           # traces
kubectl -n monitoring port-forward svc/kps-alertmanager 9093:9093   # active alerts, silences
```

---

## RobotShopAvailabilitySLO Burn
*Also used for `RobotShopErrorBudgetFastBurn` and `RobotShopErrorBudgetSlowBurn`.*

**What it means:** more than 5% of requests to the shop are failing with 5xx. Customers cannot browse, add to cart or pay.

### 1. Confirm (2 minutes)
- Grafana dashboard **Robot Shop: Requests, Errors, Latency**: is the "Error ratio now" stat red?
- **Error rate by service** panel: which service is failing? `web` errors usually come from a backend.

### 2. Mitigate (stop the bleeding)
| Likely cause | Check | Mitigation |
|---|---|---|
| A recent deploy | `helm history robot-shop -n robot-shop` | `helm rollback robot-shop <last-good-revision> -n robot-shop --wait` |
| Pod crashing or not ready | `kubectl -n robot-shop get pods` (look for CrashLoopBackOff, 0/1 READY) | `kubectl -n robot-shop rollout restart deploy/<service>` |
| Pod deleted or scaled to 0 | `kubectl -n robot-shop get deploy` (0/0 or 0/1) | `kubectl -n robot-shop scale deploy/<service> --replicas=1` |
| Data store down (mysql, mongodb, redis, rabbitmq) | `kubectl -n robot-shop get pods \| grep -E "mysql\|mongo\|redis\|rabbit"` | Restart it, then restart the services that depend on it |
| Bad requests flooding one service | Logs below; look for one repeated error | Scale or block the source; for load-gen: `kubectl -n robot-shop set env deploy/load ERROR=0` |

### 3. Find the root cause
- **Logs** (Grafana > Explore > Loki):
  `{namespace="robot-shop", level="error"}` then narrow to one service, e.g. `{namespace="robot-shop", service="payment", level="error"}`
- **Traces** (Jaeger, service `payment`): open a slow or red trace and see which call failed.
- **Events:** `kubectl -n robot-shop get events --sort-by=.lastTimestamp | tail -20`
- **Describe the failing pod:** `kubectl -n robot-shop describe pod <pod>`

### 4. Close out
- Confirm the error ratio is back under 1% and the alert shows **RESOLVED** in Slack.
- Note the time of detection, mitigation and resolution.
- Write a [blameless postmortem](postmortem-template.md) if the incident burned more than 20% of the error budget, or if it was the instructor's drill.

---

## RobotShopNoTraffic
**What it means:** Prometheus sees zero requests at `web`. Either the shop is down, the load generator stopped, or metrics collection broke.

1. Is the shop up? `kubectl -n robot-shop get pods,svc` and open the web EXTERNAL-IP on port 8080.
2. Is load-gen running? `kubectl -n robot-shop get deploy load`
3. Is Beyla running? `kubectl -n monitoring get pods -l app.kubernetes.io/name=beyla`
4. Is Prometheus scraping it? Prometheus UI > Status > Targets > search "beyla".
