# PHP WebApp Helm Chart

Helm chart for deploying PHP web applications with PHP-FPM and Nginx in Kubernetes.

## Architecture

This chart deploys a production-ready PHP application using:
- **PHP-FPM** container (port 9000) - Handles PHP processing
- **Nginx** sidecar container (port 80) - HTTP server and reverse proxy
- Shared volumes for application files and PHP socket

## Prerequisites

- Kubernetes 1.19+
- Helm 3.8+
- Built Docker image with your PHP application

## Installation

### 1. Update Chart Dependencies

```bash
helm dependency update
```

### 2. Install Chart

```bash
helm install my-php-app . \
  --set image.repository=yourorg/my-php-app \
  --set image.tag=v1.0.0
```

## Configuration

See `values.yaml` for all available options.

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | PHP application image | `my-php-app` |
| `image.tag` | Image tag | `latest` |
| `replicaCount` | Number of replicas | `1` |
| `phpFpm.resources.requests.cpu` | PHP-FPM CPU request | `200m` |
| `phpFpm.resources.requests.memory` | PHP-FPM memory request | `256Mi` |
| `nginx.enabled` | Enable Nginx sidecar | `true` |
| `ingress.enabled` | Enable ingress | `false` |
| `autoscaling.enabled` | Enable HPA | `false` |

### Example: Production Deployment

```yaml
# values-production.yaml
replicaCount: 3

image:
  repository: ghcr.io/yourorg/app
  tag: "v1.2.3"
  pullPolicy: IfNotPresent

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

nginx:
  enabled: true

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
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
```

Deploy:
```bash
helm install my-app . -f values-production.yaml
```

## Health Checks

Your PHP application must provide:
- `/health.php` - Health check endpoint (liveness probe)
- `/health.php` - Readiness check endpoint

Example `health.php`:
```php
<?php
header('Content-Type: application/json');
http_response_code(200);
echo json_encode(['status' => 'healthy']);
```

## Nginx Configuration

The chart includes a default Nginx configuration optimized for PHP-FPM. See `templates/nginx-config.yaml`.

### Customizing Nginx

Override the ConfigMap in your values:
```yaml
# Not directly supported, fork chart if needed
```

## Security

- Containers run as non-root user (UID 1000)
- Security headers enabled (X-Frame-Options, etc.)
- Capabilities dropped
- Read-only root filesystem (where applicable)

## FluxCD Integration

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: my-php-app
spec:
  chart:
    spec:
      chart: charts/php-webapp
  values:
    image:
      repository: yourorg/app
      tag: v1.0.0
```

## Troubleshooting

### Pods not starting
Check PHP-FPM logs:
```bash
kubectl logs <pod-name> -c php-fpm
```

Check Nginx logs:
```bash
kubectl logs <pod-name> -c nginx
```

### 502 Bad Gateway
- Verify PHP-FPM is listening on port 9000
- Check PHP-FPM configuration in your image
- Ensure application files are in `/var/www/html/public`

## License

MIT
