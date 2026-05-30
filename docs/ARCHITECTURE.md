# Architecture Documentation

This document explains the architecture decisions behind the webapp Helm chart.

## Design goals

1. **One chart for everything** – no need to switch between charts
2. **Flexibility** – PHP, Node.js, or both, all configurable
3. **Database integration** – PostgreSQL and MariaDB as sub-charts
4. **Production-ready** – security, performance, and reliability out of the box
5. **FluxCD integration** – GitOps-friendly with minimal configuration

## Architecture decisions

### 1. Unified chart instead of a library pattern

**Decision:** a single `webapp` chart with feature toggles instead of separate charts.

**Rationale:**

The requirement is clear: a single `helm install` should be enough to deploy PHP and/or Node.js with an optional database. The library-chart pattern (separate `php-webapp`, `node-webapp` charts) requires multiple install commands and makes shared database usage awkward.

✅ **Solution: feature toggles**
```yaml
php:
  enabled: true      # enable PHP
nodejs:
  enabled: true      # enable Node.js
postgresql:
  enabled: true      # enable PostgreSQL
```

**Advantages:**
- One `helm install` for everything
- Shared database configuration
- Simple FluxCD HelmRelease
- Tidy values structure

**Why no "conditional hell"?**
- Only 2 runtime types (PHP + Node) — manageable
- Templates are split (`deployment-php.yaml`, `deployment-node.yaml`)
- Each file has a single `{{- if .Values.xxx.enabled }}` at the top
- No nested conditionals

### 2. Separate deployments per runtime

**Decision:** PHP and Node.js run as separate Kubernetes Deployments.

```
helm install my-app charts/webapp
  │
  ├─ Deployment: my-app-webapp-php
  │   ├─ Container: php-fpm (port 9000)
  │   └─ Container: nginx (port 80)
  │
  ├─ Deployment: my-app-webapp-nodejs
  │   └─ Container: nodejs (port 3000)
  │
  ├─ Service: my-app-webapp-php (port 80)
  ├─ Service: my-app-webapp-nodejs (port 80)
  │
  └─ StatefulSet: my-app-postgresql (via sub-chart)
```

**Advantages:**
- Independent scaling (PHP and Node each get their own HPA)
- Separate resource limits
- Separate rollouts (update PHP without restarting Node)
- Separate health checks

### 3. Database as a Bitnami sub-chart

**Decision:** PostgreSQL and MariaDB are pulled in as Bitnami sub-charts.

**Rationale:**
- Bitnami charts are battle-tested and widely adopted
- Automatic secret creation for credentials
- Persistence out of the box
- Helm-native lifecycle management

**Automatic env-var injection:**

When a database is enabled, the following environment variables are injected automatically into every runtime container:

```yaml
DB_CONNECTION: "pgsql"          # or "mysql"
DB_HOST: "release-postgresql"   # from the sub-chart
DB_PORT: "5432"                 # or "3306"
DB_DATABASE: "webapp"           # from values
DB_USERNAME: "webapp"           # from values
DB_PASSWORD: <secret>           # from the Bitnami secret
```

### 4. PHP-FPM + Nginx sidecar

**Decision:** sidecar pattern for PHP applications.

PHP-FPM (FastCGI) cannot serve HTTP directly. The solution:

```yaml
containers:
  - name: php-fpm      # port 9000 (FastCGI)
  - name: nginx        # port 80 (HTTP → FastCGI proxy)
```

**Advantages:**
- Production-grade performance
- Nginx serves static files efficiently
- Separate resource limits
- Security headers in Nginx

### 5. Per-runtime Ingress

**Decision:** each runtime has its own Ingress configuration.

```yaml
php:
  ingress:
    hosts:
      - host: app.example.com     # frontend
nodejs:
  ingress:
    hosts:
      - host: api.example.com     # API
```

This allows:
- Different host names per runtime
- Path-based routing on the same host
- Separate TLS certificates
- Runtime-specific Ingress annotations

### 6. App source: image vs. Git (runtime clone)

**Decision:** per runtime, choose whether the app code comes from the
container image (default) or is cloned from a Git repo at pod start.

```yaml
php:
  app:
    source: image   # default: code from the runtime image
    # source: git   # alternative: clone at runtime
```

**Why offer Git source at all?**

To deploy several small webapps from a single chart without maintaining a
build pipeline per app. `git push` + pod restart is enough. Especially
useful for internal/personal apps.

**How it works (source=git):**

1. The `app-files` volume (emptyDir) is created and mounted into PHP-FPM,
   Nginx, and — if present — the build container.
2. Init container **`git-clone`** (image: `alpine/git`) clones the repo
   into `/app-files`. For private repos: an SSH key from a Kubernetes Secret.
3. Init container **`app-build`** runs the build step.
   For **PHP**, this is enabled by default and runs (in the `composer:2` image):
   ```
   git config --global --add safe.directory '*' \
     && composer install --no-dev --optimize-autoloader \
        --no-interaction --ignore-platform-reqs
   ```
   The `safe.directory` line avoids "dubious ownership" errors when the
   build container's UID differs from git-clone's. `--ignore-platform-reqs`
   is needed because the slim composer image lacks extensions like
   `ext-intl` that apps usually require — those must instead be present in
   the RUNTIME PHP-FPM image. For **Node.js**, build is opt-in
   (`nodejs.app.build.enabled: true` + a `command`).
4. Runtime containers (PHP-FPM, Nginx, Node) start with the files ready.

**Trade-offs:**

| | source=image | source=git |
|---|---|---|
| Pod start | seconds | 10–60 s depending on repo + build |
| Reproducibility | immutable image tag | pin `git.ref` to a SHA |
| Build pipeline | one per app required | none required |
| Build-failure visibility | in CI | only at deploy time |
| Best for | production, scaling | dev, personal apps, many small services |

**Recommendation:** `source=image` for anything with real traffic;
`source=git` for convenience deployments. In Git mode, pin `git.ref` to a
tag or SHA, not `main` — otherwise every pod restart pulls the current
branch head.

### 7. Security defaults

**Container security (PHP-FPM):**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 33     # www-data in the official php:*-fpm images
  runAsGroup: 33
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
```

**Container security (Node.js):**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000   # "node" in the official node:*-alpine images
  runAsGroup: 1000
```

> For custom images, make sure the configured UID/GID has write
> permissions on `/var/www/html` (PHP) or on the app working directory
> (Node). Otherwise adjust `php.securityContext.runAsUser` or
> `nodejs.securityContext.runAsUser`.

**ServiceAccount:**
```yaml
automountServiceAccountToken: false   # on both the ServiceAccount and the pod spec
```

## Component flow

### PHP + Node.js + PostgreSQL

```
User request
    ↓
Ingress (TLS)
    ├─ app.example.com → Service php (port 80)
    │                       ↓
    │                    Pod (PHP)
    │                    ├─ Nginx (port 80)
    │                    └─ PHP-FPM (port 9000) ──→ PostgreSQL
    │
    └─ api.example.com → Service nodejs (port 80)
                            ↓
                         Pod (Node.js)
                         └─ Node (port 3000) ──→ PostgreSQL
```

## Validation

The chart validates inputs:
- At least one runtime must be enabled (`php.enabled` or `nodejs.enabled`)
- Only one database can be enabled at a time

```bash
# No runtime → error
helm template test charts/webapp
# ERROR: at least one runtime must be enabled.

# Both DBs → error
helm template test charts/webapp \
  --set php.enabled=true --set php.image.repository=test \
  --set postgresql.enabled=true --set mariadb.enabled=true
# ERROR: only one database can be enabled at a time.

# Missing image → required-error
helm template test charts/webapp --set php.enabled=true
# Error: php.image.repository is required when php.enabled=true
```

## Testing

```bash
# Lint
helm lint charts/webapp --set php.enabled=true --set php.image.repository=test

# Render templates (working minimal setup)
helm template test charts/webapp \
  --set php.enabled=true \
  --set php.image.repository=jthegunner/my-php-app \
  --set php.image.tag=v1.0.0

# Full setup with example values
helm dependency update charts/webapp
helm template test charts/webapp -f examples/php-and-node.yaml

# Dry run against a real cluster
helm install test charts/webapp --dry-run \
  --set php.enabled=true \
  --set php.image.repository=jthegunner/my-php-app
```

---

**Last updated:** 2026-04-11
