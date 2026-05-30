# Deployment Guide

How to deploy web applications with the webapp Helm chart.

## Table of contents

- [Prerequisites](#prerequisites)
- [Local development](#local-development)
- [Production deployment](#production-deployment)
- [FluxCD integration](#fluxcd-integration)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required tools

- **Kubernetes cluster** (1.19+)
- **Helm** (3.8+)
- **kubectl** (configured with cluster access)
- **Docker** (for building images)

### Optional tools

- **FluxCD** (for GitOps deployments)
- **cert-manager** (for automatic TLS certificates)

### Cluster requirements

- **Ingress controller** (nginx, traefik, etc.)
- **Storage class** (for database persistence)

## Local development

### 1. Update chart dependencies

```bash
cd charts/webapp
helm dependency update
```

### 2. Install the chart

**PHP application:**
```bash
helm install my-app charts/webapp \
  --set php.enabled=true \
  --set php.image.repository=localhost:5000/my-php-app \
  --set php.image.tag=dev
```

**Node.js application:**
```bash
helm install my-api charts/webapp \
  --set nodejs.enabled=true \
  --set nodejs.image.repository=localhost:5000/my-node-api \
  --set nodejs.image.tag=dev \
  --set nodejs.port=3000
```

**With a values file:**
```bash
helm install my-app charts/webapp -f examples/only-php.yaml
```

### 3. Check the deployment

```bash
# Show pods
kubectl get pods -l app.kubernetes.io/instance=my-app

# Logs (PHP)
kubectl logs <pod-name> -c php-fpm
kubectl logs <pod-name> -c nginx

# Logs (Node.js)
kubectl logs <pod-name> -c nodejs

# Port-forward for local testing
kubectl port-forward svc/my-app-webapp-php 8080:80
curl http://localhost:8080
```

### 4. Local database

```bash
# With PostgreSQL
helm install my-app charts/webapp \
  --set php.enabled=true \
  --set php.image.repository=my-app \
  --set postgresql.enabled=true \
  --set postgresql.auth.username=myapp \
  --set postgresql.auth.password=localdev \
  --set postgresql.auth.database=myapp_dev

# Check the DB connection
kubectl exec -it <php-pod> -c php-fpm -- env | grep DB_
```

## Production deployment

### 1. Create production values

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

### 2. Deploy

```bash
# Create the namespace
kubectl create namespace production

# Create the image pull secret
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=jthegunner \
  --docker-password=$GITHUB_TOKEN \
  -n production

# Deploy
helm install my-app charts/webapp \
  -f values-production.yaml \
  -n production
```

### 3. Verify

```bash
kubectl get all -n production -l app.kubernetes.io/instance=my-app
kubectl get ingress -n production
curl https://app.example.com/
```

## FluxCD integration

### 1. Create a HelmRepository

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: web-applications-charts
  namespace: flux-system
spec:
  interval: 5m
  type: oci
  url: oci://ghcr.io/jthegunner
```

### 2. Create a HelmRelease

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

### Pods don't start

```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
```

**Common causes:**
- Image pull error → check the image name and pull secrets
- CrashLoopBackOff → check the application logs
- Pending → check cluster resources

### Health-check errors

```bash
kubectl port-forward <pod-name> 8080:80
curl http://localhost:8080/   # PHP
curl http://localhost:3000/       # Node.js
```

### Database connectivity

```bash
# Check env vars
kubectl exec -it <pod-name> -c php-fpm -- env | grep DB_

# Test PostgreSQL access
kubectl exec -it <release>-postgresql-0 -- psql -U webapp -d webapp
```

### Rolling back

```bash
# Helm history
helm history <release-name> -n <namespace>

# Roll back
helm rollback <release-name> -n <namespace>
```

---

**More info:** see [ARCHITECTURE.md](ARCHITECTURE.md)
