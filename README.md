# Web Applications Helm Chart Library

A production-ready Helm chart library system for deploying PHP and Node.js web applications on Kubernetes with best practices, optimal performance, and FluxCD integration.

## 🎯 Features

- **Library Chart Pattern** - Reusable templates for DRY Kubernetes deployments
- **Multi-Stage Dockerfiles** - Assets built at Docker build-time, not runtime
- **Production-Ready Security** - Non-root users, read-only filesystems, capability drops
- **PHP-FPM + Nginx** - Production-grade PHP deployment with sidecar pattern
- **Health Checks** - Built-in liveness and readiness probes
- **Autoscaling** - HPA support out of the box
- **FluxCD Ready** - GitOps-friendly with minimal configuration

## 📁 Repository Structure

```
web-applications-helm-chart/
├── charts/
│   ├── common-webapp/          # Library chart (reusable templates)
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── _helpers.tpl    # Name and label helpers
│   │       ├── _deployment.tpl # Deployment template
│   │       ├── _service.tpl    # Service template
│   │       ├── _ingress.tpl    # Ingress template
│   │       └── _configmap.tpl  # ConfigMap template
│   │
│   ├── php-webapp/             # PHP application chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── deployment.yaml # PHP-FPM + Nginx deployment
│   │       ├── nginx-config.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml
│   │       └── configmap.yaml
│   │
│   └── node-webapp/            # Node.js application chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           └── configmap.yaml
│
├── examples/
│   ├── php-app/                # Example PHP application
│   │   ├── Dockerfile          # Multi-stage build
│   │   ├── package.json
│   │   ├── composer.json
│   │   └── public/
│   │
│   ├── node-app/               # Example Node.js application
│   │   ├── Dockerfile          # Multi-stage build
│   │   ├── package.json
│   │   └── server.js
│   │
│   └── flux/                   # FluxCD examples
│       ├── helmrepository.yaml
│       ├── php-app-release.yaml
│       └── node-app-release.yaml
│
└── docs/
    ├── ARCHITECTURE.md         # Architecture decisions
    └── DEPLOYMENT.md           # Deployment guide
```

## 🚀 Quick Start

### 1. Build Your Application Image

**PHP Application:**
```bash
cd examples/php-app
docker build -t yourorg/my-php-app:v1.0.0 .
docker push yourorg/my-php-app:v1.0.0
```

**Node.js Application:**
```bash
cd examples/node-app
docker build -t yourorg/my-node-app:v1.0.0 .
docker push yourorg/my-node-app:v1.0.0
```

### 2. Install Chart Locally (Development)

**Update chart dependencies:**
```bash
cd charts/php-webapp
helm dependency update
```

**Install the chart:**
```bash
helm install my-php-app charts/php-webapp \
  --set image.repository=yourorg/my-php-app \
  --set image.tag=v1.0.0 \
  --set ingress.enabled=false
```

### 3. Deploy with FluxCD (Production)

See [examples/flux/](examples/flux/) directory for complete FluxCD HelmRelease examples.

**Simple deployment:**
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: my-app
  namespace: web-applications
spec:
  chart:
    spec:
      chart: charts/php-webapp
      sourceRef:
        kind: HelmRepository
        name: web-applications-charts
  values:
    image:
      repository: yourorg/my-php-app
      tag: v1.0.0
    ingress:
      enabled: true
      hosts:
        - host: app.example.com
          paths:
            - path: /
              pathType: Prefix
```

## 📦 Helm Repository Setup

### Option 1: Local Development

**Update dependencies and install:**
```bash
# Update chart dependencies
helm dependency update charts/php-webapp
helm dependency update charts/node-webapp

# Install directly from local charts
helm install my-app charts/php-webapp \
  --set image.repository=jthegunner/php-composer-npm-amd \
  --set image.tag=latest
```

### Option 2: OCI Registry (Recommended for Production)

**Package and publish charts:**
```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | helm registry login ghcr.io -u USERNAME --password-stdin

# Package charts
helm package charts/common-webapp
helm package charts/php-webapp
helm package charts/node-webapp

# Push to registry
helm push php-webapp-1.0.0.tgz oci://ghcr.io/yourorg/helm-charts
helm push node-webapp-1.0.0.tgz oci://ghcr.io/yourorg/helm-charts
```

**Install from OCI registry:**
```bash
helm install my-app oci://ghcr.io/yourorg/helm-charts/php-webapp \
  --version 1.0.0 \
  -f values.yaml
```

### Option 3: FluxCD with OCI Registry

**Create HelmRepository:**
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: web-applications-charts
  namespace: flux-system
spec:
  interval: 5m
  type: oci
  url: oci://ghcr.io/yourorg/helm-charts
```

**Create HelmRelease:**
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: my-app
  namespace: webhosting
spec:
  interval: 5m
  chart:
    spec:
      chart: php-webapp
      version: "1.0.0"
      sourceRef:
        kind: HelmRepository
        name: web-applications-charts
        namespace: flux-system
  values:
    image:
      repository: jthegunner/php-composer-npm-amd
      tag: "latest"
    ingress:
      enabled: true
      hosts:
        - host: my-app.example.com
          paths:
            - path: /
              pathType: Prefix
```

**📖 For complete Helm repository setup options (Git, HTTP, automated CI/CD), see [docs/HELM-REPOSITORY.md](docs/HELM-REPOSITORY.md)**

## 📚 Documentation

- **[Helm Repository Setup](docs/HELM-REPOSITORY.md)** - All deployment options (Local, Git, OCI, FluxCD)
- **[Architecture Documentation](docs/ARCHITECTURE.md)** - Design decisions and patterns
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Comprehensive deployment instructions
- **[PHP Chart README](charts/php-webapp/README.md)** - PHP-specific configuration
- **[Node Chart README](charts/node-webapp/README.md)** - Node.js-specific configuration
- **[Library Chart README](charts/common-webapp/README.md)** - Template reference

## 🔑 Key Design Decisions

### 1. Multi-Stage Docker Builds

Assets are compiled **at Docker build-time**, not Kubernetes runtime:

✅ **Benefits:**
- Faster pod startup (no npm install on each deployment)
- Immutable artifacts (reproducible builds)
- Smaller attack surface (build tools not in production)

❌ **Anti-Pattern (Avoided):**
```yaml
# DON'T do this
initContainers:
  - name: build-assets
    command: ["npm", "install", "&&", "npm", "run", "build"]
```

### 2. Library Chart Pattern

Reusable templates without complexity:
- `common-webapp` provides shared templates
- `php-webapp` and `node-webapp` consume them
- No conditional hell in single "universal" chart

### 3. PHP-FPM + Nginx Sidecar

Production-grade PHP deployment:
- PHP-FPM handles PHP processing (port 9000)
- Nginx handles HTTP requests and static files (port 80)
- Shared volume for application files

## 🛡️ Security Features

- **Non-root containers** - All containers run as UID 1000
- **Capability dropping** - Minimal Linux capabilities
- **Read-only root filesystem** (where applicable)
- **Security headers** - X-Frame-Options, X-Content-Type-Options
- **Resource limits** - CPU and memory constraints

## 🔧 Configuration Examples

### Horizontal Pod Autoscaling
```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

### Custom Environment Variables
```yaml
phpFpm:  # or nodejs for Node.js apps
  env:
    - name: APP_ENV
      value: production
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: db-url
```

### Resource Limits
```yaml
phpFpm:
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `helm lint` and `helm template`
5. Submit a pull request

## 📝 License

MIT License - see LICENSE file for details

## 🆘 Support

For issues and questions:
- Check [DEPLOYMENT.md](docs/DEPLOYMENT.md) for troubleshooting
- Open an issue on GitHub
- Contact DevOps team

---

**Built with ❤️ for production Kubernetes deployments**
