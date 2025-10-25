# Mautic 6 Deployment Guide for mautic6.dubby.online

This is your step-by-step deployment guide for setting up Mautic 6 on your Ubuntu Server VPS.

**Server Details:**
- IP Address: 136.144.169.138
- Domain: mautic6.dubby.online
- Platform: Ubuntu Server with Docker

## Prerequisites Check

```bash
# SSH into your server
ssh root@136.144.169.138

# Check Docker installation
docker --version
docker compose version

# If Docker is not installed, run:
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

## Step 1: Clone Mautic 6 Repository

```bash
# Clone to your server
cd /opt
git clone https://github.com/rallevondalle/mautic6.git
cd mautic6
git checkout claude/mautic-6-docker-image-011CUUS6hn3Y9SVGjAauUtE8
```

## Step 2: Configure Environment Variables

```bash
# Copy the example environment file
cp .env.docker.example .env

# Edit with your secure passwords
nano .env
```

Update `.env` with these values:

```bash
# Database Configuration - USE STRONG PASSWORDS!
MYSQL_ROOT_PASSWORD=YourSecureRootPassword123!
MAUTIC_DB_NAME=mautic
MAUTIC_DB_USER=mautic
MAUTIC_DB_PASSWORD=YourSecureMauticPassword456!

# Mautic Configuration
MAUTIC_URL=https://mautic6.dubby.online

# For Nginx reverse proxy, trust the proxy IP
MAUTIC_TRUSTED_PROXIES=127.0.0.1,136.144.169.138
```

## Step 3: Build and Start Mautic

```bash
# Build the Docker image (first time only)
docker compose build

# Start all services
docker compose up -d

# Check that containers are running
docker compose ps

# View logs
docker compose logs -f mautic
```

Expected output:
```
NAME                IMAGE               STATUS
mautic6             mautic:6            Up (healthy)
mautic6_db          mariadb:10.11       Up (healthy)
mautic6_redis       redis:7-alpine      Up (healthy)
```

## Step 4: Configure Nginx Reverse Proxy

```bash
# Copy the nginx configuration
cp /opt/mautic6/nginx-mautic6.conf /etc/nginx/sites-available/mautic6.dubby.online

# Create symlink to enable the site
ln -s /etc/nginx/sites-available/mautic6.dubby.online /etc/nginx/sites-enabled/

# Test nginx configuration
nginx -t

# If test passes, reload nginx
systemctl reload nginx
```

## Step 5: Configure DNS

Make sure your domain DNS is pointing to your server:

```bash
# Check DNS resolution
dig mautic6.dubby.online

# Should show:
# mautic6.dubby.online.  IN  A  136.144.169.138
```

If not configured, add an A record:
- Type: A
- Name: mautic6
- Value: 136.144.169.138
- TTL: 3600

## Step 6: Setup SSL Certificate (Let's Encrypt)

```bash
# Install certbot
apt update
apt install certbot python3-certbot-nginx -y

# Obtain SSL certificate
certbot --nginx -d mautic6.dubby.online

# Follow the prompts and select:
# - Enter your email address
# - Agree to terms
# - Choose whether to redirect HTTP to HTTPS (recommended: Yes)

# Verify auto-renewal is configured
certbot renew --dry-run
```

After SSL is setup, edit `/etc/nginx/sites-available/mautic6.dubby.online`:
- Comment out the HTTP server block
- Uncomment the HTTPS server block

Then reload nginx:
```bash
systemctl reload nginx
```

## Step 7: Complete Mautic Installation Wizard

1. Open your browser and navigate to: `https://mautic6.dubby.online`

2. Follow the installation wizard:

### Database Configuration
- **Database Driver**: MySQL PDO
- **Database Host**: `db`
- **Database Port**: `3306`
- **Database Name**: `mautic`
- **Database Username**: `mautic`
- **Database Password**: (use the password from your `.env` file)
- **Database Table Prefix**: (leave empty or use custom prefix)

### Admin User Setup
- Create your admin username and password
- Enter your email address

### Email Configuration
You can configure this later, or set it up now:
- SMTP Host: (your email provider's SMTP)
- SMTP Port: 587 (for TLS) or 465 (for SSL)
- Encryption: TLS or SSL
- Username: your email address
- Password: your email password or app password

### Cache Configuration (Recommended)
In Mautic settings after installation:
1. Go to Settings → Configuration → System Settings
2. Cache:
   - Cache Driver: Redis
   - Redis Host: `redis`
   - Redis Port: `6379`

## Step 8: Verify Cron Jobs

```bash
# Check cron is running in container
docker compose exec mautic service cron status

# View cron configuration
docker compose exec mautic cat /etc/crontab | grep mautic

# Monitor cron execution (check system logs)
docker compose exec mautic tail -f /var/log/syslog | grep mautic
```

You should see cron jobs running every few minutes.

## Step 9: Configure Firewall

```bash
# Allow HTTP, HTTPS, and SSH
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall
ufw enable

# Check status
ufw status
```

## Step 10: Initial Configuration in Mautic

After logging in to Mautic:

1. **Configuration → System Settings**
   - Site URL: `https://mautic6.dubby.online`
   - Cache: Redis (as configured above)

2. **Configuration → Email Settings**
   - Configure your SMTP settings
   - Send a test email to verify

3. **Configuration → Queue Settings** (Optional but recommended)
   - Queue Protocol: Redis
   - Redis Host: `redis`
   - Redis Port: `6379`

## Verification Checklist

- [ ] Docker containers are running and healthy
- [ ] Nginx is configured and running
- [ ] SSL certificate is active (HTTPS works)
- [ ] Mautic installation wizard completed
- [ ] Admin user can log in
- [ ] Email sending works (test email sent)
- [ ] Cron jobs are running (check logs)
- [ ] Firewall is configured
- [ ] DNS is pointing to correct IP

## Monitoring and Maintenance

### Check Docker Container Status
```bash
docker compose ps
docker compose logs mautic --tail=100
```

### Check Disk Usage
```bash
df -h
docker system df
```

### Backup Database
```bash
# Create backup directory
mkdir -p /opt/mautic-backups

# Backup database
docker compose exec db mysqldump -u mautic -p mautic > /opt/mautic-backups/mautic_$(date +%Y%m%d_%H%M%S).sql

# Backup media files
docker compose exec mautic tar czf /tmp/media_backup.tar.gz /var/www/html/media
docker compose cp mautic:/tmp/media_backup.tar.gz /opt/mautic-backups/media_$(date +%Y%m%d_%H%M%S).tar.gz
```

### Update Mautic
```bash
cd /opt/mautic6
git pull origin claude/mautic-6-docker-image-011CUUS6hn3Y9SVGjAauUtE8
docker compose build
docker compose up -d
docker compose exec mautic php bin/console cache:clear
```

### Monitor Logs
```bash
# All logs
docker compose logs -f

# Mautic only
docker compose logs -f mautic

# Nginx logs
tail -f /var/log/nginx/mautic6_access.log
tail -f /var/log/nginx/mautic6_error.log
```

## Troubleshooting

### Issue: Cannot access Mautic

```bash
# Check containers are running
docker compose ps

# Check nginx is running
systemctl status nginx

# Check firewall
ufw status

# Check DNS
dig mautic6.dubby.online
```

### Issue: Database connection error

```bash
# Check database container
docker compose logs db

# Verify database credentials in .env file
cat .env | grep DB

# Restart database
docker compose restart db
```

### Issue: Emails not sending

```bash
# Check cron is running
docker compose exec mautic service cron status

# Manually trigger email queue
docker compose exec mautic php bin/console mautic:emails:send

# Check email configuration in Mautic settings
```

### Issue: Slow performance

```bash
# Check if Redis is running
docker compose exec redis redis-cli ping

# Clear cache
docker compose exec mautic php bin/console cache:clear --env=prod

# Check disk space
df -h
```

## Security Best Practices

1. **Keep passwords secure**: Never commit `.env` file to version control
2. **Regular updates**: Update Docker images and Mautic regularly
3. **Monitor logs**: Check for suspicious activity
4. **Backup regularly**: Automate daily backups
5. **Use strong passwords**: For admin users and database
6. **Enable 2FA**: In Mautic admin settings if available
7. **Limit SSH access**: Use SSH keys, disable password authentication
8. **Keep SSL certificate current**: Certbot auto-renewal should handle this

## Support Resources

- Mautic Documentation: https://docs.mautic.org
- Community Forum: https://forum.mautic.org
- GitHub Issues: https://github.com/mautic/mautic/issues

## Next Steps After Deployment

1. Import your contacts from Mautic 5 (if migrating)
2. Create your first segment
3. Build a campaign
4. Set up landing pages
5. Configure tracking code for your websites
6. Test email deliverability
7. Configure DKIM/SPF records for better email delivery

---

**Deployment Date:** _____________
**Deployed By:** _____________
**Notes:** _____________
