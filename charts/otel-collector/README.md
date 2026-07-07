# otel-collector — ilert OTLP gateway

Deploys the official [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
(contrib distribution) pre-configured as an **ilert OTLP gateway**. It receives
OTLP from [OBI](../obi) and your application SDKs, batches it, and forwards
traces to the ilert OTLP ingest endpoint — which builds your **Service Health**
topology.

This is the recommended collector for the ilert OpenTelemetry quick-start. If you
already standardize on Grafana Alloy, the [`alloy`](../alloy) chart plays the same
role. See [`samples/otel-service-health`](../../samples/otel-service-health) for a
full deployment.

## Why a collector in the middle?

OBI and your apps could technically send to ilert directly, but a collector gives
you three things worth having:

- **Batching** — far fewer, larger requests to ilert instead of a flood of tiny ones.
- **Resilience** — a memory limiter and retry/queue behavior in front of the network hop.
- **One credential** — the ilert ingest token lives in a single Secret here,
  not sprinkled across every workload.

It runs as a **Deployment + Service** (a gateway), not a DaemonSet: it only
forwards data, so a couple of replicas serve the whole cluster and OBI gets one
stable address to send to.

## Install

```console
helm repo add ilert https://ilert.github.io/charts/
helm repo update

helm install otel-collector ilert/otel-collector \
  --namespace ilert-otel --create-namespace \
  --set ilert.token='<YOUR-ILERT-OTLP-INGEST-TOKEN>'
```

> Use the release name `otel-collector` so the Service is reachable at
> `http://otel-collector:4318` — the default OBI points at.

### Get your ingest token

Create an **OTLP ingest token** in the ilert UI. ilert reads your tenant from the
token, so no extra tenant header is required. Prefer keeping it out of `values.yaml`:

```console
kubectl -n ilert-otel create secret generic ilert-otlp \
  --from-literal=token='<YOUR-ILERT-OTLP-INGEST-TOKEN>'

helm install otel-collector ilert/otel-collector \
  --namespace ilert-otel \
  --set ilert.existingSecret=ilert-otlp
```

## Key values

| Key | Default | Why |
| --- | --- | --- |
| `ilert.endpoint` | `https://otlp.ilert.com:4318` | ilert's public OTLP gateway. The collector appends `/v1/traces`. |
| `ilert.token` | `""` | **Required** unless `existingSecret` is set. Your ilert OTLP ingest token. |
| `ilert.existingSecret` / `existingSecretKey` | `""` / `token` | Reference a pre-made Secret instead of putting the token in values (recommended). |
| `replicaCount` | `2` | Two replicas so a rollout/node loss never drops the ingest path. |
| `ports.otlpHttp` / `ports.otlpGrpc` | `4318` / `4317` | Ports OBI and apps connect to. |
| `config.batch` | `5s`, `8192` | Batching window/size. |
| `config.memoryLimiter` | `80% / 25%` | OOM guard under trace bursts. |
| `configOverride` | `{}` | Replace the **entire** generated collector config with your own. |
| `autoscaling.enabled` | `false` | Turn on CPU-based HPA for high volume. |

Run `helm show values ilert/otel-collector` for the fully commented list.

## What the generated config does

```
receivers:  otlp (grpc :4317 + http :4318)   ← OBI and app SDKs
processors: memory_limiter → batch
exporters:  otlphttp/ilert  (Bearer token)   → https://otlp.ilert.com:4318
service:    traces pipeline only
```

Only **traces** are forwarded, because Service Health topology is derived from
spans (client/producer calls). If you also want to send metrics or logs
elsewhere, add pipelines via `configOverride` — reference the token with
`${env:ILERT_OTLP_TOKEN}`.

## Verify

```console
kubectl -n ilert-otel get pods -l app=otel-collector
kubectl -n ilert-otel logs -l app=otel-collector --tail=50   # look for export errors
```

A quick smoke test from inside the cluster:

```console
kubectl -n ilert-otel run otlp-test --rm -it --image=curlimages/curl --restart=Never -- \
  curl -v http://otel-collector:4318/v1/traces -H 'Content-Type: application/json' -d '{}'
```
