{{/*
Define a reusable configmap template
*/}}
{{- define "common-webapp.configmap" -}}
{{- if .Values.config }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "common-webapp.fullname" . }}
  labels:
    {{- include "common-webapp.labels" . | nindent 4 }}
data:
  {{- toYaml .Values.config | nindent 2 }}
{{- end }}
{{- end }}
