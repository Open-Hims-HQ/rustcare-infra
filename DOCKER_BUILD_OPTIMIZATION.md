# Docker Build Optimization Guide

## Overview

The Docker build process has been optimized for faster builds using Docker BuildKit and proper layer caching.

## Key Optimizations

### 1. BuildKit Cache Mounts
- Cargo registry cache: `/usr/local/cargo/registry`
- Build target cache: `/app/target`
- These caches persist between builds, dramatically reducing build times

### 2. Layer Caching Strategy
- **Layer 1**: Copy only `Cargo.toml` and `Cargo.lock` files
- **Layer 2**: Build dependencies (cached unless Cargo files change)
- **Layer 3**: Copy source code (only invalidates when code changes)
- **Layer 4**: Build application (uses cached dependencies)

### 3. Multi-stage Build
- Builder stage: Compiles the Rust application
- Runtime stage: Minimal Debian image with only runtime dependencies

## Usage

### Enable BuildKit (Required)

BuildKit is automatically enabled in the Makefile, but you can also enable it manually:

```bash
# For docker-compose
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# For docker build directly
DOCKER_BUILDKIT=1 docker build .
```

### Build Commands

```bash
# Standard build (uses BuildKit automatically via Makefile)
make build

# Or manually with docker-compose
DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker-compose build

# Build specific service
DOCKER_BUILDKIT=1 COMPOSE_DOCKER_CLI_BUILD=1 docker-compose build rustcare-server
```

## Performance Improvements

### First Build
- Downloads and compiles all dependencies: ~10-15 minutes
- Compiles application: ~5-10 minutes
- **Total: ~15-25 minutes**

### Subsequent Builds (with code changes)
- Uses cached dependencies: ~30 seconds
- Compiles only changed code: ~2-5 minutes
- **Total: ~3-6 minutes**

### Subsequent Builds (no code changes)
- Uses cached layers: ~10-30 seconds
- **Total: ~10-30 seconds**

## Troubleshooting

### BuildKit Not Enabled
If you see warnings about cache mounts, ensure BuildKit is enabled:
```bash
export DOCKER_BUILDKIT=1
```

### Clear Build Cache
If you encounter build issues, clear the cache:
```bash
docker builder prune
```

### Force Rebuild
To force a complete rebuild without cache:
```bash
docker-compose build --no-cache
```

## Additional Tips

1. **Use specific Rust version**: The Dockerfile uses `rust:1.75-slim` instead of `latest` for reproducible builds
2. **Parallel builds**: BuildKit automatically parallelizes independent build steps
3. **Cache mounts**: Persist between builds, even after container removal
4. **Layer optimization**: Dependencies are built in a separate layer from source code

