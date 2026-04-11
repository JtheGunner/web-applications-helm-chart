# Architektur-Dokumentation

Dieses Dokument erklärt die Architektur-Entscheidungen des Webapp Helm Charts.

## Design-Ziele

1. **Ein Chart für alles** – Kein Wechsel zwischen Charts nötig
2. **Flexibilität** – PHP, Node.js oder beides konfigurierbar
3. **Datenbank-Integration** – PostgreSQL und MariaDB als Sub-Charts
4. **Production-Ready** – Security, Performance und Reliability out of the box
5. **FluxCD Integration** – GitOps-friendly mit minimaler Konfiguration

## Architektur-Entscheidungen

### 1. Einheitliches Chart statt Library Pattern

**Entscheidung:** Ein einzelnes `webapp` Chart mit Feature-Toggles statt separater Charts.

**Begründung:**

Die Anforderung ist klar: Ein `helm install` soll reichen, um PHP und/oder Node.js mit optionaler Datenbank zu deployen. Das Library-Chart-Pattern (separate `php-webapp`, `node-webapp` Charts) erfordert mehrere Install-Befehle und macht die gemeinsame Datenbank-Nutzung umständlich.

✅ **Lösung: Feature-Toggles**
```yaml
php:
  enabled: true      # PHP aktivieren
nodejs:
  enabled: true      # Node.js aktivieren
postgresql:
  enabled: true      # PostgreSQL aktivieren
```

**Vorteile:**
- Ein einziger `helm install` für alles
- Gemeinsame Datenbank-Konfiguration
- Einfaches FluxCD HelmRelease
- Übersichtliche Values-Struktur

**Warum kein "Conditional Hell"?**
- Nur 2 Runtime-Typen (PHP + Node) – überschaubar
- Die Templates sind getrennt (`deployment-php.yaml`, `deployment-node.yaml`)
- Jede Datei hat nur ein `{{- if .Values.xxx.enabled }}` am Anfang
- Keine verschachtelten Conditionals

### 2. Separate Deployments pro Runtime

**Entscheidung:** PHP und Node.js laufen als separate Kubernetes Deployments.

```
helm install my-app charts/webapp
  │
  ├─ Deployment: my-app-webapp-php
  │   ├─ Container: php-fpm (Port 9000)
  │   └─ Container: nginx (Port 80)
  │
  ├─ Deployment: my-app-webapp-nodejs
  │   └─ Container: nodejs (Port 3000)
  │
  ├─ Service: my-app-webapp-php (Port 80)
  ├─ Service: my-app-webapp-nodejs (Port 80)
  │
  └─ StatefulSet: my-app-postgresql (via Sub-Chart)
```

**Vorteile:**
- Unabhängige Skalierung (PHP und Node haben eigene HPAs)
- Separate Resource Limits
- Getrennte Rollouts (PHP aktualisieren ohne Node neu zu starten)
- Separate Health Checks

### 3. Datenbank als Bitnami Sub-Chart

**Entscheidung:** PostgreSQL und MariaDB werden als Bitnami Sub-Charts eingebunden.

**Begründung:**
- Bitnami Charts sind battle-tested und weit verbreitet
- Automatic Secret-Erstellung für Credentials
- Persistence out of the box
- Helm-native Lifecycle Management

**Automatische Env-Var-Injection:**

Bei aktivierter Datenbank werden folgende Environment-Variablen automatisch in alle Runtime-Container injiziert:

```yaml
DB_CONNECTION: "pgsql"          # oder "mysql"
DB_HOST: "release-postgresql"   # aus Sub-Chart
DB_PORT: "5432"                 # oder "3306"
DB_DATABASE: "webapp"           # aus Values
DB_USERNAME: "webapp"           # aus Values
DB_PASSWORD: <secret>           # aus Bitnami Secret
```

### 4. PHP-FPM + Nginx Sidecar

**Entscheidung:** Sidecar-Pattern für PHP-Applikationen.

PHP-FPM (FastCGI) kann kein HTTP direkt ausliefern. Die Lösung:

```yaml
containers:
  - name: php-fpm      # Port 9000 (FastCGI)
  - name: nginx        # Port 80 (HTTP → FastCGI Proxy)
```

**Vorteile:**
- Production-grade Performance
- Nginx serviert statische Dateien effizient
- Separate Resource Limits
- Security Headers in Nginx

### 5. Per-Runtime Ingress

**Entscheidung:** Jede Runtime hat ihre eigene Ingress-Konfiguration.

```yaml
php:
  ingress:
    hosts:
      - host: app.example.com     # Frontend
nodejs:
  ingress:
    hosts:
      - host: api.example.com     # API
```

Dies ermöglicht:
- Verschiedene Hostnamen pro Runtime
- Pfad-basiertes Routing auf dem gleichen Host
- Separate TLS-Zertifikate
- Runtime-spezifische Ingress-Annotations

### 6. Security Defaults

**Container Security:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

**ServiceAccount:**
```yaml
automountServiceAccountToken: false
```

## Component Flow

### PHP + Node.js + PostgreSQL

```
User Request
    ↓
Ingress (TLS)
    ├─ app.example.com → Service php (Port 80)
    │                       ↓
    │                    Pod (PHP)
    │                    ├─ Nginx (Port 80)
    │                    └─ PHP-FPM (Port 9000) ──→ PostgreSQL
    │
    └─ api.example.com → Service nodejs (Port 80)
                            ↓
                         Pod (Node.js)
                         └─ Node (Port 3000) ──→ PostgreSQL
```

## Validierung

Das Chart validiert die Eingaben:
- Mindestens eine Runtime muss aktiviert sein (`php.enabled` oder `nodejs.enabled`)
- Nur eine Datenbank kann gleichzeitig aktiviert werden

```bash
# Ohne Runtime → Fehler
helm template test charts/webapp
# FEHLER: Mindestens eine Runtime muss aktiviert sein.

# Beide DBs → Fehler
helm template test charts/webapp --set php.enabled=true --set postgresql.enabled=true --set mariadb.enabled=true
# FEHLER: Nur eine Datenbank kann gleichzeitig aktiviert werden.
```

## Testing

```bash
# Lint
helm lint charts/webapp --set php.enabled=true

# Template rendern
helm template test charts/webapp --set php.enabled=true --set php.image.repository=test

# Dry-Run
helm install test charts/webapp --dry-run --set php.enabled=true --set php.image.repository=test
```

---

**Last Updated:** 2026-04-11
