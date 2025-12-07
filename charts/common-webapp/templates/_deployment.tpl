{{/*
Define a reusable deployment template
Usage in consuming charts:
{{- include "common-webapp.deployment" (dict "Chart" .Chart "Release" .Release "Values" .Values "containers" (list $mainContainer) "initContainers" (list) "volumes" (list)) }}
*/}}
{{- define "common-webapp.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common-webapp.fullname" . }}
  labels:
    {{- include "common-webapp.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "common-webapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        # Force rolling update on config changes
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
      labels:
        {{- include "common-webapp.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "common-webapp.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      {{- if .initContainers }}
      initContainers:
        {{- toYaml .initContainers | nindent 8 }}
      {{- end }}
      containers:
        {{- toYaml .containers | nindent 8 }}
      {{- if .volumes }}
      volumes:
        {{- toYaml .volumes | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}

{{/*
Define container security context with safe defaults
*/}}
{{- define "common-webapp.containerSecurityContext" -}}
runAsNonRoot: true
runAsUser: 1000
allowPrivilegeEscalation: false
capabilities:
  drop:
    - ALL
readOnlyRootFilesystem: false
{{- end }}

{{/*
Define liveness probe
*/}}
{{- define "common-webapp.livenessProbe" -}}
{{- if .Values.livenessProbe.enabled }}
livenessProbe:
  httpGet:
    path: {{ .Values.livenessProbe.path }}
    port: {{ .Values.livenessProbe.port }}
  initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds }}
  periodSeconds: {{ .Values.livenessProbe.periodSeconds }}
  timeoutSeconds: {{ .Values.livenessProbe.timeoutSeconds }}
  failureThreshold: {{ .Values.livenessProbe.failureThreshold }}
{{- end }}
{{- end }}

{{/*
Define readiness probe
*/}}
{{- define "common-webapp.readinessProbe" -}}
{{- if .Values.readinessProbe.enabled }}
readinessProbe:
  httpGet:
    path: {{ .Values.readinessProbe.path }}
    port: {{ .Values.readinessProbe.port }}
  initialDelaySeconds: {{ .Values.readinessProbe.initialDelaySeconds }}
  periodSeconds: {{ .Values.readinessProbe.periodSeconds }}
  timeoutSeconds: {{ .Values.readinessProbe.timeoutSeconds }}
  failureThreshold: {{ .Values.readinessProbe.failureThreshold }}
{{- end }}
{{- end }}
