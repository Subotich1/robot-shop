#!/usr/bin/env bash
# Removes everything this project installed. Run before `terraform destroy`
# so the Robot Shop load balancer and EBS volumes are cleaned up first.
set -uo pipefail
for r in beyla otel-collector fluent-bit loki kps; do helm uninstall "$r" -n monitoring 2>/dev/null; done
kubectl delete -f "$(dirname "$0")/../observability/manifests/jaeger.yaml" --ignore-not-found
helm uninstall robot-shop -n robot-shop 2>/dev/null
kubectl delete namespace robot-shop monitoring --ignore-not-found --wait=true
echo "Cleaned up. Wait about a minute for the load balancer to disappear, then run terraform destroy."
