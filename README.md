# Xplorr Helm charts

```bash
helm repo add xplorr https://charts.xplorr.io
helm repo update
```

| Chart | What it does |
|---|---|
| [`xplorr`](charts/xplorr) | Connects a Kubernetes cluster to [Xplorr](https://xplorr.io). Installs OpenCost, tells it which cluster it is looking at, and installs the collector that sends cost out. |

## Connecting a cluster

```bash
helm upgrade --install xplorr xplorr/xplorr \
  --namespace xplorr --create-namespace \
  --set clusterName=prod-eks \
  --set xplorr.clusterId=<cluster id from the console> \
  --set xplorr.ingestToken=<token from the console>
```

Get the cluster id and the token from the Xplorr console, under **Kubernetes**,
your cluster, **Collector**. The token is shown once.

Full values, the bring-your-own-OpenCost path and what actually runs in your
cluster: [`charts/xplorr/README.md`](charts/xplorr/README.md).

Docs: <https://docs.xplorr.io/guides/connect-kubernetes/>

## Adding a chart here

Put it in `charts/<name>/`. The release workflow publishes any chart whose
version in `Chart.yaml` is one it has not seen, and ignores the rest, so a
change that does not bump a version publishes nothing.

## License

Apache 2.0.
