# Node.js WebApp Helm Chart

Helm chart for deploying Node.js web applications in Kubernetes.

## Architecture

This chart deploys a single-container Node.js application with:
- Express.js or any Node.js web framework
- Health check endpoints
- Graceful shutdown handling
- Horizontal pod autoscaling support

## Prerequisites

- Kubernetes 1.19+
- Helm 3.8+
- Built Docker image with your Node.js application

## Installation

### 1. Update Chart Dependencies

```bash
helm dependency update
```

### 2. Install Chart

```bash
helm install my-node-app . \
  --set image.repository=yourorg/my-node-app \
  --set image.tag=v1.0.0
```

## Configuration

See `values.yaml` for all available options.

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Node.js application image | `my-node-app` |
| `image.tag` | Image tag | `latest` |
| `replicaCount` | Number of replicas | `1` |
| `nodejs.port` | Application port | `3000` |
| `nodejs.resources.requests.cpu` | CPU request | `100m` |
| `nodejs.resources.requests.memory` | Memory request | `128Mi` |
| `ingress.enabled` | Enable ingress | `false` |
| `autoscaling.enabled` | Enable HPA | `false` |

### Example: Production Deployment

```yaml
# values-production.yaml
replicaCount: 5

image:
  repository: ghcr.io/yourorg/api
  tag: "v2.1.0"
  pullPolicy: IfNotPresent

nodejs:
  port: 3000
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 2000m
      memory: 2Gi
  env:
    - name: NODE_ENV
      value: production
    - name: LOG_LEVEL
      value: info
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: database-url

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100"
  hosts:
    - host: api.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: api-tls
      hosts:
        - api.example.com

autoscaling:
  enabled: true
  minReplicas: 5
  maxReplicas: 50
  targetCPUUtilizationPercentage: 70
```

Deploy:
```bash
helm install my-api . -f values-production.yaml
```

## Health Checks

Your Node.js application must provide:
- `/health` - Liveness probe endpoint
- `/ready` - Readiness probe endpoint

Example with Express.js:
```javascript
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

app.get('/ready', (req, res) => {
  // Check database connection, etc.
  res.status(200).json({ status: 'ready' });
});
```

## Environment Variables

Configure via `nodejs.env`:

```yaml
nodejs:
  env:
    - name: NODE_ENV
      value: production
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: my-secrets
          key: db-url
```

## Graceful Shutdown

Your application should handle SIGTERM for graceful shutdown:

```javascript
process.on('SIGTERM', () => {
  console.log('SIGTERM received, closing server...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
```

## Security

- Container runs as non-root user (UID 1000)
- Capabilities dropped
- Security context enforced
- `dumb-init` for proper signal handling

## FluxCD Integration

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: my-node-app
spec:
  chart:
    spec:
      chart: charts/node-webapp
  values:
    image:
      repository: yourorg/app
      tag: v1.0.0
    nodejs:
      env:
        - name: NODE_ENV
          value: production
```

## Troubleshooting

### Application crashing
Check logs:
```bash
kubectl logs <pod-name>
```

Common issues:
- Port mismatch (`nodejs.port` vs application port)
- Missing environment variables
- Database connection failures

### Health check failures
Ensure your app exposes `/health` and `/ready` endpoints on the configured port.

## License

MIT
