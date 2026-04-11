{{/*
Expand the name of the chart.
*/}}
{{- define "webapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "webapp.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "webapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "webapp.labels" -}}
helm.sh/chart: {{ include "webapp.chart" . }}
{{ include "webapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels (base)
*/}}
{{- define "webapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "webapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
PHP selector labels
*/}}
{{- define "webapp.php.selectorLabels" -}}
{{ include "webapp.selectorLabels" . }}
app.kubernetes.io/component: php
{{- end }}

{{/*
PHP labels (full)
*/}}
{{- define "webapp.php.labels" -}}
{{ include "webapp.labels" . }}
app.kubernetes.io/component: php
{{- end }}

{{/*
Node.js selector labels
*/}}
{{- define "webapp.nodejs.selectorLabels" -}}
{{ include "webapp.selectorLabels" . }}
app.kubernetes.io/component: nodejs
{{- end }}

{{/*
Node.js labels (full)
*/}}
{{- define "webapp.nodejs.labels" -}}
{{ include "webapp.labels" . }}
app.kubernetes.io/component: nodejs
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "webapp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "webapp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the proper PHP image name
*/}}
{{- define "webapp.php.image" -}}
{{- $repo := .Values.php.image.repository -}}
{{- $tag := .Values.php.image.tag | toString -}}
{{- if .Values.php.image.registry -}}
{{- printf "%s/%s:%s" .Values.php.image.registry $repo $tag -}}
{{- else -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}
{{- end }}

{{/*
Return the proper Node.js image name
*/}}
{{- define "webapp.nodejs.image" -}}
{{- $repo := .Values.nodejs.image.repository -}}
{{- $tag := .Values.nodejs.image.tag | toString -}}
{{- if .Values.nodejs.image.registry -}}
{{- printf "%s/%s:%s" .Values.nodejs.image.registry $repo $tag -}}
{{- else -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}
{{- end }}

{{/*
Return PHP image pull policy
*/}}
{{- define "webapp.php.imagePullPolicy" -}}
{{- .Values.php.image.pullPolicy | default "IfNotPresent" -}}
{{- end }}

{{/*
Return Node.js image pull policy
*/}}
{{- define "webapp.nodejs.imagePullPolicy" -}}
{{- .Values.nodejs.image.pullPolicy | default "IfNotPresent" -}}
{{- end }}

{{/*
Container security context with safe defaults
*/}}
{{- define "webapp.containerSecurityContext" -}}
runAsNonRoot: true
runAsUser: 1000
allowPrivilegeEscalation: false
capabilities:
  drop:
    - ALL
readOnlyRootFilesystem: false
{{- end }}

{{/*
Nginx container security context
*/}}
{{- define "webapp.nginx.securityContext" -}}
runAsNonRoot: true
runAsUser: 101
allowPrivilegeEscalation: false
capabilities:
  drop:
    - ALL
  add:
    - NET_BIND_SERVICE
{{- end }}

{{/*
Database environment variables – injected into PHP and Node containers
when a database sub-chart is enabled.
*/}}
{{- define "webapp.databaseEnvVars" -}}
{{- if .Values.postgresql.enabled }}
- name: DB_CONNECTION
  value: "pgsql"
- name: DB_HOST
  value: {{ printf "%s-postgresql" .Release.Name | quote }}
- name: DB_PORT
  value: "5432"
- name: DB_DATABASE
  value: {{ .Values.postgresql.auth.database | quote }}
- name: DB_USERNAME
  value: {{ .Values.postgresql.auth.username | quote }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-postgresql" .Release.Name }}
      key: password
{{- else if .Values.mariadb.enabled }}
- name: DB_CONNECTION
  value: "mysql"
- name: DB_HOST
  value: {{ printf "%s-mariadb" .Release.Name | quote }}
- name: DB_PORT
  value: "3306"
- name: DB_DATABASE
  value: {{ .Values.mariadb.auth.database | quote }}
- name: DB_USERNAME
  value: {{ .Values.mariadb.auth.username | quote }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-mariadb" .Release.Name }}
      key: mariadb-password
{{- end }}
{{- end }}
