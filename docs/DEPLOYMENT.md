# Deployment Guide

Anleitung für das Deployment von Webapplikationen mit dem Webapp Helm Chart.

## Inhaltsverzeichnis

- [Voraussetzungen](#voraussetzungen)
- [Lokale Entwicklung](#lokale-entwicklung)
- [Production Deployment](#production-deployment)
- [FluxCD Integration](#fluxcd-integration)
- [Troubleshooting](#troubleshooting)

## Voraussetzungen

### Benötigte Tools

- **Kubernetes Cluster** (1.19+)
- **Helm** (3.8+)
- **kubectl** (mit Cluster-Zugang konfiguriert)
- **Docker** (zum Bauen der Images)

### Optionale Tools

- **FluxCD** (für GitOps Deployments)
- **cert-manager** (für automatische TLS-Zertifikate)

### Cluster-Anforderungen

- **Ingress Controller** (nginx, traefik, etc.)
- **Storage Class** (für Datenbank Persistence)

## Lokale Entwicklung

### 1. Chart Dependencies aktualisieren

```bash
cd charts/webapp
helm dependency update
```

### 2. Chart installieren

**PHP Applikation:**
```bash
helm install my-app charts/webapp \
  --set php.enabled=true \
  --set php.image.repository=localhost:5000/my-php-app \
  --set php.image.tag=dev
```

**Node.js Applikation:**
```bash
helm install my-api charts/webapp \
  --set nodejs.enabled=true \
  --set nodejs.image.repository=localhost:5000/my-node-api \
  --set nodejs.image.tag=dev \
  --set nodejs.port=3000
```

**Mit Values-Datei:**
```bash
helm install my-app charts/webapp -f examples/only-php.yaml
```

### 3. Deployment prüfen

```bash
# Pods anzeigen
kubectl get pods -l app.kubernetes.io/instance=my-app

# Logs (PHP)
kubectl logs <pod-name> -c php-fpm
kubectl logs <pod-name> -c nginx

# Logs (Node.js)
kubectl logs <pod-name> -c nodejs

# Port-Forward zum Testen
kubectl port-forward svc/my-app-webapp-php 8080:80
curl http://localhost:8080
```

### 4. Lokale Datenbank

```bash
# Mit PostgreSQL
helm install my-app charts/webapp \
  --set php.enabled=true \
  --set php.image.repository=my-app \
  --set postgresql.enabled=true \
  --set postgresql.auth.username=myapp \
  --set postgresql.auth.password=localdev \
  --set postgresql.auth.database=myapp_dev

# DB-Verbindung prüfen
kubectl exec -it <php-pod> -c php-fpm -- env | grep DB_
```

## Production Deployment

### 1. Production Values erstellen

```yaml
# values-production.yaml
php:
  enabled: true
  image:
    registry: ghcr.io
    repository: jthegunner/my-app
    tag: "v1.2.3"
    pullPolicy: IfNotPresent
  replicaCount: 3
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 2000m
      memory: 2Gi
  env:
    - name: APP_ENV
      value: production

  ingress:
    enabled: true
    className: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    hosts:
      - host: app.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: app-tls
        hosts:
          - app.example.com

  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 20
    targetCPUUtilizationPercentage: 70

imagePullSecrets:
  - name: ghcr-credentials

postgresql:
  enabled: true
  auth:
    username: "myapp"
    password: "secure-production-password"
    database: "myapp_production"
  primary:
    persistence:
      enabled: true
      size: 50Gi
```

### 2. Deployen

```bash
# Namespace erstellen
kubectl create namespace production

# Image Pull Secret erstellen
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=jthegunner \
  --docker-password=$GITHUB_TOKEN \
  -n production

# Deployment
helm install my-app charts/webapp \
  -f values-production.yaml \
  -n production
```

### 3. Verifizieren

```bash
kubectl get all -n production -l app.kubernetes.io/instance=my-app
kubectl get ingress -n production
curl https://app.example.com/health.php
```

## FluxCD Integration

### 1. HelmRepository erstellen

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: web-applications-charts
  namespace: flux-system
spec:
  interval: 5m
  type: oci
  url: oci://ghcr.io/jthegunner/helm-charts
```

### 2. HelmRelease erstellen

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: my-app
  namespace: production
spec:
  interval: 5m
  chart:
    spec:
      chart: webapp
      version: "1.0.0"
      sourceRef:
        kind: HelmRepository
        name: web-applications-charts
        namespace: flux-system

  values:
    php:
      enabled: true
      image:
        repository: jthegunner/my-app
        tag: "v1.2.3"
    postgresql:
      enabled: true
      auth:
        database: myapp
        username: myapp
        password: changeme
```

### 3. Monitoring

```bash
flux get helmreleases -n production
flux logs --kind=HelmRelease --name=my-app
flux reconcile helmrelease my-app -n production
```

## Troubleshooting

### Pods starten nicht

```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
```

**Häufige Ursachen:**
- Image Pull Error → Image-Name und Pull Secrets prüfen
- CrashLoopBackOff → Application Logs prüfen
- Pending → Cluster-Resourcen prüfen

### Health Check Fehler

```bash
kubectl port-forward <pod-name> 8080:80
curl http://localhost:8080/health.php   # PHP
curl http://localhost:3000/health       # Node.js
```

### Datenbank-Verbindung

```bash
# Env-Vars prüfen
kubectl exec -it <pod-name> -c php-fpm -- env | grep DB_

# PostgreSQL Zugang testen
kubectl exec -it <release>-postgresql-0 -- psql -U webapp -d webapp
```

### Rolling Back

```bash
# Helm History
helm history <release-name> -n <namespace>

# Rollback
helm rollback <release-name> -n <namespace>
```

---

**Weitere Infos:** Siehe [ARCHITECTURE.md](ARCHITECTURE.md)
