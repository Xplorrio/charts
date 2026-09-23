# Xplorr for Kubernetes

One command to send a cluster's cost to [Xplorr](https://xplorr.io).

```bash
helm repo add xplorr https://charts.xplorr.io
helm repo update

helm upgrade --install xplorr xplorr/xplorr \
  --namespace xplorr --create-namespace \
  --set clusterName=prod-eks \
  --set xplorr.clusterId=<cluster id from the console> \
  --set xplorr.ingestToken=<token from the console>
```

That installs OpenCost, tells it which cluster it is looking at, and installs
the collector that sends the numbers to Xplorr. Nothing is exposed: the
collector makes an outbound HTTPS connection on a schedule, and no inbound
access, public endpoint or cloud credential is involved.

Get the cluster id and the token from the Xplorr console, under **Kubernetes**,
your cluster, **Collector**. The token is shown once.

## Why this exists

Onboarding used to be three things in a row, and the middle one was invisible:

1. install OpenCost yourself,
2. work out that its `CLUSTER_ID` has to be set to *this* cluster, not the one
   whose values file you copied,
3. apply the YAML the console gave you.

Step 2 has no error. A cluster whose OpenCost still reports `default-cluster`
looks like it is working and files its cost under the wrong name. This chart
takes `clusterName` once and gives it to both sides, so they cannot disagree.

## Already running OpenCost

```bash
helm upgrade --install xplorr xplorr/xplorr \
  --namespace xplorr --create-namespace \
  --set clusterName=prod-eks \
  --set xplorr.clusterId=<cluster id> \
  --set xplorr.ingestToken=<token> \
  --set installOpenCost=false \
  --set openCostUrl=http://opencost.opencost.svc.cluster.local:9003
```

Then check what your OpenCost calls this cluster, since this chart is no longer
setting it:

```bash
kubectl -n opencost get deploy opencost \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="CLUSTER_ID")].value}'
```

You do not have to know this up front. With `installOpenCost` left at its
default of `true`, a real `helm install` or `helm upgrade` checks for a
Service named `opencost` in `opencostDetectNamespaces` (`opencost`,
`monitoring`, `kube-system` by default) before doing anything, and refuses
the install if it finds one, naming the namespace and the exact flags above
to rerun with. It does not reuse what it finds automatically: a same-named
Service that is not actually your OpenCost would otherwise decide the
collector's behaviour with nothing in a rendered manifest to show it, the
same failure mode `clusterName` exists to prevent on the other side. Because
the check needs a real cluster to look at, `helm template` and `--dry-run`
never see it and always render as if nothing else is running; it only acts
on a real install.

The check is best effort. Helm's `lookup` returns nothing, rather than an
error, when the identity running `helm install` cannot read Services in those
namespaces, so an installer without that access gets a second OpenCost and
no warning. If you install with a namespace-scoped account, check for an
existing OpenCost yourself and set `installOpenCost=false` when there is one.

## Keeping the token out of values

The token in `--set` ends up in Helm's release Secret. To avoid that, put it in
a Secret under the key `token`:

```bash
kubectl -n xplorr create secret generic xplorr-ingest \
  --from-literal=token=xpk8s_...

helm upgrade --install xplorr xplorr/xplorr \
  --namespace xplorr --create-namespace \
  --set clusterName=prod-eks \
  --set xplorr.clusterId=<cluster id> \
  --set xplorr.existingSecret=xplorr-ingest
```

## First run

The collector runs hourly. To see data now rather than within the hour:

```bash
kubectl -n xplorr create job xplorr-first-run --from=cronjob/xplorr-collector
kubectl -n xplorr logs job/xplorr-first-run
```

A run that worked ends with `sent to Xplorr`. The console moves the cluster
from **Waiting for collector** to **Receiving**.

## Values

| Value | Default | |
|---|---|---|
| `clusterName` | | **Required.** The name this cluster reports under, and OpenCost's `CLUSTER_ID`. |
| `xplorr.clusterId` | | **Required.** The cluster id from the console. A UUID, not `clusterName`. |
| `xplorr.ingestToken` | | The token from the console. Required unless `xplorr.existingSecret` is set. |
| `xplorr.existingSecret` | | A Secret you manage, holding the token under the key `token`. |
| `xplorr.schedule` | `0 * * * *` | How often to send, in UTC. |
| `xplorr.window` | `3d` | How far back each run sends. Re-sending replaces days rather than adding to them. |
| `xplorr.ingestBaseUrl` | `https://ingest.xplorr.io/api/v1/kubernetes/ingest` | Where to send. Change it for a self-hosted Xplorr. |
| `xplorr.image.tag` | `8.22.0` | The `curlimages/curl` tag. Pinned on purpose. |
| `installOpenCost` | `true` | Set to `false` if you already run OpenCost. |
| `openCostUrl` | | Your OpenCost API, required when `installOpenCost` is `false`. |
| `opencostDetectNamespaces` | `[opencost, monitoring, kube-system]` | Namespaces a real install checks for an existing `opencost` Service before installing its own. Empty list skips the check. |
| `opencost.*` | | Passed to the [OpenCost chart](https://github.com/opencost/opencost-helm-chart) unchanged. |

## About the numbers

OpenCost prices at public on-demand rates until you give it your cloud pricing
details. Reserved instances, savings plans and spot will not be reflected until
you [configure that](https://www.opencost.io/docs/configuration/), and until
then the totals will read high.

Node and node pool cost comes from OpenCost's Assets API. An OpenCost too old
to serve it still reports namespace, controller and pod cost; Xplorr says so
rather than showing an empty page.

## What runs in your cluster

| | |
|---|---|
| `opencost` | the upstream OpenCost chart, unmodified |
| `xplorr-cluster-id` | a ConfigMap holding `CLUSTER_ID`, read by OpenCost |
| `xplorr-ingest-token` | a Secret holding the token, unless you brought your own |
| `xplorr-collector` | a CronJob running `curlimages/curl`, pinned |

The collector mounts no ServiceAccount token, runs as user 65534 with a
read-only root filesystem, drops every capability, and its whole job is two
curls: one to OpenCost, one to Xplorr. There is no Xplorr binary in it. Read
[`charts/xplorr/templates/cronjob.yaml`](charts/xplorr/templates/cronjob.yaml).

## Docs

<https://docs.xplorr.io/guides/connect-kubernetes/>

## License

Apache 2.0.
