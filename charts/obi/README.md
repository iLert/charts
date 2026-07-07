# obi — OpenTelemetry eBPF Instrumentation for ilert

Deploys [OBI (OpenTelemetry eBPF Instrumentation)](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation)
as a DaemonSet. OBI watches your workloads from the Linux kernel with eBPF and
emits OTLP traces **without any code changes, sidecars, or redeploys**. Those
traces are what ilert turns into the **Service Health** topology — the map of
which service calls which, and how healthy those calls are.

This is one of three charts that make up the ilert OpenTelemetry quick-start:

| Chart | Role |
| --- | --- |
| **obi** (this chart) | Zero-code eBPF instrumentation → produces OTLP traces |
| [`otel-collector`](../otel-collector) | Receives OTLP, batches it, forwards to ilert (recommended collector) |
| [`alloy`](../alloy) | Grafana Alloy — the same collector role, alternative to `otel-collector` |

See [`samples/otel-service-health`](../../samples/otel-service-health) for a
complete, copy-paste deployment.

## How it fits together

```
┌──────────────────────────────┐
│  your pods (unchanged)       │
│  ┌────────┐   ┌────────┐     │
│  │ svc A  │──▶│ svc B  │─┐   │
│  └────────┘   └────────┘ │   │
└──────────│───────────────│───┘
           │ eBPF (kernel) │
     ┌─────▼───────────────▼─────┐
     │  OBI DaemonSet (per node) │  emits OTLP traces
     └─────────────┬─────────────┘
                   │ OTLP  (otlpEndpoint)
          ┌────────▼─────────┐
          │ otel-collector / │  batches + adds ilert token
          │ alloy            │
          └────────┬─────────┘
                   │ OTLP/HTTPS  Bearer <ingest token>
          ┌────────▼─────────┐
          │ otlp.ilert.com   │  ilert OTLP gateway → Service Health
          └──────────────────┘
```

OBI does **not** talk to ilert directly. It sends to an in-cluster collector so
that batching, retries, and the ingest credential all live in one place. That is
why `otlpEndpoint` defaults to a collector Service, not to ilert.

## Install

```console
helm repo add ilert https://ilert.github.io/charts/
helm repo update

# Install alongside a collector (see the otel-collector chart first).
helm install obi ilert/obi \
  --namespace ilert-otel --create-namespace \
  --set otlpEndpoint=http://otel-collector:4318 \
  --set 'discovery.instrument[0].k8sNamespace=default'
```

## What to configure

The one setting you must get right is **`discovery.instrument`** — it decides
which processes OBI instruments. If it is empty, OBI instruments nothing and
Service Health stays empty.

```yaml
discovery:
  instrument:
    - k8sNamespace: default        # instrument everything in "default"
    - k8sNamespace: shop
      k8sDeploymentName: checkout  # or narrow to one workload
  excludeInstrument:
    - k8sPodName: "otel-collector-*"  # don't trace the collector itself
    - k8sPodName: "alloy-*"
```

Selector fields (all optional, combine freely, globs allowed):
`k8sNamespace`, `k8sPodName`, `k8sDeploymentName`, `openPorts`, `exePath`.

## Key values

| Key | Default | Why |
| --- | --- | --- |
| `otlpEndpoint` | `http://otel-collector:4318` | Where OBI ships OTLP. Point at your collector Service. Use `:4317` for gRPC. |
| `discovery.instrument` | `[{k8sNamespace: default}]` | Processes to instrument. **Empty = no data.** |
| `discovery.excludeInstrument` | `[]` | Selectors to skip; exclude your collector/agents here. |
| `tracesInstrumentations` | `http, grpc, sql, redis, kafka` | Protocols decoded into spans. Keep `http`/`grpc` for topology; add DBs/brokers to see them as dependencies. |
| `kubeClusterName` | `""` | Stamps `k8s.cluster.name` on spans. Set it when you run multiple clusters. |
| `nameResolverSources` | `k8s, rdns` | How peer IPs become readable names. `rdns` names external peers (RDS, ElastiCache) by hostname. |
| `securityContext.privileged` | `false` | Least-privilege eBPF via fine-grained capabilities. Only enable if your kernel/hardening blocks it. |
| `resources` | 100m/128Mi → 500m/512Mi | Per-node request/limit. |

Run `helm show values ilert/obi` for the fully commented list.

## Requirements & notes

- **Linux kernel ≥ 5.8** with eBPF enabled (any recent EKS/GKE/AKS node qualifies).
- OBI needs elevated privileges to load eBPF programs. The default uses specific
  Linux capabilities (`BPF`, `PERFMON`, `SYS_PTRACE`, …) rather than full
  `privileged`. It also uses `hostPID: true` to see processes across the node.
- OBI runs on **every** node (tolerates all taints by default). Narrow with
  `nodeSelector`/`tolerations` to target specific node pools.

## Verify

```console
kubectl -n ilert-otel get pods -l app=obi
kubectl -n ilert-otel logs -l app=obi --tail=50
```

Then open **Service Health** in ilert — your services and their dependencies
appear within a few minutes of receiving traffic.
