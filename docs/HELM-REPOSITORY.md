# Helm Repository Setup

## Option 1: Lokale Verwendung (Development)

### Direkt aus dem lokalen Verzeichnis

```bash
# Chart Dependencies aktualisieren
cd charts/webapp
helm dependency update

# Direkt installieren
helm install my-app charts/webapp \
  --set php.enabled=true \
  --set php.image.repository=jthegunner/my-php-app \
  --set php.image.tag=latest

# Oder mit Values-Datei
helm install my-app charts/webapp -f examples/only-php.yaml
```

---

## Option 2: OCI Registry (Production – Empfohlen)

### Charts als OCI Artifacts in GitHub Container Registry

#### 1. Chart packen und pushen

```bash
# Login zu GitHub Container Registry
echo $GITHUB_TOKEN | helm registry login ghcr.io -u USERNAME --password-stdin

# Dependencies aktualisieren und Chart packen
helm dependency update charts/webapp
helm package charts/webapp

# Pushen zu GHCR
helm push webapp-1.0.0.tgz oci://ghcr.io/jthegunner
```

#### 2. Installation aus OCI Registry

```bash
# Helm 3.8+ unterstützt OCI nativ
helm install my-app oci://ghcr.io/jthegunner/webapp \
  --version 1.0.0 \
  -f values.yaml
```

---

## Option 3: FluxCD mit OCI Registry (GitOps – Empfohlen für Production)

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
  url: oci://ghcr.io/jthegunner
```

### 2. HelmRelease erstellen

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
        repository: jthegunner/my-php-app
        tag: "v1.0.0"
    postgresql:
      enabled: true
      auth:
        database: myapp
        username: myapp
        password: changeme
```

---

## Option 4: FluxCD mit Git Repository

### 1. GitRepository erstellen

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: web-applications-charts
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/jthegunner/web-applications-helm-chart
  ref:
    branch: main
```

### 2. HelmRelease mit Git Source

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
      chart: charts/webapp
      sourceRef:
        kind: GitRepository
        name: web-applications-charts
        namespace: flux-system

  values:
    php:
      enabled: true
      image:
        repository: jthegunner/my-php-app
        tag: "v1.0.0"
```

---

## Vergleich der Optionen

| Option | Development | Production | Komplexität |
|--------|-------------|------------|-------------|
| **Lokal** | ✅ Perfekt | ❌ | ⭐ Sehr einfach |
| **OCI Registry** | ✅ Gut | ✅ Perfekt | ⭐⭐⭐ Mittel |
| **FluxCD + OCI** | ❌ | ✅ Perfekt | ⭐⭐⭐⭐ Fortgeschritten |
| **FluxCD + Git** | ❌ | ✅ Gut | ⭐⭐⭐ Mittel |

---

## CI/CD: Automatisches Chart Publishing

**GitHub Actions: `.github/workflows/publish-charts.yaml`**

```yaml
name: Publish Helm Charts

on:
  push:
    branches:
      - main
    paths:
      - 'charts/**'

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Helm
        uses: azure/setup-helm@v3

      - name: Login to GHCR
        run: |
          echo ${{ secrets.GITHUB_TOKEN }} | helm registry login ghcr.io -u ${{ github.actor }} --password-stdin

      - name: Package and Push Chart
        run: |
          helm dependency update charts/webapp
          helm package charts/webapp
          helm push webapp-*.tgz oci://ghcr.io/$(echo "${{ github.repository_owner }}" | tr '[:upper:]' '[:lower:]')/helm-charts
```

---

## Troubleshooting

### Chart nicht gefunden

```bash
# OCI Registry direkt testen
helm show chart oci://ghcr.io/jthegunner/webapp
```

### Dependencies fehlen

```bash
helm dependency update charts/webapp
helm dependency list charts/webapp
```

### FluxCD findet Chart nicht

```bash
kubectl describe helmrepository -n flux-system web-applications-charts
flux reconcile source helm web-applications-charts
```
