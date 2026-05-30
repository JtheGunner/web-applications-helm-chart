# Web Applications Helm Chart

A universal Helm chart for deploying PHP and/or Node.js web applications on Kubernetes with optional database support (PostgreSQL, MariaDB).

## 🎯 Features

- **One chart for everything** – run PHP, Node.js, or both at the same time, switched by values
- **App from image *or* Git** – `app.source: image` (default) or `app.source: git`; for PHP the build step (`composer install`) runs automatically, Node.js opt-in
- **Database support** – PostgreSQL and MariaDB as optional sub-charts (Bitnami), with `existingSecret` supported
- **PHP-FPM + Nginx + init container** – production-grade PHP deployment with a correctly shared app volume
- **Separate deployments** – PHP and Node.js scale independently
- **Production-ready security** – non-root users, capability drops, seccomp, security headers
- **Health checks** – liveness, readiness, and startup probes; TCP probe directly on PHP-FPM
- **Autoscaling, PDB & NetworkPolicy** – HPA, PodDisruptionBudget, and NetworkPolicy per runtime
- **HA scheduling** – `topologySpreadConstraints`, `affinity`, `tolerations` per runtime
- **FluxCD ready** – GitOps-friendly with minimal configuration

## 📁 Repository structure

```
web-applications-helm-chart/
├── charts/
│   └── webapp/                         # The unified Helm chart
│       ├── Chart.yaml                  # Chart definition + DB dependencies
│       ├── values.yaml                 # All configurable values
│       └── templates/
│           ├── _helpers.tpl            # Name, label, image, envFrom helpers
│           ├── validate.yaml           # Input validation (runtime/DB)
│           ├── deployment-php.yaml     # PHP-FPM + Nginx + init container
│           ├── deployment-node.yaml    # Node.js
│           ├── service-php.yaml        # PHP Service
│           ├── service-node.yaml       # Node Service
│           ├── ingress-php.yaml        # PHP Ingress
│           ├── ingress-node.yaml       # Node Ingress
│           ├── nginx-config.yaml       # Nginx config for PHP-FPM
│           ├── configmap.yaml          # Root app configuration (envFrom)
│           ├── configmap-php-fpm.yaml  # PHP-FPM tuning (www.conf etc.)
│           ├── hpa-php.yaml            # HPA for PHP
│           ├── hpa-node.yaml           # HPA for Node.js
│           ├── pdb-php.yaml            # PodDisruptionBudget PHP
│           ├── pdb-node.yaml           # PodDisruptionBudget Node.js
│           ├── networkpolicy-php.yaml  # NetworkPolicy PHP
│           ├── networkpolicy-node.yaml # NetworkPolicy Node.js
│           ├── serviceaccount.yaml     # ServiceAccount
│           └── NOTES.txt               # Helm install output
│
├── examples/
│   ├── only-php.yaml              # PHP only + PostgreSQL
│   ├── only-node.yaml             # Node.js only + MariaDB
│   ├── php-and-node.yaml          # Both + PostgreSQL
│   ├── no-database.yaml           # No database
│   ├── php-app/                   # Sample PHP application
│   ├── node-app/                  # Sample Node.js application
│   └── flux/                      # FluxCD examples
│
└── docs/
    ├── ARCHITECTURE.md            # Architecture decisions
    ├── DEPLOYMENT.md              # Deployment guide
    └── HELM-REPOSITORY.md         # Helm repository setup
```

## 🚀 Quick start

### 1. Update dependencies

```bash
cd charts/webapp
helm dependency update
```

### 2. Install the chart

**PHP only:**
```bash
helm install my-app charts/webapp \
  --set php.enabled=true \
  --set php.image.repository=jthegunner/my-php-app \
  --set php.image.tag=v1.0.0
```

**Node.js only:**
```bash
helm install my-api charts/webapp \
  --set nodejs.enabled=true \
  --set nodejs.image.repository=jthegunner/my-node-api \
  --set nodejs.image.tag=v2.0.0
```

**PHP + Node.js + PostgreSQL:**
```bash
helm install my-app charts/webapp -f examples/php-and-node.yaml
```

### 3. Deploy with FluxCD (production)

See [examples/flux/](examples/flux/) for full FluxCD HelmRelease examples.

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: my-app
  namespace: webhosting
spec:
  chart:
    spec:
      chart: webapp
      sourceRef:
        kind: HelmRepository
        name: web-applications-charts
  values:
    php:
      enabled: true
      image:
        repository: jthegunner/my-php-app
        tag: v1.0.0
    postgresql:
      enabled: true
      auth:
        database: myapp
        username: myapp
        password: changeme
```

## 📦 Configuration

### Runtime selection

| Parameter | Description | Default |
|-----------|-------------|---------|
| `php.enabled` | Enable the PHP runtime | `false` |
| `nodejs.enabled` | Enable the Node.js runtime | `false` |

### Database

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Enable the PostgreSQL sub-chart | `false` |
| `mariadb.enabled` | Enable the MariaDB sub-chart | `false` |

> **Note:** Only one database can be enabled at a time.

Database connection details are injected automatically as environment variables into every enabled runtime:
- `DB_CONNECTION` – database type (`pgsql` or `mysql`)
- `DB_HOST` – host name
- `DB_PORT` – port
- `DB_DATABASE` – database name
- `DB_USERNAME` – user name
- `DB_PASSWORD` – password (from a Secret)

### PHP configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `php.image.repository` | PHP image | `""` |
| `php.image.tag` | Image tag | `latest` |
| `php.replicaCount` | Number of replicas | `1` |
| `php.resources` | Resource limits | `200m/256Mi` |
| `php.nginx.image.tag` | Nginx sidecar version | `1.27-alpine` |
| `php.ingress.enabled` | Enable Ingress | `false` |
| `php.autoscaling.enabled` | Enable HPA | `false` |

### Node.js configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nodejs.image.repository` | Node.js image | `""` |
| `nodejs.image.tag` | Image tag | `latest` |
| `nodejs.port` | Application port | `3000` |
| `nodejs.replicaCount` | Number of replicas | `1` |
| `nodejs.resources` | Resource limits | `100m/128Mi` |
| `nodejs.ingress.enabled` | Enable Ingress | `false` |
| `nodejs.autoscaling.enabled` | Enable HPA | `false` |

## 🔧 Usage examples

### PHP only with PostgreSQL

```yaml
php:
  enabled: true
  image:
    repository: jthegunner/my-php-app
    tag: "v1.0.0"
  env:
    - name: APP_ENV
      value: production

postgresql:
  enabled: true
  auth:
    username: "myapp"
    password: "changeme"
    database: "myapp"
```

### PHP + Node.js (frontend + API)

```yaml
php:
  enabled: true
  image:
    repository: jthegunner/my-frontend
    tag: "v1.0.0"
  ingress:
    enabled: true
    hosts:
      - host: app.example.com
        paths:
          - path: /
            pathType: Prefix

nodejs:
  enabled: true
  image:
    repository: jthegunner/my-api
    tag: "v2.0.0"
  ingress:
    enabled: true
    hosts:
      - host: api.example.com
        paths:
          - path: /
            pathType: Prefix

postgresql:
  enabled: true
  auth:
    database: myapp
    username: myapp
    password: changeme
```

## 🛡️ Security features

- **Non-root containers** – all containers run as a non-root UID (PHP-FPM: 33, Node.js: 1000)
- **Capability dropping** – minimal Linux capabilities
- **Security headers** – X-Frame-Options, X-Content-Type-Options (PHP/Nginx)
- **Resource limits** – CPU and memory constraints
- **ServiceAccount token** – automount disabled

## 📚 Documentation

- **[Architecture](docs/ARCHITECTURE.md)** – design decisions
- **[Deployment Guide](docs/DEPLOYMENT.md)** – step-by-step deployment instructions
- **[Helm Repository Setup](docs/HELM-REPOSITORY.md)** – repository options

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `helm lint` and `helm template`
5. Open a pull request

## 📝 License

MIT License

---

**Built with ❤️ for production Kubernetes deployments**
