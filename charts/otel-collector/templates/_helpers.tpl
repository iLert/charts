{{/*
Expand the name of the chart.
*/}}
{{- define "otel-collector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "otel-collector.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "otel-collector.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "otel-collector.labels" -}}
helm.sh/chart: {{ include "otel-collector.chart" . }}
{{ include "otel-collector.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: ilert
{{- end }}

{{- define "otel-collector.selectorLabels" -}}
app: {{ include "otel-collector.name" . }}
app.kubernetes.io/name: {{ include "otel-collector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "otel-collector.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "otel-collector.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the Secret holding the ilert OTLP token.
*/}}
{{- define "otel-collector.secretName" -}}
{{- if .Values.ilert.existingSecret }}
{{- .Values.ilert.existingSecret }}
{{- else }}
{{- printf "%s-ilert-token" (include "otel-collector.fullname" .) }}
{{- end }}
{{- end }}

{{- define "otel-collector.secretKey" -}}
{{- if .Values.ilert.existingSecret }}
{{- .Values.ilert.existingSecretKey }}
{{- else }}
{{- "token" }}
{{- end }}
{{- end }}
