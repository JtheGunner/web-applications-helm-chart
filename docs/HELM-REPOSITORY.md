# Helm Repository Setup

## Option 1: Local use (development)

### Install directly from the local directory

```bash
# Update chart dependencies
cd charts/webapp
helm dependency update

# Install directly
helm install my-app charts/webapp \
  --set php.enabled=true \
  --set php.image.repository=jthegunner/my-php-app \
  --set php.image.tag=latest

# Or with a values file
helm install my-app charts/webapp -f examples/only-php.yaml
```

---

## Option 2: OCI registry (production — recommended)

### Charts as OCI artifacts in GitHub Container Registry

#### 1. Package and push the chart

```bash
# Log in to GitHub Container Registry
echo $GITHUB_TOKEN | helm registry login ghcr.io -u USERNAME --password-stdin

# Update dependencies and package the chart
helm dependency update charts/webapp
helm package charts/webapp

# Push to GHCR
helm push webapp-1.0.0.tgz oci://ghcr.io/jthegunner
```

#### 2. Install from the OCI registry

```bash
# Helm 3.8+ supports OCI natively
helm install my-app oci://ghcr.io/jthegunner/webapp \
  --version 1.0.0 \
  -f values.yaml
```

---

## Option 3: FluxCD with OCI registry (GitOps — recommended for production)

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

## Option 4: FluxCD with a Git repository

### 1. Create a GitRepository

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

### 2. HelmRelease with a Git source

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

## Comparing the options

| Option | Development | Production | Complexity |
|--------|-------------|------------|------------|
| **Local** | ✅ Perfect | ❌ | ⭐ Very simple |
| **OCI registry** | ✅ Good | ✅ Perfect | ⭐⭐⭐ Medium |
| **FluxCD + OCI** | ❌ | ✅ Perfect | ⭐⭐⭐⭐ Advanced |
| **FluxCD + Git** | ❌ | ✅ Good | ⭐⭐⭐ Medium |

---

## CI/CD: automatic chart publishing

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

### Chart not found

```bash
# Test the OCI registry directly
helm show chart oci://ghcr.io/jthegunner/webapp
```

### Missing dependencies

```bash
helm dependency update charts/webapp
helm dependency list charts/webapp
```

### FluxCD can't find the chart

```bash
kubectl describe helmrepository -n flux-system web-applications-charts
flux reconcile source helm web-applications-charts
```
