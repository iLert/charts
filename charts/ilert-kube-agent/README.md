# ilert-kube-agent Helm Chart

Installs the [ilert-kube-agent](https://github.com/iLert/ilert-kube-agent).

## Get Repo Info

```console
helm repo add ilert https://ilert.github.io/charts/
helm repo update
```

_See [helm repo](https://helm.sh/docs/helm/helm_repo/) for command documentation._

## Install Chart

```console
$ helm install [RELEASE_NAME] ilert/ilert-kube-agent [flags]
```

_See [configuration](#configuration) below._

_See [helm install](https://helm.sh/docs/helm/helm_install/) for command documentation._

## Uninstall Chart

```console
$ helm uninstall [RELEASE_NAME]
```

This removes all the Kubernetes components associated with the chart and deletes the release.

_See [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) for command documentation._

## Upgrading Chart

```console
$ helm upgrade [RELEASE_NAME] ilert/ilert-kube-agent [flags]
```

_See [helm upgrade](https://helm.sh/docs/helm/helm_upgrade/) for command documentation._

## Configuration

See [Customizing the Chart Before Installing](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing). To see all configurable options with detailed comments:

```console
helm show values ilert/ilert-kube-agent
```

You may also `helm show values` on this chart's [dependencies](#dependencies) for additional options.
