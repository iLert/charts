# iLert Helm Charts

## Get Repo Info

```console
helm repo add ilert https://ilert.github.io/charts/
helm repo update
```

## Charts

| Chart | Description |
| --- | --- |
| [`ilert-kube-agent`](charts/ilert-kube-agent) | Kubernetes monitoring agent — cluster/node/pod alarms into ilert. |
| [`obi`](charts/obi) | OpenTelemetry eBPF Instrumentation — zero-code tracing for Service Health. |
| [`otel-collector`](charts/otel-collector) | Official OpenTelemetry Collector, pre-configured as an ilert OTLP gateway. |
| [`alloy`](charts/alloy) | Grafana Alloy as an ilert OTLP gateway (alternative to `otel-collector`). |

### OpenTelemetry Service Health quick-start

The `obi`, `otel-collector`, and `alloy` charts work together to light up the
ilert **Service Health** page with **no application changes**: OBI instruments
your workloads from the kernel via eBPF and emits OTLP traces; a collector
(`otel-collector` or `alloy`) batches them and forwards them to ilert.

See [`samples/otel-service-health`](samples/otel-service-health) for a complete,
copy-paste deployment.

## Getting help

We are happy to respond to [GitHub issues][issues] as well.

[issues]: https://github.com/iLert/charts/issues/new

<br>

#### License

<sup>
Licensed under <a href="LICENSE">Apache License, Version
2.0</a>
</sup>

<br>

<sub>
Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in charts by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
</sub>
