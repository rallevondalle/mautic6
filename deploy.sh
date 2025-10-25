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
    echo ""
    echo "⚠️  IMPORTANT: You need to edit .env with your passwords!"
    echo ""
    echo "Run this command to edit:"
    echo "  nano /home/componental/mautic6/.env"
    echo ""
    echo "Update these values:"
    echo "  - MYSQL_ROOT_PASSWORD (use a strong password)"
    echo "  - MAUTIC_DB_PASSWORD (use a strong password)"
    echo "  - MAUTIC_URL=https://mautic6.dubby.online"
    echo "  - MAUTIC_TRUSTED_PROXIES=127.0.0.1,136.144.169.138"
    echo ""
    read -p "Press Enter when you've edited the .env file..."
else
    echo "Step 4: .env file already exists, skipping..."
fi

# Step 5: Build and start Docker containers
echo ""
echo "Step 5: Building and starting Docker containers..."
echo "This may take several minutes on first run..."
docker compose build
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
echo "   sudo cp /home/componental/mautic6/nginx-mautic6.conf /etc/nginx/sites-available/mautic6.dubby.online"
echo "   sudo ln -s /etc/nginx/sites-available/mautic6.dubby.online /etc/nginx/sites-enabled/"
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
