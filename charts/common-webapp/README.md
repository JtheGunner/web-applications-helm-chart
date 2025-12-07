# Common WebApp Library Chart

A Helm library chart providing reusable Kubernetes templates for web applications.

## Overview

This is a **library chart** (type: library) that cannot be installed directly. It provides shared templates consumed by application charts like `php-webapp` and `node-webapp`.

## Template Reference

### Helpers (`_helpers.tpl`)

#### `common-webapp.name`
Returns the chart name or override.

#### `common-webapp.fullname`
Returns the fully qualified application name.

#### `common-webapp.labels`
Standard Kubernetes labels for all resources.

#### `common-webapp.selectorLabels`
Pod selector labels.

#### `common-webapp.image`
Constructs the full image name from registry, repository, and tag.

#### `common-webapp.imagePullPolicy`
Determines the image pull policy (defaults to `Always` for `latest` tag).

### Templates

#### `_deployment.tpl`
Reusable deployment template with:
- Pod security context
- Init containers support
- Container injection
- Volume mounting
- Health probes
- Resource limits

#### `_service.tpl`
Service template with configurable type and ports.

#### `_ingress.tpl`
Ingress template supporting:
- Multiple hosts and paths
- TLS configuration
- Custom annotations (cert-manager, etc.)

#### `_configmap.tpl`
ConfigMap for application configuration.

## Usage in Consuming Charts

### 1. Add Dependency

In your chart's `Chart.yaml`:
```yaml
dependencies:
  - name: common-webapp
    version: "1.0.0"
    repository: "file://../common-webapp"
```

### 2. Use Templates

In your templates:
```yaml
{{ include "common-webapp.service" . }}
```

### 3. Update Dependencies

```bash
helm dependency update
```

## Required Values

Consuming charts must provide:
- `image.repository`
- `image.tag`
- `service.port`
- `service.targetPort`

See `values.yaml` for complete reference.

## Example

```yaml
apiVersion: v2
name: my-webapp
dependencies:
  - name: common-webapp
    version: "1.0.0"
    repository: "file://../common-webapp"
```

## Security Defaults

- **Container Security Context:**
  - `runAsNonRoot: true`
  - `runAsUser: 1000`
  - `allowPrivilegeEscalation: false`
  - Capabilities dropped: `ALL`

- **Pod Security Context:**
  - `fsGroup: 1000`

## License

MIT
