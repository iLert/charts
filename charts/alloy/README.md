# alloy — ilert OTLP gateway (Grafana Alloy)

Deploys [Grafana Alloy](https://grafana.com/docs/alloy/latest/) pre-configured as
an **ilert OTLP gateway**. It receives OTLP from [OBI](../obi) and your
application SDKs, batches it, and forwards traces to the ilert OTLP ingest
endpoint — which builds your **Service Health** topology.

This chart is **functionally interchangeable** with [`otel-collector`](../otel-collector);
they play the same role. Pick `alloy` if your team already standardizes on
Grafana Alloy, otherwise the `otel-collector` chart is the recommended default.
See [`samples/otel-service-health`](../../samples/otel-service-health) for a full
deployment.

## Why a collector in the middle?

OBI and your apps could send to ilert directly, but a gateway gives you:

- **Batching** — fewer, larger requests to ilert.
- **Resilience** — a memory limiter in front of the network hop.
- **One credential** — the ilert ingest token lives in a single Secret here.

It runs as a **Deployment + Service** (a gateway), not a DaemonSet: it only
forwards data, so a couple of replicas serve the whole cluster.

## Install

```console
helm repo add ilert https://ilert.github.io/charts/
helm repo update

helm install alloy ilert/alloy \
  --namespace ilert-otel --create-namespace \
  --set ilert.token='<YOUR-ILERT-OTLP-INGEST-TOKEN>'
```

> Point OBI at this gateway with `--set otlpEndpoint=http://alloy:4318`.

### Get your ingest token

Create an **OTLP ingest token** in the ilert UI. ilert reads your tenant from the
token. Prefer keeping it out of `values.yaml`:

```console
kubectl -n ilert-otel create secret generic ilert-otlp \
  --from-literal=token='<YOUR-ILERT-OTLP-INGEST-TOKEN>'

helm install alloy ilert/alloy \
  --namespace ilert-otel \
  --set ilert.existingSecret=ilert-otlp
```

## Key values

| Key | Default | Why |
| --- | --- | --- |
| `ilert.endpoint` | `https://otlp.ilert.com:4318` | ilert's public OTLP gateway. Alloy appends `/v1/traces`. |
| `ilert.token` | `""` | **Required** unless `existingSecret` is set. |
| `ilert.existingSecret` / `existingSecretKey` | `""` / `token` | Reference a pre-made Secret instead of putting the token in values. |
| `replicaCount` | `2` | Two replicas so a rollout/node loss never drops the ingest path. |
| `ports.otlpHttp` / `ports.otlpGrpc` | `4318` / `4317` | Ports OBI and apps connect to. |
| `ports.http` | `12345` | Alloy's own HTTP UI + health endpoint. |
| `config.batch` | `5s`, `8192` | Batching window/size. |
| `config.memoryLimiter` | `80% / 25%` | OOM guard under trace bursts. |
| `configOverride` | `""` | Replace the **entire** generated Alloy config with your own (`config.alloy` syntax). |
| `autoscaling.enabled` | `false` | Turn on CPU-based HPA. |

Run `helm show values ilert/alloy` for the fully commented list.

## What the generated config does

```
otelcol.receiver.otlp   (grpc :4317 + http :4318)   ← OBI and app SDKs
  → otelcol.processor.memory_limiter
  → otelcol.processor.batch
  → otelcol.exporter.otlphttp "ilert"  (Bearer token) → https://otlp.ilert.com:4318
```

Only **traces** are wired, because Service Health topology is derived from spans.
To ship metrics/logs elsewhere, supply your own config via `configOverride` and
reference the token with `sys.env("ILERT_OTLP_TOKEN")`.

## Verify

```console
kubectl -n ilert-otel get pods -l app=alloy
kubectl -n ilert-otel logs -l app=alloy --tail=50

# Alloy's built-in UI shows the live component graph and any export errors:
kubectl -n ilert-otel port-forward svc/alloy 12345:12345
# open http://localhost:12345
```
