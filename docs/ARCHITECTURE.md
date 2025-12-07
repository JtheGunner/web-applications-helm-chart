# Architecture Documentation

This document explains the architectural decisions behind the web applications Helm chart library system.

## Design Goals

1. **DRY Principle** - Eliminate code duplication across application deployments
2. **Production-Ready** - Security, performance, and reliability out of the box
3. **FluxCD Integration** - GitOps-friendly with minimal configuration
4. **Maintainability** - Easy to understand, debug, and extend
5. **Best Practices** - Follow Kubernetes and Docker community standards

## Architecture Decisions

### 1. Library Chart Pattern

**Decision:** Use Helm library charts instead of a single "universal" chart.

**Rationale:**

❌ **Anti-Pattern (Rejected):**
```yaml
# Single chart with conditional logic
{{- if eq .Values.runtimeMode "php" }}
  # 100 lines of PHP config
{{- else if eq .Values.runtimeMode "node" }}
  # 100 lines of Node config
{{- end }}
```

**Problems:**
- Template hell after adding 3-4 runtime modes
- Difficult to debug (which branch executed?)
- Hard to maintain and test
- Poor developer experience

✅ **Solution: Library Chart Pattern**

```
common-webapp (library) ─┬─> php-webapp (concrete)
                         ├─> node-webapp (concrete)
                         └─> python-webapp (future)
```

**Benefits:**
- Each chart remains simple and focused
- Code reuse through library templates
- Easy to add new runtime types
- Industry standard (used by Bitnami, Gitlab, etc.)

### 2. Multi-Stage Docker Builds

**Decision:** Build assets at Docker build-time, not Kubernetes runtime.

**Rationale:**

❌ **Anti-Pattern (InitContainers):**
```yaml
initContainers:
  - name: build-assets
    command: ["npm", "install", "&&", "npm", "run", "build"]
```

**Problems:**
- Assets rebuilt on **every pod start** (scaling, crashes, updates)
- Slow pod startup (minutes instead of seconds)
- Wasted resources (CPU/memory for NPM during runtime)
- Non-reproducible builds (network issues, version changes)
- Security risk (build tools in production cluster)

✅ **Solution: Multi-Stage Builds**

```dockerfile
# Stage 1: Build assets
FROM node:20-alpine AS builder
RUN npm install && npm run build

# Stage 2: Production
FROM php:8.2-fpm-alpine
COPY --from=builder /build/public/dist ./public/dist
```

**Benefits:**
- Assets compiled once, reused forever
- Fast pod startup (seconds)
- Immutable artifacts (reproducible)
- Smaller production images (no Node.js/NPM)
- Build failures caught before deployment

### 3. PHP-FPM + Nginx Sidecar

**Decision:** Use sidecar pattern for PHP applications.

**Rationale:**

PHP-FPM (FastCGI) cannot serve HTTP directly. Options:

**Option A: PHP Built-in Server**
```yaml
command: ["php", "-S", "0.0.0.0:8000"]
```
❌ Single-threaded, not production-ready

**Option B: Apache + mod_php**
❌ Heavyweight, difficult to configure

**Option C: PHP-FPM + Nginx (Sidecar)** ✅

```yaml
containers:
  - name: php-fpm      # Port 9000
  - name: nginx        # Port 80 (proxies to PHP-FPM)
```

**Benefits:**
- Production-grade performance
- Separate resource limits
- Nginx handles static files efficiently
- Industry standard
- Security headers and rate limiting

### 4. Separate Images per Runtime

**Decision:** No "fat images" containing PHP + Node + Composer.

**Rationale:**

❌ **Fat Image Problems:**
```dockerfile
FROM ubuntu
RUN apt-get install php nodejs composer npm
# Result: 2GB image with huge attack surface
```

- Massive images (slow pulls)
- Security vulnerabilities (unnecessary tools)
- Violates "one concern per container"
- Difficult to maintain

✅ **Solution: Lean, Focused Images**

```dockerfile
# PHP Image
FROM php:8.2-fpm-alpine  # ~80MB

# Node Image
FROM node:20-alpine      # ~120MB
```

**Benefits:**
- Smaller attack surface
- Faster deployments
- Clear separation of concerns
- Easier security updates

### 5. Security Context Defaults

**Decision:** Enforce security contexts by default.

**Implementation:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

**Rationale:**
- Prevents container breakout attacks
- Follows least-privilege principle
- Complies with Pod Security Standards
- Required for many enterprise environments

## Component Interactions

### PHP Application Flow

```
User Request
    ↓
Ingress (TLS termination)
    ↓
Service (port 80)
    ↓
Pod
  ├─ Nginx Container (port 80)
  │    ├─ Serves static files
  │    └─ Proxies *.php to PHP-FPM
  │
  └─ PHP-FPM Container (port 9000)
       └─ Executes PHP code
```

### Node.js Application Flow

```
User Request
    ↓
Ingress (TLS termination)
    ↓
Service (port 80)
    ↓
Pod
  └─ Node.js Container (port 3000)
       └─ Express.js handles request
```

## Resource Architecture

### Shared Resources (Library Chart)

- **Labels and Selectors** - Consistent across all apps
- **Ingress Templates** - TLS, annotations, hosts
- **Service Templates** - ClusterIP, port mapping
- **Security Contexts** - Non-root, capabilities

### Runtime-Specific Resources

**PHP Chart:**
- PHP-FPM deployment
- Nginx ConfigMap
- Sidecar container management

**Node Chart:**
- Single-container deployment
- Environment configuration
- Command overrides

## Scalability Considerations

### Horizontal Scaling

Both charts support Horizontal Pod Autoscaler (HPA):

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
```

**Stateless Design:**
- No local state (files, sessions)
- External databases for persistence
- Shared caching (Redis, Memcached)

### Vertical Scaling

Resource limits per container:

```yaml
resources:
  requests:
    cpu: 250m      # Guaranteed
    memory: 256Mi
  limits:
    cpu: 1000m     # Maximum
    memory: 1Gi
```

## GitOps Integration (FluxCD)

### Repository Structure

```
flux-config/
├── infrastructure/
│   └── helmrepositories/
│       └── web-apps.yaml
│
└── applications/
    ├── production/
    │   ├── app1-release.yaml
    │   └── app2-release.yaml
    └── staging/
        └── app1-release.yaml
```

### Update Flow

```
Developer pushes code
    ↓
CI builds Docker image
    ↓
CI updates HelmRelease (tag: v1.2.3)
    ↓
FluxCD detects change
    ↓
FluxCD applies HelmRelease
    ↓
Kubernetes rolling update
```

## Testing Strategy

### Chart Validation

```bash
# Syntax validation
helm lint charts/php-webapp

# Template rendering
helm template test charts/php-webapp > /tmp/rendered.yaml

# Dry-run install
helm install test charts/php-webapp --dry-run
```

### Docker Build Validation

```bash
# Build image
docker build -t test:latest examples/php-app/

# Security scan
docker scan test:latest

# Size check
docker images test:latest
```

## Future Extensions

### Potential Additions

1. **Python WebApp Chart** - Django, Flask applications
2. **Static Site Chart** - Nginx-only for SPAs
3. **Database Subchart** - Optional PostgreSQL/MySQL
4. **Monitoring Integration** - ServiceMonitor for Prometheus
5. **Network Policies** - Pod-to-pod traffic rules

### Extension Pattern

New charts should:
1. Depend on `common-webapp` library
2. Provide runtime-specific `values.yaml`
3. Include multi-stage Dockerfile example
4. Document health check requirements

## References

- [Helm Library Charts](https://helm.sh/docs/topics/library_charts/)
- [Multi-Stage Docker Builds](https://docs.docker.com/build/building/multi-stage/)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [FluxCD HelmRelease](https://fluxcd.io/docs/components/helm/)

---

**Last Updated:** 2025-12-07
