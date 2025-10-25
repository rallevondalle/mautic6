# Mautic 6 Production Docker Image
# Using PHP 8.3 for better package compatibility and stability
FROM php:8.3-apache

LABEL maintainer="Mautic Community"
LABEL description="Mautic 6 - Open Source Marketing Automation"

# Set working directory
WORKDIR /var/www/html

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    libkrb5-dev \
    unzip \
    cron \
    default-mysql-client \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    mysqli \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip \
    intl \
    opcache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Note: IMAP extension removed for compatibility
# Most Mautic installations use SMTP and don't require IMAP
# If you need IMAP support, you can configure it via Mautic's email settings

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Configure Apache
RUN a2enmod rewrite expires headers ssl

# Copy Apache virtual host configuration
COPY <<EOF /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Configure PHP for production
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.save_comments=1'; \
    } > /usr/local/etc/php/conf.d/opcache.ini

RUN { \
    echo 'memory_limit=512M'; \
    echo 'upload_max_filesize=128M'; \
    echo 'post_max_size=128M'; \
    echo 'max_execution_time=300'; \
    echo 'date.timezone=UTC'; \
    echo 'always_populate_raw_post_data=-1'; \
    } > /usr/local/etc/php/conf.d/mautic.ini

# Copy application files
COPY --chown=www-data:www-data . /var/www/html

# Install PHP dependencies
# Note: Ignoring IMAP platform requirement as it's not critical for most Mautic deployments
# Using --no-scripts to skip npm-related post-install scripts (not needed for production)
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress --ignore-platform-req=ext-imap --no-scripts

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/var/cache \
    && chmod -R 775 /var/www/html/var/logs \
    && chmod -R 775 /var/www/html/var/spool \
    && chmod -R 775 /var/www/html/media/files \
    && chmod -R 775 /var/www/html/media/images \
    && chmod -R 775 /var/www/html/translations

# Setup cron for Mautic background jobs
# These cron jobs are CRITICAL for Mautic to function properly
# All jobs run as www-data user to maintain proper file permissions
RUN { \
    echo '# Mautic Cron Jobs Configuration'; \
    echo '# Format: minute hour day month weekday user command'; \
    echo ''; \
    echo '# SEGMENTS UPDATE - Updates contact segments based on filters'; \
    echo '# Runs every 5 minutes to keep segments current'; \
    echo '# This ensures contacts are added/removed from segments in near real-time'; \
    echo '*/5 * * * * www-data php /var/www/html/bin/console mautic:segments:update --no-interaction 2>&1 | logger -t mautic-segments'; \
    echo ''; \
    echo '# CAMPAIGNS UPDATE - Processes campaign membership'; \
    echo '# Runs every 5 minutes to add contacts to campaigns'; \
    echo '# Determines which contacts should enter or exit campaigns'; \
    echo '*/5 * * * * www-data php /var/www/html/bin/console mautic:campaigns:update --no-interaction 2>&1 | logger -t mautic-campaigns'; \
    echo ''; \
    echo '# CAMPAIGNS TRIGGER - Executes campaign actions'; \
    echo '# Runs every 5 minutes to process campaign events'; \
    echo '# Sends emails, updates contact fields, executes campaign logic'; \
    echo '*/5 * * * * www-data php /var/www/html/bin/console mautic:campaigns:trigger --no-interaction 2>&1 | logger -t mautic-triggers'; \
    echo ''; \
    echo '# EMAIL QUEUE PROCESSING - Sends queued marketing emails'; \
    echo '# Runs every 5 minutes for optimal delivery'; \
    echo '# Processes email queue and sends scheduled emails to contacts'; \
    echo '# More frequent = faster delivery, adjust based on email volume'; \
    echo '*/5 * * * * www-data php /var/www/html/bin/console mautic:emails:send --no-interaction 2>&1 | logger -t mautic-emails'; \
    echo ''; \
    echo '# MONITORED INBOX - Fetches emails from monitored mailboxes'; \
    echo '# Runs every 15 minutes to check for bounces and replies'; \
    echo '# Processes bounce notifications and unsubscribe requests'; \
    echo '*/15 * * * * www-data php /var/www/html/bin/console mautic:email:fetch --no-interaction 2>&1 | logger -t mautic-fetch'; \
    echo ''; \
    echo '# WEBHOOKS - Processes outgoing webhook queue'; \
    echo '# Runs every 10 minutes to send webhook data to integrations'; \
    echo '# Delivers contact and activity data to external systems'; \
    echo '*/10 * * * * www-data php /var/www/html/bin/console mautic:webhooks:process --no-interaction 2>&1 | logger -t mautic-webhooks'; \
    echo ''; \
    echo '# BROADCASTS - Sends broadcast/notification messages'; \
    echo '# Runs every 5 minutes to process mobile and web notifications'; \
    echo '# Handles push notifications and in-app messages'; \
    echo '*/5 * * * * www-data php /var/www/html/bin/console mautic:broadcasts:send --no-interaction 2>&1 | logger -t mautic-broadcasts'; \
    echo ''; \
    echo '# SOCIAL MONITORING - Processes social media monitoring'; \
    echo '# Runs every 15 minutes to check social media channels'; \
    echo '# Monitors Twitter, Facebook, and other social platforms'; \
    echo '*/15 * * * * www-data php /var/www/html/bin/console mautic:social:monitoring --no-interaction 2>&1 | logger -t mautic-social'; \
    echo ''; \
    echo '# IMPORT PROCESSING - Processes contact imports'; \
    echo '# Runs every 5 minutes to handle CSV/file imports in background'; \
    echo '# Continues processing large import files'; \
    echo '*/5 * * * * www-data php /var/www/html/bin/console mautic:import --no-interaction 2>&1 | logger -t mautic-import'; \
    echo ''; \
    echo '# QUEUE PROCESSING - Processes message queues (if using queue)'; \
    echo '# Runs every minute for high-priority async tasks'; \
    echo '# Handles asynchronous operations for better performance'; \
    echo '* * * * * www-data php /var/www/html/bin/console mautic:queue:process --no-interaction 2>&1 | logger -t mautic-queue'; \
    echo ''; \
    echo '# MAINTENANCE CLEANUP - Removes old data'; \
    echo '# Runs daily at 3 AM to clean up old statistics and visitor data'; \
    echo '# Keeps database size manageable by removing data older than 365 days'; \
    echo '# Adjust --days-old parameter based on your data retention policy'; \
    echo '0 3 * * * www-data php /var/www/html/bin/console mautic:maintenance:cleanup --days-old=365 --no-interaction 2>&1 | logger -t mautic-cleanup'; \
    echo ''; \
    echo '# UNUSED IP CLEANUP - Removes unused IP address records'; \
    echo '# Runs daily at 2 AM to clean up IP address database'; \
    echo '0 2 * * * www-data php /var/www/html/bin/console mautic:unusedip:delete --no-interaction 2>&1 | logger -t mautic-ipcleanup'; \
    echo ''; \
    } >> /etc/crontab

# Create entrypoint script
COPY <<'EOF' /entrypoint.sh
#!/bin/bash
set -e

# Start cron service
service cron start

# Execute the original command
exec apache2-foreground
EOF

RUN chmod +x /entrypoint.sh

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
