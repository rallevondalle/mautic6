# Mautic 6 Docker Deployment Guide

This guide will help you deploy Mautic 6 using Docker on your Ubuntu Server VPS.

## Prerequisites

- Docker Engine 20.10+ installed
- Docker Compose V2 installed
- At least 2GB RAM (4GB recommended)
- 10GB+ free disk space

## Quick Start

### 1. Clone or Download Mautic 6

```bash
git clone https://github.com/mautic/mautic.git mautic6
cd mautic6
git checkout 7.x  # or the latest stable branch
```

### 2. Configure Environment Variables

Copy the example environment file and update with your values:

```bash
cp .env.docker.example .env
nano .env  # or use your preferred editor
```

Update the following values in `.env`:
- `MYSQL_ROOT_PASSWORD` - Strong password for MySQL root user
- `MAUTIC_DB_PASSWORD` - Strong password for Mautic database user
- `MAUTIC_URL` - Your domain URL (e.g., https://mautic.yourdomain.com)
- `MAUTIC_TRUSTED_PROXIES` - If behind a proxy/load balancer

### 3. Build and Start the Containers

```bash
docker compose up -d --build
```

This will:
- Build the Mautic 6 Docker image
- Start MariaDB 10.11 database
- Start Redis cache
- Start Mautic web application on port 8080

### 4. Access Mautic

Open your browser and navigate to:
- Local: `http://localhost:8080`
- VPS: `http://your-server-ip:8080`

Follow the installation wizard to complete the setup.

## Installation Wizard Configuration

When you first access Mautic, you'll see the installation wizard. Use these settings:

### Database Configuration
- **Database Driver**: MySQL PDO
- **Database Host**: `db`
- **Database Port**: `3306`
- **Database Name**: `mautic` (or value from .env)
- **Database Username**: `mautic` (or value from .env)
- **Database Password**: Use the password from `.env` (MAUTIC_DB_PASSWORD)

### Cache Configuration (Optional but Recommended)
- **Cache Driver**: Redis
- **Redis Host**: `redis`
- **Redis Port**: `6379`

## Production Deployment Tips

### Using a Reverse Proxy (Recommended)

For production, use a reverse proxy like Nginx or Traefik with SSL:

#### Example Nginx Configuration

```nginx
server {
    listen 80;
    server_name mautic.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name mautic.yourdomain.com;

    ssl_certificate /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Change the Default Port

To use a different port, edit `docker-compose.yml`:

```yaml
services:
  mautic:
    ports:
      - "8080:80"  # Change 8080 to your preferred port
```

### Persistent Data

The following volumes are created to persist your data:
- `mautic_data` - Application data, cache, logs
- `mautic_media` - Uploaded media files
- `mautic_config` - Configuration files
- `db_data` - Database files
- `redis_data` - Redis cache data

## Management Commands

### View Logs

```bash
# All services
docker compose logs -f

# Mautic only
docker compose logs -f mautic

# Database only
docker compose logs -f db
```

### Stop Mautic

```bash
docker compose stop
```

### Start Mautic

```bash
docker compose start
```

### Restart Mautic

```bash
docker compose restart
```

### Update Mautic

```bash
# Pull latest code
git pull origin 7.x

# Rebuild and restart
docker compose up -d --build

# Clear cache
docker compose exec mautic php bin/console cache:clear
```

### Backup

#### Backup Database

```bash
docker compose exec db mysqldump -u mautic -p mautic > mautic_backup_$(date +%Y%m%d).sql
```

#### Backup Files

```bash
docker compose exec mautic tar czf /tmp/mautic_files_$(date +%Y%m%d).tar.gz /var/www/html/media
docker compose cp mautic:/tmp/mautic_files_$(date +%Y%m%d).tar.gz .
```

### Restore Database

```bash
docker compose exec -T db mysql -u mautic -p mautic < mautic_backup_20250101.sql
```

## Cron Jobs

The Docker image includes pre-configured cron jobs for:
- Segment updates (every 5 minutes)
- Campaign updates (every 5 minutes)
- Campaign triggers (every 5 minutes)
- Email sending (2 AM daily)
- Email fetching (every 15 minutes)
- Webhook processing (every 10 minutes)
- Broadcast sending (every 5 minutes)
- Maintenance cleanup (3 AM daily)

You can verify cron is running:

```bash
docker compose exec mautic service cron status
```

## Troubleshooting

### Container won't start

Check logs:
```bash
docker compose logs mautic
```

### Database connection errors

Verify database is ready:
```bash
docker compose exec db mysql -u mautic -p -e "SHOW DATABASES;"
```

### Permission issues

Fix permissions:
```bash
docker compose exec mautic chown -R www-data:www-data /var/www/html
docker compose exec mautic chmod -R 775 /var/www/html/var
```

### Clear cache

```bash
docker compose exec mautic php bin/console cache:clear --env=prod
```

### Run Mautic console commands

```bash
docker compose exec mautic php bin/console [command]
```

Example:
```bash
docker compose exec mautic php bin/console mautic:segments:update
```

## System Requirements

### Minimum
- 2 CPU cores
- 2GB RAM
- 10GB storage

### Recommended
- 4+ CPU cores
- 4GB+ RAM
- 50GB+ storage (depending on data volume)
- SSD storage for better performance

## Security Recommendations

1. Use strong passwords in `.env`
2. Keep Docker and images updated
3. Use SSL/TLS (HTTPS) in production
4. Configure firewall rules
5. Regular backups
6. Limit exposed ports
7. Use specific trusted proxy IPs instead of 0.0.0.0/0
8. Monitor logs regularly

## Upgrading from Mautic 5

If you're migrating from Mautic 5:

1. Backup your Mautic 5 database
2. Backup your Mautic 5 media files
3. Deploy Mautic 6 using this Docker setup
4. Restore your database backup
5. Restore your media files
6. Run database migrations:
   ```bash
   docker compose exec mautic php bin/console doctrine:migrations:migrate --no-interaction
   ```
7. Clear cache:
   ```bash
   docker compose exec mautic php bin/console cache:clear
   ```

## Support

- Documentation: https://docs.mautic.org
- Community Forum: https://forum.mautic.org
- GitHub Issues: https://github.com/mautic/mautic/issues
- Slack Community: https://mautic.org/slack

## License

Mautic is open source software licensed under the GPL v3.0.
