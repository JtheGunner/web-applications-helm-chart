{{/*
Define a reusable service template
*/}}
{{- define "common-webapp.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common-webapp.fullname" . }}
  labels:
    {{- include "common-webapp.labels" . | nindent 4 }}
  {{- with .Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort | default "http" }}
      protocol: TCP
      name: http
  selector:
    {{- include "common-webapp.selectorLabels" . | nindent 4 }}
{{- end }}
