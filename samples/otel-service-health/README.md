# Sample: ilert Service Health with OpenTelemetry

This sample stands up the full **zero-code** path to the ilert **Service Health**
page in a Kubernetes cluster — no application changes, no SDKs, no redeploys.

You deploy two things into one namespace:

1. A **collector** ([`otel-collector`](../../charts/otel-collector), or
   [`alloy`](../../charts/alloy)) — an in-cluster OTLP gateway that batches
   telemetry and forwards it to ilert with your ingest token.
2. **[OBI](../../charts/obi)** — an eBPF DaemonSet that watches your workloads
   from the kernel and emits OTLP traces for the calls they make.

```
┌────────────────────────────┐
│ your pods (unchanged)      │
│   svc A ──▶ svc B ──▶ db   │
└─────────│──────────────────┘
          │ eBPF (kernel)
   ┌──────▼───────┐
   │ OBI DaemonSet│  OTLP  ─▶  ┌───────────────┐  OTLP/HTTPS + Bearer  ┌─────────────────┐
   │ (per node)   │            │ collector     │ ─────────────────────▶│ otlp.ilert.com  │
   └──────────────┘            │ (gateway)     │                       │ → Service Health│
                               └───────────────┘                       └─────────────────┘
```

ilert derives the service **topology** from the traces (which service calls
which), so the graph appears with no dashboards to build.

## Prerequisites

- A Kubernetes cluster with **Linux kernel ≥ 5.8** nodes (any recent
  EKS/GKE/AKS qualifies) and `kubectl` + `helm` (v3) configured.
- An **ilert OTLP ingest token**. Create it in the ilert UI. ilert reads your
  tenant from the token, so no other tenant header is needed.

## Option A — one command

```console
ILERT_OTLP_TOKEN='<YOUR-ILERT-OTLP-INGEST-TOKEN>' ./install.sh
```

Useful overrides (environment variables):

| Var | Default | Meaning |
| --- | --- | --- |
| `NAMESPACE` | `ilert-otel` | Namespace the stack is installed into. |
| `COLLECTOR` | `otel-collector` | `otel-collector` or `alloy`. |
| `INSTRUMENT_NS` | `default` | Namespace whose workloads OBI instruments. |
| `ILERT_ENDPOINT` | `https://otlp.ilert.com:4318` | Your region's OTLP endpoint. |

Example — instrument the `shop` namespace using Alloy:

```console
ILERT_OTLP_TOKEN='...' COLLECTOR=alloy INSTRUMENT_NS=shop ./install.sh
```

## Option B — step by step with Helm

```console
helm repo add ilert https://ilert.github.io/charts/
helm repo update

# 1. Namespace
kubectl create namespace ilert-otel

# 2. Store the ingest token as a Secret (keeps it out of values files)
kubectl -n ilert-otel create secret generic ilert-otlp \
  --from-literal=token='<YOUR-ILERT-OTLP-INGEST-TOKEN>'

# 3. Collector (OTLP gateway). Keep the release name `otel-collector` so its
#    Service is reachable at http://otel-collector:4318.
helm install otel-collector ilert/otel-collector \
  -n ilert-otel -f values-otel-collector.yaml

# 4. OBI (zero-code instrumentation), pointing at the collector
helm install obi ilert/obi \
  -n ilert-otel -f values-obi.yaml
```

Prefer Grafana Alloy as the gateway? Swap step 3 for:

```console
helm install alloy ilert/alloy -n ilert-otel -f values-alloy.yaml
helm install obi ilert/obi -n ilert-otel -f values-obi.yaml \
  --set otlpEndpoint=http://alloy:4318
```

## Verify

```console
# Everything running?
kubectl -n ilert-otel get pods

# Collector forwarding without auth/connection errors?
kubectl -n ilert-otel logs -l app=otel-collector --tail=50   # or app=alloy

# OBI instrumenting and exporting?
kubectl -n ilert-otel logs -l app=obi --tail=50
```

Then generate some traffic in the instrumented namespace and open **Service
Health** in ilert. Your services and their dependencies appear within a few
minutes.

## Tuning what you see

- **Instrument the right namespaces.** Edit `discovery.instrument` in
  [`values-obi.yaml`](./values-obi.yaml) — this is the single most important
  setting. If it's empty, nothing appears.
- **See databases and brokers as dependencies.** Keep `sql`, `redis`, `kafka` in
  `tracesInstrumentations` (already set in the sample).
- **Distinguish multiple clusters.** Set `kubeClusterName` on the OBI chart.
- **Add app-level spans later.** OBI gives you the topology for free; for richer
  spans you can additionally point OpenTelemetry SDKs at the same collector
  Service (`http://otel-collector:4318`). Not required for Service Health.

## Uninstall

```console
helm uninstall obi otel-collector -n ilert-otel   # or: alloy instead of otel-collector
kubectl -n ilert-otel delete secret ilert-otlp
kubectl delete namespace ilert-otel
```
