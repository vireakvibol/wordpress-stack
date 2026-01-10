#!/bin/bash
set -e

# Custom entrypoint for WordPress Stack
# Starts MariaDB (using original entrypoint) and OpenLiteSpeed

echo "=== WordPress Stack Starting ==="

# Validate required environment variables
MISSING_VARS=""
[ -z "$MARIADB_DATABASE" ] && MISSING_VARS="$MISSING_VARS MARIADB_DATABASE"
[ -z "$MARIADB_USER" ] && MISSING_VARS="$MISSING_VARS MARIADB_USER"
[ -z "$MARIADB_PASSWORD" ] && MISSING_VARS="$MISSING_VARS MARIADB_PASSWORD"

if [ -n "$MISSING_VARS" ]; then
    echo "ERROR: Required environment variables are not set:$MISSING_VARS"
    echo "Please provide:"
    echo "  -e MARIADB_DATABASE=your_database"
    echo "  -e MARIADB_USER=your_user"
    echo "  -e MARIADB_PASSWORD=your_password"
    exit 1
fi

# Generate random root password if not set (and not allowing empty)
if [ -z "$MARIADB_ROOT_PASSWORD" ] && [ -z "$MARIADB_ALLOW_EMPTY_ROOT_PASSWORD" ] && [ -z "$MARIADB_RANDOM_ROOT_PASSWORD" ]; then
    export MARIADB_ROOT_PASSWORD=$(openssl rand -hex 16)
    echo "GENERATED ROOT PASSWORD: $MARIADB_ROOT_PASSWORD"
fi

# Check if wp-content is an empty volume (missing plugins/themes) and populate from image backup
if [ -d "/usr/src/wordpress/wp-content" ]; then
    if [ ! -d "/var/www/vhosts/localhost/html/wp-content/plugins" ] || [ -z "$(ls -A /var/www/vhosts/localhost/html/wp-content/plugins)" ]; then
        echo "Populating wp-content volume from image backup..."
        # Copy plugins and themes. Use -n to not overwrite if exists? No, cp -r merges.
        cp -rn /usr/src/wordpress/wp-content/* /var/www/vhosts/localhost/html/wp-content/
        
        # Ensure permissions
        chown -R nobody:nogroup /var/www/vhosts/localhost/html/wp-content
    fi
fi

# Start MariaDB in background using original entrypoint
echo "Starting MariaDB..."
docker-entrypoint.sh "$@" &
MARIADB_PID=$!

# Wait for MariaDB to be ready (wait for TCP connection to ensure real server is up, not temp)
echo "Waiting for MariaDB to be ready..."
for i in {1..60}; do
    if mariadb-admin ping -h 127.0.0.1 --silent 2>/dev/null; then
        echo "MariaDB is ready!"
        break
    fi
    sleep 1
done

# Configure wp-config.php if database credentials are provided
/usr/local/bin/init-apps.sh

# Start OpenLiteSpeed
echo "Starting OpenLiteSpeed..."
/usr/local/lsws/bin/lswsctrl start

echo "=== WordPress Stack Ready ==="
echo "  - WordPress: http://localhost/"
echo "  - phpMyAdmin: http://localhost/phpmyadmin/"
echo "  - OLS Admin: https://localhost:7080/"

# Keep container running by waiting for MariaDB process
wait $MARIADB_PID
