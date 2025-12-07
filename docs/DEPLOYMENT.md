# Deployment Guide

Comprehensive guide for deploying web applications using this Helm chart library.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [Production Deployment](#production-deployment)
- [FluxCD Integration](#fluxcd-integration)
- [CI/CD Pipeline](#cicd-pipeline)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- **Kubernetes Cluster** (1.19+)
- **Helm** (3.8+)
- **kubectl** (configured with cluster access)
- **Docker** (for building images)

### Optional Tools

- **FluxCD** (for GitOps deployments)
- **cert-manager** (for automatic TLS certificates)
- **Prometheus** (for monitoring)

### Cluster Requirements

- **Ingress Controller** (nginx, traefik, etc.)
- **Storage Class** (if using persistent volumes)
- **Namespace** with appropriate RBAC

## Local Development

### 1. Build Application Image

#### PHP Application

```bash
cd examples/php-app

# Build multi-stage Docker image
docker build -t localhost:5000/my-php-app:dev .

# Test locally
docker run -p 8000:9000 localhost:5000/my-php-app:dev

# Push to local registry (optional)
docker push localhost:5000/my-php-app:dev
```

#### Node.js Application

```bash
cd examples/node-app

# Build image
docker build -t localhost:5000/my-node-app:dev .

# Test locally
docker run -p 3000:3000 localhost:5000/my-node-app:dev

# Verify health endpoint
curl http://localhost:3000/health
```

### 2. Install Chart Locally

#### Update Dependencies

```bash
cd charts/php-webapp
helm dependency update
```

#### Install to Kubernetes

```bash
# Install PHP app
helm install my-php-app charts/php-webapp \
  --set image.repository=localhost:5000/my-php-app \
  --set image.tag=dev \
  --set ingress.enabled=false \
  --set replicaCount=1

# Install Node app
helm install my-node-app charts/node-webapp \
  --set image.repository=localhost:5000/my-node-app \
  --set image.tag=dev \
  --set ingress.enabled=false
```

#### Verify Deployment

```bash
# Check pods
kubectl get pods

# Check logs (PHP)
kubectl logs <pod-name> -c php-fpm
kubectl logs <pod-name> -c nginx

# Check logs (Node)
kubectl logs <pod-name>

# Port-forward for testing
kubectl port-forward svc/my-php-app 8080:80
curl http://localhost:8080
```

### 3. Local Testing with Values Override

Create `values-dev.yaml`:

```yaml
# values-dev.yaml
image:
  repository: localhost:5000/my-app
  tag: dev
  pullPolicy: Always

replicaCount: 1

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: myapp.local
      paths:
        - path: /
          pathType: Prefix

# Disable autoscaling for dev
autoscaling:
  enabled: false
```

Deploy:
```bash
helm install my-app charts/php-webapp -f values-dev.yaml
```

## Production Deployment

### 1. Build Production Image

```bash
# Tag with version
docker build -t ghcr.io/yourorg/my-app:v1.2.3 .

# Security scan
docker scan ghcr.io/yourorg/my-app:v1.2.3

# Push to registry
docker push ghcr.io/yourorg/my-app:v1.2.3
```

### 2. Create Production Values

```yaml
# values-production.yaml
image:
  registry: ghcr.io
  repository: yourorg/my-app
  tag: v1.2.3
  pullPolicy: IfNotPresent

imagePullSecrets:
  - name: ghcr-credentials

replicaCount: 3

phpFpm:
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
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: database-url

nginx:
  enabled: true
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rate-limit: "100"
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: app-tls
      hosts:
        - app.example.com

livenessProbe:
  enabled: true
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  enabled: true
  initialDelaySeconds: 10
  periodSeconds: 5

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"
```

### 3. Deploy to Production

```bash
# Create namespace
kubectl create namespace production

# Create image pull secret (if using private registry)
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=yourorg \
  --docker-password=$GITHUB_TOKEN \
  -n production

# Deploy application
helm install my-app charts/php-webapp \
  -f values-production.yaml \
  -n production
```

### 4. Verify Deployment

```bash
# Check deployment status
kubectl get deployment -n production
kubectl get pods -n production

# Check ingress
kubectl get ingress -n production

# Test endpoint
curl https://app.example.com/health

# Watch rollout
kubectl rollout status deployment/my-app -n production
```

## FluxCD Integration

### 1. Setup HelmRepository

```yaml
# infrastructure/helmrepository.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: web-applications
  namespace: flux-system
spec:
  interval: 5m
  type: git
  url: https://github.com/yourorg/web-applications-helm-chart
  ref:
    branch: main
```

Apply:
```bash
kubectl apply -f infrastructure/helmrepository.yaml
```

### 2. Create HelmRelease

```yaml
# applications/production/my-app.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: my-app
  namespace: production
spec:
  interval: 5m
  timeout: 10m
  
  chart:
    spec:
      chart: charts/php-webapp
      version: "1.0.0"
      sourceRef:
        kind: HelmRepository
        name: web-applications
        namespace: flux-system
  
  releaseName: my-app
  
  install:
    createNamespace: true
    remediation:
      retries: 3
  
  upgrade:
    remediation:
      retries: 3
  
  valuesFrom:
    - kind: ConfigMap
      name: my-app-config
    - kind: Secret
      name: my-app-secrets
  
  values:
    image:
      repository: ghcr.io/yourorg/my-app
      tag: v1.2.3
```

Apply:
```bash
kubectl apply -f applications/production/my-app.yaml
```

### 3. Monitor FluxCD

```bash
# Watch reconciliation
flux get helmreleases -n production

# Check logs
flux logs --kind=HelmRelease --name=my-app

# Force reconciliation
flux reconcile helmrelease my-app -n production
```

## CI/CD Pipeline

### GitHub Actions Example

```yaml
# .github/workflows/deploy.yaml
name: Deploy Application

on:
  push:
    tags:
      - 'v*'

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker image
        run: |
          docker build -t ghcr.io/${{ github.repository }}:${{ github.ref_name }} .
      
      - name: Push to registry
        run: |
          echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
          docker push ghcr.io/${{ github.repository }}:${{ github.ref_name }}
      
      - name: Update HelmRelease
        run: |
          # Update tag in FluxCD HelmRelease
          yq e ".spec.values.image.tag = \"${{ github.ref_name }}\"" -i flux/production/my-app.yaml
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add flux/production/my-app.yaml
          git commit -m "Update image tag to ${{ github.ref_name }}"
          git push
```

## Troubleshooting

### Pods Not Starting

**Check pod status:**
```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
```

**Common issues:**
- Image pull errors → Check image name and pull secrets
- CrashLoopBackOff → Check application logs
- Pending → Check resource availability

### Health Check Failures

**Verify health endpoints:**
```bash
# Port-forward to pod
kubectl port-forward <pod-name> 8080:80

# Test endpoint
curl http://localhost:8080/health
```

**Common issues:**
- Wrong path (`/health` vs `/health.php`)
- Wrong port (3000 vs 80)
- Application not ready (increase `initialDelaySeconds`)

### PHP-FPM Issues

**Check PHP-FPM configuration:**
```bash
kubectl exec <pod-name> -c php-fpm -- php-fpm -t
```

**Check Nginx to PHP-FPM connection:**
```bash
kubectl logs <pod-name> -c nginx
# Look for "502 Bad Gateway" errors
```

**Common issues:**
- PHP-FPM not listening on port 9000
- Application files not in `/var/www/html/public`
- Permissions issues

### Ingress Issues

**Check ingress status:**
```bash
kubectl get ingress -n <namespace>
kubectl describe ingress <ingress-name> -n <namespace>
```

**Common issues:**
- DNS not pointing to ingress IP
- TLS certificate not issued (check cert-manager)
- Ingress class mismatch

### Resource Limits

**Check resource usage:**
```bash
kubectl top pods -n <namespace>
```

**If pods are OOMKilled:**
```yaml
# Increase memory limits
resources:
  limits:
    memory: 2Gi  # Increase this
```

### Debug Mode

**Enable debug logging:**
```yaml
# For PHP
phpFpm:
  env:
    - name: APP_DEBUG
      value: "true"
    - name: LOG_LEVEL
      value: debug

# For Node
nodejs:
  env:
    - name: NODE_ENV
      value: development
    - name: LOG_LEVEL
      value: debug
```

### Rolling Back

**Helm rollback:**
```bash
# List releases
helm list -n <namespace>

# Check history
helm history <release-name> -n <namespace>

# Rollback to previous version
helm rollback <release-name> -n <namespace>
```

**FluxCD rollback:**
```bash
# Update HelmRelease with previous tag
kubectl edit helmrelease <release-name> -n <namespace>

# Or commit previous version in Git
git revert <commit-hash>
git push
```

## Best Practices

### 1. Resource Management
- Always set resource requests and limits
- Use HPA for dynamic scaling
- Monitor resource usage

### 2. Security
- Never use `latest` tag in production
- Always use image pull secrets for private registries
- Enable Pod Security Standards
- Regular security scans

### 3. Monitoring
- Implement health checks
- Use Prometheus metrics
- Set up alerts for failures

### 4. Deployment Strategy
- Use blue-green or canary deployments
- Test in staging first
- Automate with CI/CD

---

**Need Help?** Check the [Architecture Documentation](ARCHITECTURE.md) or open an issue.
