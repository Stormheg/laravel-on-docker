# START OF THE INSTALLER
# This container is used during the build process only and exists to not bloat the main container
FROM composer:1.8.0 as installer

# COMPOSER BE FAST
RUN composer global require hirak/prestissimo --no-plugins --no-scripts

COPY composer.json composer.json
COPY composer.lock composer.lock
RUN composer install --prefer-dist --no-scripts --no-dev --no-autoloader

# Copy the app source code
COPY . ./
RUN composer dump-autoload --no-scripts --no-dev --optimize

# END OF THE INSTALLER


# START OF THE MAIN CONTAINER
# Comes with php and nginx preinstalled
FROM stormheg/nginx-php7-alpine:latest

# You can change a limited number of PHP and nginx settings here
ENV PHP_MEMORY_LIMIT=128m

# Configures PHP and nginx settings. Very important! DO NOT FORGET
RUN /etc/configure.sh

# Our application lives here...
WORKDIR /app
COPY --from=installer /app/ /app/
# Cram everything into a single layer
RUN chown -R nginx:nginx /app/storage /app/bootstrap/cache && \
    mkdir -p /app/storage/framework/cache/data && \
    php artisan storage:link && \
    chmod -R 775 /app/storage && echo "php artisan config:cache && php artisan migrate" >> pre_start.sh
    # You can echo any commands you want to pre_start.sh script. `artisan config:cache` is included here because the app key is not correctly setup otherwise.
    # example `echo "php artisan migrate" >> pre_start.sh`

# The stormheg/nginx-php7-alpine container comes with a build-in dummy healthcheck at /_healthcheck/
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 CMD curl --fail http://127.0.0.1:8080/_healthcheck/ || exit 1

# Supervisord runs the pre_start.sh script when the container is spun up.
# It is also responsible for keeping nginx and PHP alive.
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor.conf"]
