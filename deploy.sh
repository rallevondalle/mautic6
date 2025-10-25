#!/bin/bash
# Mautic 6 Quick Deployment Script for mautic6.dubby.online
# Server: 136.144.169.138
# Installation Path: /home/componental

set -e  # Exit on error

echo "=========================================="
echo "Mautic 6 Docker Deployment"
echo "Domain: mautic6.dubby.online"
echo "Path: /home/componental/mautic6"
echo "=========================================="
echo ""

# Step 1: Navigate to Docker projects directory
echo "Step 1: Navigating to /home/componental..."
cd /home/componental

# Step 2: Clone repository (if not exists)
if [ -d "mautic6" ]; then
    echo "Step 2: Directory mautic6 already exists, skipping clone..."
    cd mautic6
    git fetch origin
else
    echo "Step 2: Cloning Mautic 6 repository..."
    git clone https://github.com/rallevondalle/mautic6.git
    cd mautic6
fi

# Step 3: Checkout the Docker branch
echo "Step 3: Checking out Docker-enabled branch..."
git checkout claude/mautic-6-docker-image-011CUUS6hn3Y9SVGjAauUtE8
git pull origin claude/mautic-6-docker-image-011CUUS6hn3Y9SVGjAauUtE8

echo ""
echo "Branch checked out successfully!"
git branch --show-current
echo ""

# Step 4: Configure environment
if [ ! -f .env ]; then
    echo "Step 4: Creating .env file..."
    cp .env.docker.example .env

    # Generate random passwords
    MYSQL_ROOT_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    MAUTIC_DB_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

    # Update .env file with generated passwords and correct settings
    sed -i "s/changeme_root_password/${MYSQL_ROOT_PASS}/" .env
    sed -i "s/changeme_db_password/${MAUTIC_DB_PASS}/" .env
    sed -i "s|MAUTIC_URL=http://localhost:8080|MAUTIC_URL=https://mautic6.dubby.online|" .env
    sed -i "s|MAUTIC_TRUSTED_PROXIES=0.0.0.0/0|MAUTIC_TRUSTED_PROXIES=127.0.0.1,136.144.169.138|" .env

    echo ""
    echo "✅ .env file created with auto-generated passwords!"
    echo ""
    echo "Passwords have been saved to: /home/componental/mautic6/.env"
    echo "MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASS}"
    echo "MAUTIC_DB_PASSWORD: ${MAUTIC_DB_PASS}"
    echo ""
    echo "⚠️  IMPORTANT: Save these passwords somewhere safe!"
    echo ""
    read -p "Press Enter to continue..."
else
    echo "Step 4: .env file already exists, checking configuration..."
    if grep -q "changeme_root_password" .env || grep -q "changeme_db_password" .env; then
        echo ""
        echo "⚠️  WARNING: .env file still has default passwords!"
        echo ""
        echo "Please edit .env and set strong passwords:"
        echo "  nano /home/componental/mautic6/.env"
        echo ""
        echo "Update these values:"
        echo "  - MYSQL_ROOT_PASSWORD"
        echo "  - MAUTIC_DB_PASSWORD"
        echo "  - MAUTIC_URL=https://mautic6.dubby.online"
        echo "  - MAUTIC_TRUSTED_PROXIES=127.0.0.1,136.144.169.138"
        echo ""
        read -p "Press Enter when you've edited the .env file..."
    else
        echo "✅ .env file is configured"
    fi
fi

# Step 5: Build and start Docker containers
echo ""
echo "Step 5: Finding available port and starting Docker containers..."

# Find an available port between 8080-8099
MAUTIC_PORT=""
for port in {8080..8099}; do
    if ! sudo lsof -i :$port > /dev/null 2>&1; then
        MAUTIC_PORT=$port
        echo "Found available port: $MAUTIC_PORT"
        break
    fi
done

if [ -z "$MAUTIC_PORT" ]; then
    echo "ERROR: No available ports found between 8080-8099"
    echo "Please free up a port or modify docker-compose.yml manually"
    exit 1
fi

# Update docker-compose.yml with the available port
sed -i "s/\"[0-9]*:80\"/\"${MAUTIC_PORT}:80\"/" docker-compose.yml
echo "Updated docker-compose.yml to use port ${MAUTIC_PORT}"

echo "Building and starting containers (first build takes 3-5 minutes)..."
docker compose build --no-cache
docker compose up -d

# Step 6: Wait for services to be healthy
echo ""
echo "Step 6: Waiting for services to start..."
sleep 10

# Check container status
docker compose ps

echo ""
echo "=========================================="
echo "✅ Mautic 6 Docker Setup Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo ""
echo "1. Setup Nginx Reverse Proxy:"
echo "   # Update nginx config to use port ${MAUTIC_PORT}"
echo "   sudo sed -i 's/proxy_pass http:\/\/127.0.0.1:[0-9]*/proxy_pass http:\/\/127.0.0.1:${MAUTIC_PORT}/' /home/componental/mautic6/nginx-mautic6.conf"
echo "   sudo cp /home/componental/mautic6/nginx-mautic6.conf /etc/nginx/sites-available/mautic6.dubby.online"
echo "   sudo ln -sf /etc/nginx/sites-available/mautic6.dubby.online /etc/nginx/sites-enabled/"
echo "   sudo nginx -t"
echo "   sudo systemctl reload nginx"
echo ""
echo "2. Setup SSL Certificate:"
echo "   sudo certbot --nginx -d mautic6.dubby.online"
echo ""
echo "3. Access Mautic:"
echo "   https://mautic6.dubby.online"
echo ""
echo "4. Check logs:"
echo "   cd /home/componental/mautic6"
echo "   docker compose logs -f mautic"
echo ""
echo "5. Verify cron jobs:"
echo "   docker compose exec mautic service cron status"
echo "   docker compose exec mautic cat /etc/crontab | grep mautic"
echo ""
echo "For complete documentation, see:"
echo "  /home/componental/mautic6/DEPLOYMENT_GUIDE_mautic6.dubby.online.md"
echo "  /home/componental/mautic6/CRON_JOBS_EXPLAINED.md"
echo ""
