#!/usr/bin/env bash
# Installs Robot Shop and the observability stack on the Capstone 1 EKS cluster.
#
# Usage:  ./scripts/install.sh <step>
#   shop     Robot Shop + load generator              (Capstone 2, Step 1)
#   metrics  Prometheus, Grafana, Alertmanager, Beyla,
#            dashboard and SLO alerts                 (Steps 2 and 5)
#   logs     Loki + Fluent Bit                        (Step 3)
#   traces   Jaeger + OpenTelemetry Collector         (Step 4)
#   all      everything, in order
#
# Needs: kubectl pointed at the cluster, helm, and for "metrics":
#   export SLACK_WEBHOOK_URL=...   (read it with: read -rs SLACK_WEBHOOK_URL; export SLACK_WEBHOOK_URL)
set -euo pipefail
cd "$(dirname "$0")/.."

# Pinned chart versions (reproducible installs)
KPS_VERSION=92.14.1
LOKI_VERSION=7.5.0
FLUENT_BIT_VERSION=0.58.3
OTEL_COLLECTOR_VERSION=0.178.0
BEYLA_VERSION=1.16.16

OBS=observability

repos() {
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo add fluent https://fluent.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null
}

ns() {
  for n in "$@"; do
    kubectl create namespace "$n" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  done
}

install_shop() {
  echo "==> Robot Shop"
  ns robot-shop
  helm upgrade --install robot-shop K8s/helm -n robot-shop --wait --timeout 10m
  kubectl -n robot-shop apply -f K8s/load-deployment.yaml
  kubectl -n robot-shop get pods
}

install_metrics() {
  echo "==> Prometheus, Alertmanager, Grafana"
  : "${SLACK_WEBHOOK_URL:?Set SLACK_WEBHOOK_URL first (see the usage notes at the top of this script)}"
  ns monitoring

  # Secrets are created here, from your shell, so they never touch Git
  kubectl -n monitoring create secret generic alertmanager-slack \
    --from-literal=url="$SLACK_WEBHOOK_URL" --dry-run=client -o yaml | kubectl apply -f -
  if ! kubectl -n monitoring get secret grafana-admin >/dev/null 2>&1; then
    pw="$(openssl rand -base64 18)"
    kubectl -n monitoring create secret generic grafana-admin \
      --from-literal=admin-user=admin --from-literal=admin-password="$pw"
    echo "Grafana login -> user: admin  password: $pw   (save it somewhere safe)"
  fi

  helm upgrade --install kps prometheus-community/kube-prometheus-stack --version "$KPS_VERSION" \
    -n monitoring -f "$OBS/values/kube-prometheus-stack.yaml" --wait --timeout 10m

  echo "==> SLO rules and dashboard"
  kubectl apply -f "$OBS/alerts/robot-shop-slo.yaml"
  kubectl -n monitoring create configmap robot-shop-dashboard \
    --from-file="$OBS/dashboards/robot-shop-red.json" --dry-run=client -o yaml \
    | kubectl label --local -f - grafana_dashboard=1 -o yaml \
    | kubectl apply -f -

  echo "==> Beyla (eBPF request, error and latency metrics; also sends payment traces)"
  helm upgrade --install beyla grafana/beyla --version "$BEYLA_VERSION" \
    -n monitoring -f "$OBS/values/beyla.yaml" --wait --timeout 5m
}

install_logs() {
  echo "==> Loki and Fluent Bit"
  ns monitoring
  helm upgrade --install loki grafana/loki --version "$LOKI_VERSION" \
    -n monitoring -f "$OBS/values/loki.yaml" --wait --timeout 10m
  helm upgrade --install fluent-bit fluent/fluent-bit --version "$FLUENT_BIT_VERSION" \
    -n monitoring -f "$OBS/values/fluent-bit.yaml" --wait --timeout 5m
}

install_traces() {
  echo "==> Jaeger and OpenTelemetry Collector"
  ns monitoring
  kubectl apply -f "$OBS/manifests/jaeger.yaml"
  helm upgrade --install otel-collector open-telemetry/opentelemetry-collector --version "$OTEL_COLLECTOR_VERSION" \
    -n monitoring -f "$OBS/values/otel-collector.yaml" --wait --timeout 5m
}

step="${1:-}"
case "$step" in
  shop)    install_shop ;;
  metrics) repos; install_metrics ;;
  logs)    repos; install_logs ;;
  traces)  repos; install_traces ;;
  all)     repos; install_shop; install_metrics; install_logs; install_traces ;;
  *) sed -n '2,15p' "$0"; exit 1 ;;
esac

echo
echo "Done. Open the UIs with port-forwards (then browse to localhost):"
echo "  Grafana:      kubectl -n monitoring port-forward svc/kps-grafana 3000:80"
echo "  Prometheus:   kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090"
echo "  Alertmanager: kubectl -n monitoring port-forward svc/kps-alertmanager 9093:9093"
echo "  Jaeger:       kubectl -n monitoring port-forward svc/jaeger 16686:16686"
echo "  Robot Shop:   kubectl -n robot-shop get svc web   (EXTERNAL-IP, port 8080)"
