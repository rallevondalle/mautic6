#!/bin/bash
# Emergency fix for Docker build issue
# This script pulls the latest fixes and rebuilds

set -e

echo "=========================================="
echo "Mautic 6 Docker Build Fix"
echo "=========================================="
echo ""

cd /home/componental/mautic6

# Stop any running containers
echo "Stopping any running containers..."
docker compose down 2>/dev/null || true

# Pull latest fixes
echo "Pulling latest fixes from GitHub..."
git fetch origin
git reset --hard origin/claude/mautic-6-docker-image-011CUUS6hn3Y9SVGjAauUtE8

# Clean Docker build cache
echo "Cleaning Docker build cache..."
docker builder prune -f

# Verify Dockerfile shows PHP 8.3
echo ""
echo "Verifying Dockerfile (should show PHP 8.3):"
head -3 Dockerfile
echo ""

# Check if .env exists and is configured
if [ ! -f .env ] || grep -q "changeme" .env; then
    echo "Creating/updating .env file with secure passwords..."
    cp .env.docker.example .env

    # Generate strong passwords
    MYSQL_ROOT_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    MAUTIC_DB_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

    # Update .env
    sed -i "s/changeme_root_password/${MYSQL_ROOT_PASS}/" .env
    sed -i "s/changeme_db_password/${MAUTIC_DB_PASS}/" .env
    sed -i "s|MAUTIC_URL=http://localhost:8080|MAUTIC_URL=https://mautic6.dubby.online|" .env
    sed -i "s|MAUTIC_TRUSTED_PROXIES=0.0.0.0/0|MAUTIC_TRUSTED_PROXIES=127.0.0.1,136.144.169.138|" .env

    echo ""
    echo "=========================================="
    echo "⚠️  IMPORTANT - SAVE THESE PASSWORDS!"
    echo "=========================================="
    echo "MySQL Root Password: ${MYSQL_ROOT_PASS}"
    echo "Mautic DB Password:  ${MAUTIC_DB_PASS}"
    echo "=========================================="
    echo ""
    echo "These passwords are also saved in: /home/componental/mautic6/.env"
    echo ""
fi

# Build with no cache to ensure fresh build
echo "Building Docker image (this will take a few minutes)..."
docker compose build --no-cache

# Start containers
echo "Starting containers..."
docker compose up -d

# Wait for services
echo "Waiting for services to start..."
sleep 15

# Check status
echo ""
echo "=========================================="
echo "Container Status:"
echo "=========================================="
docker compose ps

echo ""
echo "✅ Build complete! Check if all containers show 'Up (healthy)'"
echo ""
echo "If you see errors, check logs with:"
echo "  docker compose logs -f"
