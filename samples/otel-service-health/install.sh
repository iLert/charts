#!/usr/bin/env bash
# Quick-start installer for the ilert OpenTelemetry Service Health setup.
#
# Deploys a collector (OTLP gateway) + OBI (zero-code eBPF instrumentation) into
# one namespace. Within a few minutes your services appear on the ilert Service
# Health page.
#
# Usage:
#   ILERT_OTLP_TOKEN='<your-ingest-token>' ./install.sh
#
# Optional environment overrides:
#   NAMESPACE       target namespace              (default: ilert-otel)
#   COLLECTOR       otel-collector | alloy        (default: otel-collector)
#   INSTRUMENT_NS   namespace OBI instruments     (default: default)
#   ILERT_ENDPOINT  OTLP ingest endpoint          (default: https://otlp.ilert.com:4318)
set -euo pipefail

NAMESPACE="${NAMESPACE:-ilert-otel}"
COLLECTOR="${COLLECTOR:-otel-collector}"
INSTRUMENT_NS="${INSTRUMENT_NS:-default}"
ILERT_ENDPOINT="${ILERT_ENDPOINT:-https://otlp.ilert.com:4318}"

if [[ -z "${ILERT_OTLP_TOKEN:-}" ]]; then
  echo "ERROR: set ILERT_OTLP_TOKEN to your ilert OTLP ingest token." >&2
  echo "       Create one in the ilert UI, then re-run:" >&2
  echo "       ILERT_OTLP_TOKEN='<token>' ./install.sh" >&2
  exit 1
fi

if [[ "${COLLECTOR}" != "otel-collector" && "${COLLECTOR}" != "alloy" ]]; then
  echo "ERROR: COLLECTOR must be 'otel-collector' or 'alloy' (got '${COLLECTOR}')." >&2
  exit 1
fi

echo "==> Adding ilert Helm repo"
helm repo add ilert https://ilert.github.io/charts/ >/dev/null 2>&1 || true
helm repo update ilert >/dev/null

echo "==> Ensuring namespace ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Creating/updating ilert OTLP token Secret"
kubectl -n "${NAMESPACE}" create secret generic ilert-otlp \
  --from-literal=token="${ILERT_OTLP_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installing collector: ${COLLECTOR}"
helm upgrade --install "${COLLECTOR}" "ilert/${COLLECTOR}" \
  --namespace "${NAMESPACE}" \
  --set ilert.endpoint="${ILERT_ENDPOINT}" \
  --set ilert.existingSecret=ilert-otlp \
  --set ilert.existingSecretKey=token \
  --wait

echo "==> Installing OBI (instrumenting namespace: ${INSTRUMENT_NS})"
helm upgrade --install obi ilert/obi \
  --namespace "${NAMESPACE}" \
  --set otlpEndpoint="http://${COLLECTOR}:4318" \
  --set "discovery.instrument[0].k8sNamespace=${INSTRUMENT_NS}" \
  --set "discovery.excludeInstrument[0].k8sPodName=${COLLECTOR}-*" \
  --set "discovery.excludeInstrument[1].k8sPodName=obi-*"

cat <<EOF

Done. Verify:
  kubectl -n ${NAMESPACE} get pods
  kubectl -n ${NAMESPACE} logs -l app=${COLLECTOR} --tail=50

Generate some traffic in namespace '${INSTRUMENT_NS}', then open the ilert
Service Health page — your services and their dependencies appear within a
few minutes.
EOF
