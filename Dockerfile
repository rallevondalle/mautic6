# Mautic 6 Production Docker Image
FROM php:8.4-apache

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
    libc-client-dev \
    libkrb5-dev \
    unzip \
    cron \
    default-mysql-client \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
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
    imap \
    opcache \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress

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
RUN echo "*/5 * * * * www-data php /var/www/html/bin/console mautic:segments:update > /dev/null 2>&1" >> /etc/crontab \
    && echo "*/5 * * * * www-data php /var/www/html/bin/console mautic:campaigns:update > /dev/null 2>&1" >> /etc/crontab \
    && echo "*/5 * * * * www-data php /var/www/html/bin/console mautic:campaigns:trigger > /dev/null 2>&1" >> /etc/crontab \
    && echo "0 2 * * * www-data php /var/www/html/bin/console mautic:emails:send > /dev/null 2>&1" >> /etc/crontab \
    && echo "*/15 * * * * www-data php /var/www/html/bin/console mautic:email:fetch > /dev/null 2>&1" >> /etc/crontab \
    && echo "*/10 * * * * www-data php /var/www/html/bin/console mautic:webhooks:process > /dev/null 2>&1" >> /etc/crontab \
    && echo "*/5 * * * * www-data php /var/www/html/bin/console mautic:broadcasts:send > /dev/null 2>&1" >> /etc/crontab \
    && echo "0 3 * * * www-data php /var/www/html/bin/console mautic:maintenance:cleanup --days-old=365 > /dev/null 2>&1" >> /etc/crontab

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
