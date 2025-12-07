# Example Application Docker Images

This directory contains example applications with production-ready multi-stage Dockerfiles.

## PHP Application (`php-app/`)

### Features
- **PHP 8.3 FPM** on Alpine Linux
- **All essential PHP extensions:**
  - `gd` (image processing)
  - `pdo_mysql` (database)
  - `bcmath` (math calculations)
  - `sockets` (network operations)
  - `pcntl` (process control)
  - `intl` (internationalization)
  - `zip` (compression)
  - `opcache` (performance)
- **Development tools:**
  - Composer
  - Node.js & npm (for asset building)
  - Git & SSH client
  - PM2 & Yarn (process managers)
- **Multi-stage build** for optimized image size
- **Non-root user** (UID 1000)

### Build & Run

```bash
cd examples/php-app

# Build image
docker build -t yourorg/php-webapp-example:latest .

# Run locally
docker run -p 9000:9000 yourorg/php-webapp-example:latest

# Test with curl (requires Nginx or PHP built-in server)
# For testing PHP-FPM, deploy to Kubernetes with the php-webapp chart
```

### Image Size
Approximately **150-200MB** (Alpine-based with all extensions)

---

## Node.js Application (`node-app/`)

### Features
- **Node.js 20** on Alpine Linux
- **Express.js** web framework
- **Multi-stage build** for production dependencies only
- **dumb-init** for proper signal handling
- **Non-root user** (UID 1000)
- **Health check endpoints** (`/health`, `/ready`)
- **Graceful shutdown** handling

### Build & Run

```bash
cd examples/node-app

# Build image
docker build -t yourorg/node-webapp-example:latest .

# Run locally
docker run -p 3000:3000 yourorg/node-webapp-example:latest

# Test endpoints
curl http://localhost:3000
curl http://localhost:3000/health
curl http://localhost:3000/api/info
```

### Image Size
Approximately **120-140MB** (Alpine-based with production dependencies)

---

## Publishing Images

### To Docker Hub
```bash
# PHP
docker tag yourorg/php-webapp-example:latest yourorg/php-webapp-example:v1.0.0
docker push yourorg/php-webapp-example:v1.0.0

# Node.js
docker tag yourorg/node-webapp-example:latest yourorg/node-webapp-example:v1.0.0
docker push yourorg/node-webapp-example:v1.0.0
```

### To GitHub Container Registry (GHCR)
```bash
# Login
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# PHP
docker tag yourorg/php-webapp-example:latest ghcr.io/yourorg/php-webapp-example:v1.0.0
docker push ghcr.io/yourorg/php-webapp-example:v1.0.0

# Node.js
docker tag yourorg/node-webapp-example:latest ghcr.io/yourorg/node-webapp-example:v1.0.0
docker push ghcr.io/yourorg/node-webapp-example:v1.0.0
```

---

## Using with Helm Charts

After building and pushing the images:

### PHP Chart
```bash
helm install my-php-app charts/php-webapp \
  --set image.repository=yourorg/php-webapp-example \
  --set image.tag=v1.0.0
```

### Node.js Chart
```bash
helm install my-node-app charts/node-webapp \
  --set image.repository=yourorg/node-webapp-example \
  --set image.tag=v1.0.0
```

---

## Customizing for Your Application

### For PHP Apps

1. **Replace application code**
   - Update `public/index.php` with your application
   - Update `composer.json` with your dependencies
   - Update `package.json` with your frontend dependencies

2. **Adjust PHP settings**
   - Edit `Dockerfile` PHP configuration sections
   - Add/remove PHP extensions as needed

3. **Add additional tools**
   ```dockerfile
   RUN apk add --no-cache \
       your-package-here
   ```

### For Node.js Apps

1. **Replace application code**
   - Update `server.js` with your Express app
   - Update `package.json` with your dependencies

2. **Change port** (if needed)
   ```dockerfile
   ENV PORT=8080
   EXPOSE 8080
   ```

3. **Add build step** (for TypeScript, etc.)
   ```dockerfile
   # In builder stage
   RUN npm run build
   
   # In production stage
   COPY --from=builder /build/dist ./dist
   CMD ["node", "dist/index.js"]
   ```

---

## Best Practices

✅ **Always use specific tags** in production (not `latest`)  
✅ **Scan images for vulnerabilities** (`docker scan`)  
✅ **Keep base images updated** (rebuild regularly)  
✅ **Minimize layer count** (combine RUN commands)  
✅ **Use `.dockerignore`** to exclude unnecessary files  
✅ **Multi-stage builds** for smaller final images  
✅ **Non-root users** for security  
✅ **Health checks** for container orchestration  

---

## Troubleshooting

### Build fails with "no space left on device"
```bash
docker system prune -a
```

### Image size too large
- Check for unnecessary files in COPY commands
- Use `.dockerignore`
- Combine RUN commands to reduce layers

### PHP extensions missing
```bash
# Check installed extensions
docker run yourorg/php-webapp-example:latest php -m
```

### Node.js app crashes on startup
```bash
# Check logs
docker logs <container-id>

# Run interactively
docker run -it yourorg/node-webapp-example:latest sh
```
