# Mautic 6 Cron Jobs - Complete Guide

This document explains all the cron jobs configured in the Mautic 6 Docker image and their importance.

## Overview

Mautic requires cron jobs to function properly. These background tasks handle everything from sending emails to updating contact segments. **Without cron jobs, Mautic will not send emails or process campaigns.**

All cron jobs are automatically configured in the Docker container and run as the `www-data` user with proper logging.

## Configured Cron Jobs (12 Total)

### 1. Segments Update
```bash
*/5 * * * * php bin/console mautic:segments:update
```
- **Frequency**: Every 5 minutes
- **Purpose**: Updates contact segments based on filters
- **Why it matters**: Ensures contacts are automatically added/removed from segments in near real-time based on their attributes and behavior
- **Example**: If a contact's status changes to "customer", they'll be added to the "customers" segment within 5 minutes

### 2. Campaigns Update
```bash
*/5 * * * * php bin/console mautic:campaigns:update
```
- **Frequency**: Every 5 minutes
- **Purpose**: Processes campaign membership
- **Why it matters**: Adds contacts to campaigns they qualify for and removes those who no longer qualify
- **Example**: When a contact joins a segment that triggers a campaign, they'll enter that campaign within 5 minutes

### 3. Campaigns Trigger
```bash
*/5 * * * * php bin/console mautic:campaigns:trigger
```
- **Frequency**: Every 5 minutes
- **Purpose**: Executes campaign actions and decision points
- **Why it matters**: This is what actually sends campaign emails, updates fields, sends webhooks, and executes campaign logic
- **Example**: After a contact enters a campaign, this job sends the welcome email, waits for opens/clicks, and processes the next steps
- **Critical**: Without this, campaigns won't execute any actions!

### 4. Email Queue Processing
```bash
*/5 * * * * php bin/console mautic:emails:send
```
- **Frequency**: Every 5 minutes
- **Purpose**: Sends queued marketing emails
- **Why it matters**: Processes the email queue and sends scheduled emails to contacts
- **Critical for**: Email broadcasts, campaign emails, segment emails
- **Note**: Frequency can be adjusted based on email volume:
  - High volume: Every 1-2 minutes
  - Normal volume: Every 5 minutes (default)
  - Low volume: Every 10-15 minutes

### 5. Monitored Inbox Processing
```bash
*/15 * * * * php bin/console mautic:email:fetch
```
- **Frequency**: Every 15 minutes
- **Purpose**: Fetches emails from monitored mailboxes
- **Why it matters**: Processes bounce notifications, unsubscribe requests, and email replies
- **Critical for**: Email deliverability, maintaining clean lists, bounce handling
- **Example**: If someone replies to unsubscribe, this processes it and removes them from your list

### 6. Webhooks Processing
```bash
*/10 * * * * php bin/console mautic:webhooks:process
```
- **Frequency**: Every 10 minutes
- **Purpose**: Processes outgoing webhook queue
- **Why it matters**: Sends contact and activity data to external systems and integrations
- **Example**: Sends new contact data to your CRM, e-commerce platform, or analytics tools

### 7. Broadcasts Send
```bash
*/5 * * * * php bin/console mautic:broadcasts:send
```
- **Frequency**: Every 5 minutes
- **Purpose**: Sends broadcast and notification messages
- **Why it matters**: Handles push notifications, SMS broadcasts, and web notifications
- **Example**: Sends mobile push notifications to your app users

### 8. Social Monitoring
```bash
*/15 * * * * php bin/console mautic:social:monitoring
```
- **Frequency**: Every 15 minutes
- **Purpose**: Monitors social media channels
- **Why it matters**: Tracks mentions, hashtags, and social interactions
- **Example**: Adds contacts who mention your brand on Twitter

### 9. Import Processing
```bash
*/5 * * * * php bin/console mautic:import
```
- **Frequency**: Every 5 minutes
- **Purpose**: Processes contact imports in background
- **Why it matters**: Continues processing large CSV/file imports without timing out
- **Example**: Importing a 50,000 contact CSV file processes in batches

### 10. Queue Processing
```bash
* * * * * php bin/console mautic:queue:process
```
- **Frequency**: Every minute
- **Purpose**: Processes message queues for high-priority async tasks
- **Why it matters**: Handles asynchronous operations for better performance
- **Best for**: High-traffic installations using queue-based processing
- **Note**: Only active if you've configured queue processing in Mautic settings

### 11. Maintenance Cleanup
```bash
0 3 * * * php bin/console mautic:maintenance:cleanup --days-old=365
```
- **Frequency**: Daily at 3:00 AM
- **Purpose**: Removes old data and statistics
- **Why it matters**: Keeps database size manageable and performance optimal
- **Configurable**: Adjust `--days-old` parameter based on your data retention policy
- **Example**: Removes visitor tracking data older than 365 days

### 12. Unused IP Cleanup
```bash
0 2 * * * php bin/console mautic:unusedip:delete
```
- **Frequency**: Daily at 2:00 AM
- **Purpose**: Removes unused IP address records
- **Why it matters**: Cleans up the IP address database table to prevent bloat
- **Example**: Removes IP records that aren't associated with any contacts or visits

## Critical Cron Jobs

These three are **absolutely essential** for Mautic to function:

1. **mautic:campaigns:trigger** - Without this, campaigns don't execute
2. **mautic:emails:send** - Without this, emails don't send
3. **mautic:segments:update** - Without this, segments don't update

## Monitoring Cron Jobs

### Check Cron Status
```bash
docker compose exec mautic service cron status
```

### View Cron Configuration
```bash
docker compose exec mautic cat /etc/crontab | grep mautic
```

### Monitor Cron Execution
```bash
# View real-time logs
docker compose exec mautic tail -f /var/log/syslog | grep mautic

# Or use logger tags
journalctl -f | grep mautic
```

### Manually Run a Cron Job (for testing)
```bash
# Test segments update
docker compose exec mautic php bin/console mautic:segments:update -v

# Test email sending
docker compose exec mautic php bin/console mautic:emails:send -v

# Test campaign processing
docker compose exec mautic php bin/console mautic:campaigns:trigger -v
```

## Customizing Cron Schedules

If you need to adjust the frequency of cron jobs, edit the `Dockerfile` before building:

### Example: Increase Email Sending Frequency
Change from every 5 minutes to every 2 minutes for high-volume sending:
```bash
# From:
*/5 * * * * www-data php /var/www/html/bin/console mautic:emails:send

# To:
*/2 * * * * www-data php /var/www/html/bin/console mautic:emails:send
```

### Example: Reduce Queue Processing Load
Change from every minute to every 5 minutes if not using queue:
```bash
# From:
* * * * * www-data php /var/www/html/bin/console mautic:queue:process

# To:
*/5 * * * * www-data php /var/www/html/bin/console mautic:queue:process
```

## Cron Schedule Format

```
*    *    *    *    *
┬    ┬    ┬    ┬    ┬
│    │    │    │    │
│    │    │    │    └───── Day of week (0-7) (Sunday = 0 or 7)
│    │    │    └────────── Month (1-12)
│    │    └─────────────── Day of month (1-31)
│    └──────────────────── Hour (0-23)
└───────────────────────── Minute (0-59)
```

### Common Patterns
- `* * * * *` - Every minute
- `*/5 * * * *` - Every 5 minutes
- `*/15 * * * *` - Every 15 minutes
- `0 * * * *` - Every hour
- `0 2 * * *` - Every day at 2:00 AM
- `0 0 * * 0` - Every Sunday at midnight

## Troubleshooting

### Cron jobs not running?

1. **Check cron service is running:**
   ```bash
   docker compose exec mautic service cron status
   ```

2. **Restart cron service:**
   ```bash
   docker compose exec mautic service cron restart
   ```

3. **Check for errors in logs:**
   ```bash
   docker compose logs mautic | grep -i error
   ```

4. **Manually test a cron command:**
   ```bash
   docker compose exec -u www-data mautic php bin/console mautic:emails:send -v
   ```

### Emails not sending?

1. Check email configuration in Mautic Settings
2. Verify `mautic:emails:send` cron is running
3. Check email queue in Mautic (Channels → Emails → Email Queue)
4. Send a test email manually:
   ```bash
   docker compose exec mautic php bin/console mautic:emails:send --limit=10 -v
   ```

### Campaigns not executing?

1. Verify all three campaign crons are running
2. Check campaign logic and publish status
3. Manually trigger campaigns:
   ```bash
   docker compose exec mautic php bin/console mautic:campaigns:update -v
   docker compose exec mautic php bin/console mautic:campaigns:trigger -v
   ```

## Performance Optimization

### For High-Volume Installations

If you're sending 100,000+ emails or processing large contact databases:

1. **Increase email sending frequency:**
   ```bash
   */2 * * * * # Every 2 minutes instead of 5
   ```

2. **Add batch size limits:**
   ```bash
   php bin/console mautic:emails:send --limit=500
   ```

3. **Use queue-based processing:**
   - Configure Redis queue in Mautic settings
   - Enable queue processing cron (runs every minute)

4. **Stagger cron jobs:**
   - Don't run all jobs at the same time (e.g., :00, :05, :10)
   - Spread them out (e.g., :02, :07, :12)

### For Low-Volume Installations

If you have fewer than 10,000 contacts and low email volume:

1. **Reduce cron frequency:**
   ```bash
   */10 * * * * # Every 10 minutes instead of 5
   ```

2. **Disable unused jobs:**
   - Comment out social monitoring if not using
   - Reduce queue processing if not configured

## Best Practices

1. **Always run cron as www-data user** - Prevents permission issues
2. **Use --no-interaction flag** - Prevents cron from hanging
3. **Log cron output** - Use logger or redirect to files for debugging
4. **Monitor cron execution** - Set up alerts if crons fail
5. **Test after changes** - Always test manually before relying on cron
6. **Keep default timings** - Unless you have specific performance needs
7. **Don't over-optimize** - More frequent isn't always better (server load)

## Official Documentation

For more information, see:
- Mautic Cron Jobs: https://docs.mautic.org/en/setup/cron-jobs
- Symfony Console Commands: https://symfony.com/doc/current/console.html

---

**Last Updated:** 2025-10-25
**Mautic Version:** 6.x
**Docker Image:** PHP 8.4 Apache
