# Examples

## Values files

| File | Description |
|------|-------------|
| [only-php.yaml](only-php.yaml) | PHP runtime only, with PostgreSQL |
| [only-node.yaml](only-node.yaml) | Node.js runtime only, with MariaDB |
| [php-and-node.yaml](php-and-node.yaml) | PHP + Node.js with PostgreSQL |
| [no-database.yaml](no-database.yaml) | Minimal deployment without a database |
| [git-source-portfolio.yaml](git-source-portfolio.yaml) | PHP app cloned directly from Git (runtime clone, composer install) |
| [git-source-node.yaml](git-source-node.yaml) | Node.js app cloned directly from Git (runtime clone, npm ci) |

## Usage

```bash
# Update dependencies
cd charts/webapp
helm dependency update

# Install an example
helm install my-app charts/webapp -f examples/only-php.yaml
```

## FluxCD examples

See the [flux/](flux/) directory for FluxCD HelmRelease examples.

## Example applications

- [php-app/](php-app/) – PHP example with a multi-stage Dockerfile
- [node-app/](node-app/) – Node.js example with Express.js
