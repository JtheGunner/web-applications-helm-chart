# Beispiele

## Values-Dateien

| Datei | Beschreibung |
|-------|-------------|
| [only-php.yaml](only-php.yaml) | Nur PHP Runtime mit PostgreSQL |
| [only-node.yaml](only-node.yaml) | Nur Node.js Runtime mit MariaDB |
| [php-and-node.yaml](php-and-node.yaml) | PHP + Node.js mit PostgreSQL |
| [no-database.yaml](no-database.yaml) | Minimales Deployment ohne Datenbank |

## Verwendung

```bash
# Dependencies aktualisieren
cd charts/webapp
helm dependency update

# Beispiel installieren
helm install my-app charts/webapp -f examples/only-php.yaml
```

## FluxCD Beispiele

Siehe [flux/](flux/) Verzeichnis für FluxCD HelmRelease Beispiele.

## Beispiel-Applikationen

- [php-app/](php-app/) – PHP Beispiel mit Multi-Stage Dockerfile
- [node-app/](node-app/) – Node.js Beispiel mit Express.js
