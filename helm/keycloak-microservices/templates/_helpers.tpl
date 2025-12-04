{{/*
Expand the name of the chart.
*/}}
{{- define "keycloak-microservices.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "keycloak-microservices.fullname" -}}
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
Keycloak issuer URI
*/}}
{{- define "keycloak-microservices.keycloakIssuerUri" -}}
http://{{ .Values.keycloak.service.name | default "keycloak" }}.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.keycloak.service.port }}/realms/{{ .Values.global.keycloakRealm }}
{{- end }}

{{/*
Build full image name with registry
Usage: {{ include "keycloak-microservices.image" (dict "root" . "repository" "api-gateway" "tag" "latest") }}
*/}}
{{- define "keycloak-microservices.image" -}}
{{- $registry := .root.Values.global.imageRegistry }}
{{- $repo := .repository }}
{{- $tag := .tag }}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repo $tag }}
{{- else }}
{{- printf "%s:%s" $repo $tag }}
{{- end }}
{{- end }}

