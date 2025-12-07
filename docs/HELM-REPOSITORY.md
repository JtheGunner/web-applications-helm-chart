# Helm Repository Setup

## Option 1: Lokale Verwendung (Development)

### Direkt aus dem lokalen Verzeichnis

```bash
# Charts dependencies aktualisieren
helm dependency update charts/php-webapp
helm dependency update charts/node-webapp

# Direkt installieren
helm install my-app charts/php-webapp \
  --set image.repository=jthegunner/php-composer-npm-amd \
  --set image.tag=latest

# Oder mit values.yaml
helm install my-app charts/php-webapp -f my-values.yaml
```

---

## Option 2: Git Repository (Development/Staging)

### Helm kann direkt aus Git installieren

```bash
# Direkt aus GitHub
helm install my-app \
  git+https://github.com/jthegunner/web-applications-helm-chart@charts/php-webapp

# Mit spezifischer Version/Branch
helm install my-app \
  git+https://github.com/jthegunner/web-applications-helm-chart@charts/php-webapp?ref=v1.0.0
```

---

## Option 3: OCI Registry (Production - Empfohlen)

### Charts als OCI Artifacts in GitHub Container Registry

#### 1. Charts packen und pushen

```bash
# Login zu GitHub Container Registry
echo $GITHUB_TOKEN | helm registry login ghcr.io -u USERNAME --password-stdin

# Charts packen
helm package charts/common-webapp
helm package charts/php-webapp
helm package charts/node-webapp

# Pushen zu GHCR
helm push common-webapp-1.0.0.tgz oci://ghcr.io/jthegunner/helm-charts
helm push php-webapp-1.0.0.tgz oci://ghcr.io/jthegunner/helm-charts
helm push node-webapp-1.0.0.tgz oci://ghcr.io/jthegunner/helm-charts
```

#### 2. Installation aus OCI Registry

```bash
# Helm 3.8+ unterstützt OCI nativ
helm install my-app oci://ghcr.io/jthegunner/helm-charts/php-webapp \
  --version 1.0.0

# Mit values
helm install my-app oci://ghcr.io/jthegunner/helm-charts/php-webapp \
  --version 1.0.0 \
  -f values.yaml
```

---

## Option 4: FluxCD HelmRepository (GitOps - Empfohlen für Production)

### 1. HelmRepository erstellen

**Datei: `flux-system/sources/helm-charts-repo.yaml`**

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: web-applications-charts
  namespace: flux-system
spec:
  interval: 5m
  # Option A: OCI Registry (empfohlen)
  type: oci
  url: oci://ghcr.io/jthegunner/helm-charts
  
  # Optional: Authentication für private Registry
  # secretRef:
  #   name: ghcr-auth
```

**Alternative mit Git:**

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
  ignore: |
    /*
    !/charts/
```

### 2. HelmRelease erstellen

**Datei: `clusters/production/helmreleases/my-app.yaml`**

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
      # Für OCI Registry
      chart: php-webapp
      version: "1.0.0"
      sourceRef:
        kind: HelmRepository
        name: web-applications-charts
        namespace: flux-system
      
      # Für Git Repository
      # chart: charts/php-webapp
      # sourceRef:
      #   kind: GitRepository
      #   name: web-applications-charts
      #   namespace: flux-system
  
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

### 3. Deployen

```bash
# FluxCD erkennt automatisch die HelmRelease
kubectl apply -f flux-system/sources/helm-charts-repo.yaml
kubectl apply -f clusters/production/helmreleases/my-app.yaml

# Status überprüfen
kubectl get helmrelease -n webhosting
flux get helmreleases -n webhosting
```

---

## Option 5: Helm HTTP Server (Klassisch)

### 1. Chart Museum oder GitHub Pages

**Mit GitHub Pages:**

```bash
# Chart packen
helm package charts/php-webapp -d packages/
helm package charts/node-webapp -d packages/

# Index erstellen
helm repo index packages/ --url https://jthegunner.github.io/helm-charts

# Zu gh-pages branch pushen
git checkout gh-pages
cp -r packages/* .
git add .
git commit -m "Update charts"
git push
```

### 2. Repository hinzufügen

```bash
# Lokal
helm repo add jthegunner https://jthegunner.github.io/helm-charts
helm repo update

# Installieren
helm install my-app jthegunner/php-webapp
```

### 3. FluxCD HelmRepository

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: jthegunner-charts
  namespace: flux-system
spec:
  interval: 5m
  url: https://jthegunner.github.io/helm-charts
```

---

## Vergleich der Optionen

| Option | Development | Staging | Production | Komplexität |
|--------|-------------|---------|------------|-------------|
| **Lokal** | ✅ Perfekt | ❌ | ❌ | ⭐ Sehr einfach |
| **Git** | ✅ Gut | ✅ Gut | ⚠️ Geht | ⭐⭐ Einfach |
| **OCI Registry** | ✅ Gut | ✅ Sehr gut | ✅ Perfekt | ⭐⭐⭐ Mittel |
| **FluxCD** | ❌ | ✅ Sehr gut | ✅ Perfekt | ⭐⭐⭐⭐ Fortgeschritten |
| **HTTP Server** | ⚠️ | ✅ Gut | ✅ Gut | ⭐⭐⭐ Mittel |

---

## Empfohlener Workflow

```
Development (Lokal)
    ↓
helm install my-app charts/php-webapp
    ↓
Commit & Push Charts
    ↓
CI/CD packt Charts → OCI Registry
    ↓
FluxCD deployed automatisch
    ↓
Production
```

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
      
      - name: Package and Push Charts
        run: |
          for chart in charts/*/; do
            if [ -f "$chart/Chart.yaml" ]; then
              helm package "$chart"
              chart_name=$(basename "$chart")
              helm push ${chart_name}-*.tgz oci://ghcr.io/${{ github.repository_owner }}/helm-charts
            fi
          done
```

**Jetzt:** Git Push → Charts automatisch in Registry!

---

## Troubleshooting

### Chart nicht gefunden

```bash
# Cache clearen
helm repo update

# OCI Registry direkt testen
helm show chart oci://ghcr.io/jthegunner/helm-charts/php-webapp
```

### FluxCD findet Chart nicht

```bash
# HelmRepository Status
kubectl describe helmrepository -n flux-system web-applications-charts

# Reconcile forcieren
flux reconcile source helm web-applications-charts
```

### Dependencies fehlen

```bash
# Dependencies updaten
helm dependency update charts/php-webapp

# Dependencies checken
helm dependency list charts/php-webapp
```
