# Web Applications Helm Chart

Ein universelles Helm Chart für das Deployment von PHP und/oder Node.js Webapplikationen auf Kubernetes mit optionaler Datenbank-Unterstützung (PostgreSQL, MariaDB).

## 🎯 Features

- **Ein Chart für alles** – PHP, Node.js oder beides gleichzeitig per Values steuern
- **App aus Image *oder* Git** – `app.source: image` (Default) oder `app.source: git` mit optionalem Build-Schritt (composer install, npm ci)
- **Datenbank-Support** – PostgreSQL und MariaDB als optionale Sub-Charts (Bitnami), `existingSecret` unterstützt
- **PHP-FPM + Nginx + Init-Container** – Production-grade PHP Deployment mit korrekt geteiltem App-Volume
- **Separate Deployments** – PHP und Node.js skalieren unabhängig voneinander
- **Production-Ready Security** – Non-root Users, Capability Drops, seccomp, Security Headers
- **Health Checks** – Liveness, Readiness und Startup Probes; TCP-Probe direkt auf PHP-FPM
- **Autoscaling, PDB & NetworkPolicy** – HPA, PodDisruptionBudget und NetworkPolicy pro Runtime
- **HA-Scheduling** – `topologySpreadConstraints`, `affinity`, `tolerations` pro Runtime
- **FluxCD Ready** – GitOps-friendly mit minimaler Konfiguration

## 📁 Repository Struktur

```
web-applications-helm-chart/
├── charts/
│   └── webapp/                     # Das einheitliche Helm Chart
│       ├── Chart.yaml                  # Chart-Definition + DB Dependencies
│       ├── values.yaml                 # Alle konfigurierbaren Values
│       └── templates/
│           ├── _helpers.tpl            # Name, Label, Image, envFrom Helpers
│           ├── validate.yaml           # Input-Validierung (Runtime/DB)
│           ├── deployment-php.yaml     # PHP-FPM + Nginx + Init-Container
│           ├── deployment-node.yaml    # Node.js
│           ├── service-php.yaml        # PHP Service
│           ├── service-node.yaml       # Node Service
│           ├── ingress-php.yaml        # PHP Ingress
│           ├── ingress-node.yaml       # Node Ingress
│           ├── nginx-config.yaml       # Nginx Config für PHP-FPM
│           ├── configmap.yaml          # Root-App-Konfiguration (envFrom)
│           ├── configmap-php-fpm.yaml  # PHP-FPM Tuning (www.conf etc.)
│           ├── hpa-php.yaml            # HPA für PHP
│           ├── hpa-node.yaml           # HPA für Node.js
│           ├── pdb-php.yaml            # PodDisruptionBudget PHP
│           ├── pdb-node.yaml           # PodDisruptionBudget Node.js
│           ├── networkpolicy-php.yaml  # NetworkPolicy PHP
│           ├── networkpolicy-node.yaml # NetworkPolicy Node.js
│           ├── serviceaccount.yaml     # ServiceAccount
│           └── NOTES.txt               # Helm install Output
│
├── examples/
│   ├── only-php.yaml              # Nur PHP + PostgreSQL
│   ├── only-node.yaml             # Nur Node.js + MariaDB
│   ├── php-and-node.yaml          # Beides + PostgreSQL
│   ├── no-database.yaml           # Ohne Datenbank
│   ├── php-app/                   # Beispiel PHP Applikation
│   ├── node-app/                  # Beispiel Node.js Applikation
│   └── flux/                      # FluxCD Beispiele
│
└── docs/
    ├── ARCHITECTURE.md            # Architektur-Entscheidungen
    ├── DEPLOYMENT.md              # Deployment-Anleitung
    └── HELM-REPOSITORY.md         # Helm Repository Setup
```

## 🚀 Quick Start

### 1. Dependencies aktualisieren

```bash
cd charts/webapp
helm dependency update
```

### 2. Chart installieren

**Nur PHP:**
```bash
helm install my-app charts/webapp \
  --set php.enabled=true \
  --set php.image.repository=jthegunner/my-php-app \
  --set php.image.tag=v1.0.0
```

**Nur Node.js:**
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

### 3. Deploy mit FluxCD (Production)

Siehe [examples/flux/](examples/flux/) für vollständige FluxCD HelmRelease Beispiele.

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

## 📦 Konfiguration

### Runtime-Auswahl

| Parameter | Beschreibung | Default |
|-----------|-------------|---------|
| `php.enabled` | PHP Runtime aktivieren | `false` |
| `nodejs.enabled` | Node.js Runtime aktivieren | `false` |

### Datenbank

| Parameter | Beschreibung | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | PostgreSQL Sub-Chart aktivieren | `false` |
| `mariadb.enabled` | MariaDB Sub-Chart aktivieren | `false` |

> **Hinweis:** Es kann nur eine Datenbank gleichzeitig aktiviert werden.

Die Datenbank-Verbindungsdaten werden automatisch als Environment-Variablen in alle aktivierten Runtimes injiziert:
- `DB_CONNECTION` – Datenbanktyp (`pgsql` oder `mysql`)
- `DB_HOST` – Hostname
- `DB_PORT` – Port
- `DB_DATABASE` – Datenbankname
- `DB_USERNAME` – Benutzername
- `DB_PASSWORD` – Passwort (aus Secret)

### PHP Konfiguration

| Parameter | Beschreibung | Default |
|-----------|-------------|---------|
| `php.image.repository` | PHP Image | `""` |
| `php.image.tag` | Image Tag | `latest` |
| `php.replicaCount` | Anzahl Replicas | `1` |
| `php.resources` | Resource Limits | `200m/256Mi` |
| `php.nginx.image.tag` | Nginx Sidecar Version | `1.27-alpine` |
| `php.ingress.enabled` | Ingress aktivieren | `false` |
| `php.autoscaling.enabled` | HPA aktivieren | `false` |

### Node.js Konfiguration

| Parameter | Beschreibung | Default |
|-----------|-------------|---------|
| `nodejs.image.repository` | Node.js Image | `""` |
| `nodejs.image.tag` | Image Tag | `latest` |
| `nodejs.port` | Application Port | `3000` |
| `nodejs.replicaCount` | Anzahl Replicas | `1` |
| `nodejs.resources` | Resource Limits | `100m/128Mi` |
| `nodejs.ingress.enabled` | Ingress aktivieren | `false` |
| `nodejs.autoscaling.enabled` | HPA aktivieren | `false` |

## 🔧 Verwendungsbeispiele

### Nur PHP mit PostgreSQL

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

### PHP + Node.js (Frontend + API)

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

## 🛡️ Security Features

- **Non-root Container** – Alle Container laufen als UID 1000
- **Capability Dropping** – Minimale Linux Capabilities
- **Security Headers** – X-Frame-Options, X-Content-Type-Options (PHP/Nginx)
- **Resource Limits** – CPU und Memory Constraints
- **ServiceAccount Token** – Automount deaktiviert

## 📚 Dokumentation

- **[Architektur](docs/ARCHITECTURE.md)** – Design-Entscheidungen
- **[Deployment Guide](docs/DEPLOYMENT.md)** – Deployment-Anleitung
- **[Helm Repository Setup](docs/HELM-REPOSITORY.md)** – Repository-Optionen

## 🤝 Contributing

1. Fork des Repositories
2. Feature Branch erstellen
3. Änderungen vornehmen
4. Testen mit `helm lint` und `helm template`
5. Pull Request erstellen

## 📝 Lizenz

MIT License

---

**Built with ❤️ for production Kubernetes deployments**
