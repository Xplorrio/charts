{{/*
Names. Kept short because the collector is one CronJob and one Secret, and a
long release name would otherwise push the generated Job names past the 63
character limit.
*/}}
{{- define "xplorr.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "xplorr.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 40 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 40 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "xplorr.labels" -}}
app.kubernetes.io/name: {{ include "xplorr.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: xplorr
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
The Secret holding the ingest token: either one this chart creates, or one the
operator already manages.
*/}}
{{- define "xplorr.secretName" -}}
{{- if .Values.xplorr.existingSecret -}}
{{- .Values.xplorr.existingSecret -}}
{{- else -}}
{{- printf "%s-ingest-token" (include "xplorr.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Where the collector sends.

Built from the base URL and the cluster id rather than asked for whole,
because a customer copying a long URL by hand is how the wrong cluster id ends
up in it. xplorr.ingestUrl remains for a self-hosted Xplorr.
*/}}
{{- define "xplorr.ingestUrl" -}}
{{- if .Values.xplorr.ingestUrl -}}
{{- trimSuffix "/" .Values.xplorr.ingestUrl -}}
{{- else -}}
{{- printf "%s/%s" (trimSuffix "/" .Values.xplorr.ingestBaseUrl) .Values.xplorr.clusterId -}}
{{- end -}}
{{- end -}}

{{/*
Where OpenCost is.

When this chart installs OpenCost, the address is known and the operator is
not asked for it. When it does not, openCostUrl is required, because guessing
at a namespace is how a collector ends up sending nothing with no error.
*/}}
{{- define "xplorr.openCostUrl" -}}
{{- if .Values.installOpenCost -}}
{{- printf "http://opencost.%s.svc.cluster.local:9003" .Release.Namespace -}}
{{- else -}}
{{- required "openCostUrl is required when installOpenCost is false. Give the in-cluster address of your OpenCost API, for example http://opencost.opencost.svc.cluster.local:9003" .Values.openCostUrl | trimSuffix "/" -}}
{{- end -}}
{{- end -}}

{{/*
Refuses to install a second OpenCost over one that is already running.

`lookup` only sees a live cluster: `helm template` and `--dry-run` get an
empty result back and this check does not fire for them. That is deliberate,
not a gap. Its job is to stop a real `helm install` from standing up a
duplicate OpenCost, not to change what a preview shows, so a rendered
manifest stays an honest preview of the chart rather than of the cluster it
happens to run against.

Reusing what `lookup` finds automatically was rejected: a Service that
happens to be named opencost in a namespace this chart checks would then pick
which OpenCost the collector reads, with nothing in a rendered manifest or a
`helm diff` to show it. That is the CLUSTER_ID mistake again, one layer
further down, and unlike CLUSTER_ID there would be no console field to catch
it in later. Failing and naming the exact flags to rerun with keeps the
decision with whoever is running the install, the same way a missing
clusterId or ingestToken already does above, and costs one extra command
against a real conflict, which is rare, rather than a silent wrong OpenCost
against every install, which would not be.
*/}}
{{- define "xplorr.opencostConflictCheck" -}}
{{- if .Values.installOpenCost -}}
{{- $found := list -}}
{{- range $ns := .Values.opencostDetectNamespaces -}}
{{- if ne $ns $.Release.Namespace -}}
{{- if lookup "v1" "Service" $ns "opencost" -}}
{{- $found = append $found $ns -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $found -}}
{{- $ns := first $found -}}
{{- fail (printf "\n\nAn OpenCost Service already exists: %s (namespace %s).\n\ninstallOpenCost defaults to true, which would install a second one. Reuse the one that is already there instead:\n\n  --set installOpenCost=false --set openCostUrl=http://opencost.%s.svc.cluster.local:9003\n\nIf that Service is not actually OpenCost, rename it, or narrow opencostDetectNamespaces to skip it.\n" (join ", " $found) $ns $ns) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Everything the chart cannot run without, checked in one place so a missing
value is one readable sentence rather than a template error forty lines down.
*/}}
{{- define "xplorr.validate" -}}
{{- if not .Values.xplorr.clusterId -}}
{{- fail "\n\nxplorr.clusterId is not set.\n\nIt is the cluster id shown in the Xplorr console under Kubernetes, your cluster, Collector. Install with --set xplorr.clusterId=<id>.\n" -}}
{{- end -}}
{{- if and (not .Values.xplorr.ingestToken) (not .Values.xplorr.existingSecret) -}}
{{- fail "\n\nNo ingest token.\n\nGenerate one in the Xplorr console under Kubernetes, your cluster, Collector, then install with --set xplorr.ingestToken=xpk8s_...\n\nTo keep it out of values, put it in a Secret under the key `token` and set xplorr.existingSecret instead.\n" -}}
{{- end -}}
{{- if and .Values.xplorr.ingestToken .Values.xplorr.existingSecret -}}
{{- fail "\n\nBoth xplorr.ingestToken and xplorr.existingSecret are set, and they are alternatives. Keep whichever one holds the token you want used.\n" -}}
{{- end -}}
{{- if not .Values.clusterName -}}
{{- fail "\n\nclusterName is not set.\n\nIt is the name this cluster reports under, and it is given to OpenCost as its CLUSTER_ID. Install with --set clusterName=<name>.\n" -}}
{{- end -}}
{{- include "xplorr.opencostConflictCheck" . -}}
{{- end -}}
