{{/*
Expand the name of the chart.
*/}}
{{- define "alloy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "alloy.fullname" -}}
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

{{- define "alloy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "alloy.labels" -}}
helm.sh/chart: {{ include "alloy.chart" . }}
{{ include "alloy.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: ilert
{{- end }}

{{- define "alloy.selectorLabels" -}}
app: {{ include "alloy.name" . }}
app.kubernetes.io/name: {{ include "alloy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "alloy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "alloy.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "alloy.secretName" -}}
{{- if .Values.ilert.existingSecret }}
{{- .Values.ilert.existingSecret }}
{{- else }}
{{- printf "%s-ilert-token" (include "alloy.fullname" .) }}
{{- end }}
{{- end }}

{{- define "alloy.secretKey" -}}
{{- if .Values.ilert.existingSecret }}
{{- .Values.ilert.existingSecretKey }}
{{- else }}
{{- "token" }}
{{- end }}
{{- end }}
