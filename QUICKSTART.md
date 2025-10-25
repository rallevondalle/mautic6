# Mautic 6 Quick Start Guide

**Server:** 136.144.169.138
**Domain:** mautic6.dubby.online
**Install Path:** /home/componental/mautic6

---

## One-Command Installation

SSH to your server and run:

```bash
curl -fsSL https://raw.githubusercontent.com/rallevondalle/mautic6/claude/mautic-6-docker-image-011CUUS6hn3Y9SVGjAauUtE8/deploy.sh | bash
```

**Or** follow the manual steps below:

---

## Manual Installation (5 Steps)

### 1. Clone the Repository

```bash
cd /home/componental
git clone https://github.com/rallevondalle/mautic6.git
cd mautic6
git checkout claude/mautic-6-docker-image-011CUUS6hn3Y9SVGjAauUtE8
```

### 2. Configure Environment

```bash
cp .env.docker.example .env
nano .env
```

**Update these values in .env:**
```bash
MYSQL_ROOT_PASSWORD=YourStrongPassword123!
MAUTIC_DB_PASSWORD=YourStrongPassword456!
MAUTIC_URL=https://mautic6.dubby.online
MAUTIC_TRUSTED_PROXIES=127.0.0.1,136.144.169.138
```

### 3. Start Mautic

```bash
docker compose up -d --build
```

Wait 2-3 minutes for containers to start, then check:
```bash
docker compose ps
```

All services should show "Up (healthy)".

### 4. Setup Nginx Reverse Proxy

```bash
sudo cp /home/componental/mautic6/nginx-mautic6.conf /etc/nginx/sites-available/mautic6.dubby.online
sudo ln -s /etc/nginx/sites-available/mautic6.dubby.online /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 5. Setup SSL Certificate

```bash
sudo certbot --nginx -d mautic6.dubby.online
```

Follow the prompts and choose "Yes" to redirect HTTP to HTTPS.

---

## Access Mautic

Open your browser: **https://mautic6.dubby.online**

### Installation Wizard Settings:

**Database Configuration:**
- Host: `db`
- Port: `3306`
- Database Name: `mautic`
- Username: `mautic`
- Password: (the password from your .env file)

**Cache Configuration (Recommended):**
- Cache Driver: `Redis`
- Redis Host: `redis`
- Redis Port: `6379`

---

## Verify Everything Works

### Check Docker Containers
```bash
cd /home/componental/mautic6
docker compose ps
```

### Check Cron Jobs (Critical for Email Sending!)
```bash
docker compose exec mautic service cron status
docker compose exec mautic cat /etc/crontab | grep mautic
```

### Check Logs
```bash
docker compose logs -f mautic
```

### Test Email Queue (Manual)
```bash
docker compose exec mautic php bin/console mautic:emails:send -v
```

---

## Common Commands

### View Logs
```bash
cd /home/componental/mautic6
docker compose logs -f
```

### Restart Mautic
```bash
docker compose restart
```

### Stop Mautic
```bash
docker compose stop
```

### Start Mautic
```bash
docker compose start
```

### Update Mautic
```bash
cd /home/componental/mautic6
git pull origin claude/mautic-6-docker-image-011CUUS6hn3Y9SVGjAauUtE8
docker compose build
docker compose up -d
docker compose exec mautic php bin/console cache:clear
```

### Backup Database
```bash
mkdir -p /home/componental/mautic-backups
docker compose exec db mysqldump -u mautic -p mautic > /home/componental/mautic-backups/mautic_$(date +%Y%m%d).sql
```

---

## Important Notes

✅ **Cron Jobs:** 12 background jobs run automatically for:
   - Email sending (every 5 min)
   - Campaign processing (every 5 min)
   - Segment updates (every 5 min)
   - See `CRON_JOBS_EXPLAINED.md` for details

✅ **Backups:** Run backups regularly (database + media files)

✅ **SSL:** Required for production use

✅ **Firewall:** Allow ports 22, 80, 443

---

## Troubleshooting

**Can't access Mautic?**
```bash
# Check containers
docker compose ps

# Check nginx
sudo systemctl status nginx

# Check firewall
sudo ufw status
```

**Emails not sending?**
```bash
# Check cron
docker compose exec mautic service cron status

# Manually send
docker compose exec mautic php bin/console mautic:emails:send -v
```

**Database errors?**
```bash
# Check database
docker compose logs db

# Restart database
docker compose restart db
```

---

## Full Documentation

- **Complete Deployment Guide:** `DEPLOYMENT_GUIDE_mautic6.dubby.online.md`
- **Cron Jobs Explained:** `CRON_JOBS_EXPLAINED.md`
- **General Docker Guide:** `DOCKER_DEPLOYMENT.md`

---

## Support

- Mautic Docs: https://docs.mautic.org
- Community Forum: https://forum.mautic.org
- GitHub: https://github.com/mautic/mautic

---

**Ready to deploy? Start with Step 1!** 🚀
