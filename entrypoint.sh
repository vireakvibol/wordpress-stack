#!/bin/bash
set -e

# Custom entrypoint for WordPress Stack
# Starts MariaDB (using original entrypoint) and OpenLiteSpeed

echo "=== WordPress Stack Starting ==="

# Deploy phpMyAdmin if not present
if [ ! -d "/var/www/vhosts/localhost/html/phpmyadmin" ] && [ -d "/usr/src/phpmyadmin" ]; then
    echo "Deploying phpMyAdmin..."
    cp -r /usr/src/phpmyadmin /var/www/vhosts/localhost/html/
    chown -R nobody:nogroup /var/www/vhosts/localhost/html/phpmyadmin
fi

# Deploy WordPress if not present
if [ ! -f "/var/www/vhosts/localhost/html/wp-settings.php" ] && [ -d "/usr/src/wordpress" ]; then
    echo "Deploying WordPress..."
    cp -r /usr/src/wordpress/* /var/www/vhosts/localhost/html/
    chown -R nobody:nogroup /var/www/vhosts/localhost/html/
fi

# Start MariaDB in background using original entrypoint
echo "Starting MariaDB..."
docker-entrypoint.sh "$@" &
MARIADB_PID=$!

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
for i in {1..60}; do
    if mariadb-admin ping --silent 2>/dev/null; then
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
