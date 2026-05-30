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
Name of the root-level app config ConfigMap.
*/}}
{{- define "webapp.configMapName" -}}
{{- printf "%s-config" (include "webapp.fullname" .) }}
{{- end }}

{{/*
Name of the PHP-FPM config ConfigMap.
*/}}
{{- define "webapp.php.configMapName" -}}
{{- printf "%s-php-fpm" (include "webapp.fullname" .) }}
{{- end }}

{{/*
Name of the synthetic /etc/passwd ConfigMap. Used by git-clone/app-build
init containers so OpenSSH's getpwuid() lookup for the runtime UID
succeeds (alpine/git's /etc/passwd doesn't have UID 33).
*/}}
{{- define "webapp.passwdConfigMapName" -}}
{{- printf "%s-passwd" (include "webapp.fullname" .) }}
{{- end }}

{{/*
Return the proper PHP image name
*/}}
{{- define "webapp.php.image" -}}
{{- $repo := required "php.image.repository is required when php.enabled=true" .Values.php.image.repository -}}
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
{{- $repo := required "nodejs.image.repository is required when nodejs.enabled=true" .Values.nodejs.image.repository -}}
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
Nginx container security context.
*/}}
{{- define "webapp.nginx.securityContext" -}}
runAsNonRoot: true
runAsUser: 101
runAsGroup: 101
allowPrivilegeEscalation: false
capabilities:
  drop:
    - ALL
  add:
    - NET_BIND_SERVICE
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{/*
Database environment variables — injected into PHP and Node containers
when a database sub-chart is enabled. Honors auth.existingSecret.
*/}}
{{- define "webapp.databaseEnvVars" -}}
{{- $m := .Values.database.envMapping -}}
{{- if .Values.postgresql.enabled }}
{{- $secretName := default (printf "%s-postgresql" .Release.Name) .Values.postgresql.auth.existingSecret }}
{{- $passwordKey := .Values.postgresql.auth.secretKeys.userPasswordKey | default "password" }}
- name: {{ $m.connection }}
  value: "pgsql"
- name: {{ $m.host }}
  value: {{ printf "%s-postgresql" .Release.Name | quote }}
- name: {{ $m.port }}
  value: "5432"
- name: {{ $m.database }}
  value: {{ .Values.postgresql.auth.database | quote }}
- name: {{ $m.username }}
  value: {{ .Values.postgresql.auth.username | quote }}
- name: {{ $m.password }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ $passwordKey }}
{{- else if .Values.mariadb.enabled }}
{{- $secretName := default (printf "%s-mariadb" .Release.Name) .Values.mariadb.auth.existingSecret }}
{{- $passwordKey := .Values.mariadb.auth.secretKeys.userPasswordKey | default "mariadb-password" }}
- name: {{ $m.connection }}
  value: "mysql"
- name: {{ $m.host }}
  value: {{ printf "%s-mariadb" .Release.Name | quote }}
- name: {{ $m.port }}
  value: "3306"
- name: {{ $m.database }}
  value: {{ .Values.mariadb.auth.database | quote }}
- name: {{ $m.username }}
  value: {{ .Values.mariadb.auth.username | quote }}
- name: {{ $m.password }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ $passwordKey }}
{{- end }}
{{- end }}

{{/*
envFrom snippet for PHP. Auto-includes the root app ConfigMap when
.Values.config is set, plus any user-supplied php.envFrom entries.
*/}}
{{- define "webapp.php.envFrom" -}}
{{- if .Values.config }}
- configMapRef:
    name: {{ include "webapp.configMapName" . }}
{{- end }}
{{- with .Values.php.envFrom }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
envFrom snippet for Node.js.
*/}}
{{- define "webapp.nodejs.envFrom" -}}
{{- if .Values.config }}
- configMapRef:
    name: {{ include "webapp.configMapName" . }}
{{- end }}
{{- with .Values.nodejs.envFrom }}
{{- toYaml . }}
{{- end }}
{{- end }}