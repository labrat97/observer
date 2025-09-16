# Multi-stage build for OpenBroadcaster (observer) with embedded MariaDB

# 1) Build JS bundles
FROM node:20-bookworm AS node_builder
WORKDIR /app
COPY package.json package-lock.json webpack.config.js ./
RUN npm ci --no-audit --no-fund
RUN npm run build

# 2) Install PHP dependencies with Composer
FROM composer:2 AS composer_builder
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --no-progress

# 3) Runtime image with Apache + PHP + MariaDB
FROM php:8.2-apache-bookworm

# Install system deps, MariaDB server/client, and PHP extensions
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      mariadb-server mariadb-client \
      libpng-dev libjpeg62-turbo-dev libfreetype6-dev libonig-dev libxml2-dev libmagickwand-dev \
      ffmpeg vorbis-tools festival imagemagick; \
    a2enmod rewrite headers; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j"$(nproc)" gd mysqli mbstring xml; \
    pecl install imagick; \
    docker-php-ext-enable imagick; \
    rm -rf /var/lib/apt/lists/*

# Copy application source
WORKDIR /var/www/html
COPY . .

# Bring in built dependencies
COPY --from=composer_builder /app/vendor ./vendor
COPY --from=node_builder /app/bundles/chrono-bundle.js ./bundles/chrono-bundle.js
COPY --from=node_builder /app/node_modules ./node_modules

# Ensure CLI is executable and ownership is correct
RUN chmod +x tools/cli/ob && chown -R www-data:www-data /var/www/html

# Single data volume for app data (media, thumbnails, cache, and internal DB)
VOLUME ["/var/ob"]

# Reasonable defaults; no DB configuration required by user
ENV OB_DB_HOST=localhost \
    OB_DB_NAME=observer \
    OB_DB_USER=observer \
    OB_DB_PASS=observer \
    OB_SITE=http://localhost/ \
    OB_EMAIL_FROM=OpenBroadcaster \
    OB_EMAIL_REPLY=noreply@example.com \
    OB_MEDIA_BASE=/var/ob/media \
    OB_THUMBNAILS=/var/ob/thumbnails \
    OB_CACHE=/var/ob/cache \
    OB_ENABLE_CRON_MONITOR=1 \
    OB_RUN_UPDATES_ON_STARTUP=1 \
    OB_FORCE_CONFIG_REGENERATE=0

# Entrypoint boots MariaDB, prepares config, optionally runs updates/cron, then Apache
COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Normalize line endings for critical scripts to avoid bash\r issues on Windows checkouts
RUN set -eux; \
    sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh; \
    if [ -f tools/cli/ob ]; then sed -i 's/\r$//' tools/cli/ob; fi; \
    if [ -f tools/stream/transcode.sh ]; then sed -i 's/\r$//' tools/stream/transcode.sh; fi; \
    if [ -f dev/pre-commit ]; then sed -i 's/\r$//' dev/pre-commit; fi; \
    if [ -f tools/git-hooks/pre-commit ]; then sed -i 's/\r$//' tools/git-hooks/pre-commit; fi

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]
