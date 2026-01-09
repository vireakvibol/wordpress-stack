#!/bin/bash
set -e

# Data directory
DATADIR="/var/lib/mysql"

# Check if phpMyAdmin needs installation
if [ ! -d "/var/www/vhosts/localhost/html/phpmyadmin" ] && [ -d "/usr/src/phpmyadmin" ]; then
    echo "Deploying phpMyAdmin..."
    cp -r /usr/src/phpmyadmin /var/www/vhosts/localhost/html/
    chown -R 994:994 /var/www/vhosts/localhost/html/phpmyadmin
fi

# Check if WordPress needs installation (check for wp-settings.php)
if [ ! -f "/var/www/vhosts/localhost/html/wp-settings.php" ] && [ -d "/usr/src/wordpress" ]; then
    echo "Deploying WordPress..."
    # Copy contents of wordpress directory to html
    cp -r /usr/src/wordpress/* /var/www/vhosts/localhost/html/
    chown -R 994:994 /var/www/vhosts/localhost/html/
fi

# Configure wp-config.php if database credentials are provided
WP_CONFIG="/var/www/vhosts/localhost/html/wp-config.php"
WP_CONFIG_SAMPLE="/var/www/vhosts/localhost/html/wp-config-sample.php"

if [ ! -f "$WP_CONFIG" ] && [ -f "$WP_CONFIG_SAMPLE" ] && [ -n "$MARIADB_DATABASE" ]; then
    echo "Configuring WordPress wp-config.php..."
    
    # Determine database credentials
    DB_NAME="${MARIADB_DATABASE}"
    DB_USER="${MARIADB_USER:-root}"
    DB_PASSWORD="${MARIADB_PASSWORD:-$MARIADB_ROOT_PASSWORD}"
    DB_HOST="localhost"
    
    # Copy sample config
    cp "$WP_CONFIG_SAMPLE" "$WP_CONFIG"
    
    # Replace database settings
    sed -i "s/database_name_here/$DB_NAME/" "$WP_CONFIG"
    sed -i "s/username_here/$DB_USER/" "$WP_CONFIG"
    sed -i "s/password_here/$DB_PASSWORD/" "$WP_CONFIG"
    sed -i "s/localhost/$DB_HOST/" "$WP_CONFIG"
    
    # Generate unique keys and salts using openssl (hex to avoid special chars)
    generate_salt() {
        openssl rand -hex 32
    }
    
    # Replace each placeholder salt with a unique random value
    for i in 1 2 3 4 5 6 7 8; do
        SALT=$(generate_salt)
        sed -i "0,/put your unique phrase here/s/put your unique phrase here/$SALT/" "$WP_CONFIG"
    done
    
    # Set correct ownership
    chown 994:994 "$WP_CONFIG"
    
    echo "WordPress configured with database: $DB_NAME, user: $DB_USER"
fi

# Check if database needs initialization
if [ ! -d "$DATADIR/mysql" ]; then
    echo "Initializing MariaDB..."
    mariadb-install-db --user=mysql --datadir="$DATADIR" --skip-test-db > /dev/null

    echo "Starting MariaDB (temp) to set password..."
    mariadbd --user=mysql --datadir="$DATADIR" --skip-networking &
    PID=$!

    echo "Waiting for MariaDB to start..."
    for i in {1..30}; do
        if mariadb-admin ping --socket=/run/mysqld/mysqld.sock --silent; then
            break
        fi
        sleep 1
    done

    echo "Setting up users and databases..."
    
    # Defaults: Generate random password if not set
    if [ -z "$MARIADB_ROOT_PASSWORD" ]; then
        ROOT_PWD=$(openssl rand -base64 32)
        echo "GENERATED ROOT PASSWORD: $ROOT_PWD"
    else
        ROOT_PWD="$MARIADB_ROOT_PASSWORD"
    fi
    
    # Execute SQL commands directly (avoid writing to disk)
    mariadb -u root --socket=/run/mysqld/mysqld.sock <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('$ROOT_PWD');
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
$(if [ -n "$MARIADB_DATABASE" ]; then echo "CREATE DATABASE IF NOT EXISTS \`$MARIADB_DATABASE\`;"; fi)
$(if [ -n "$MARIADB_USER" ] && [ -n "$MARIADB_PASSWORD" ]; then
    echo "CREATE USER '$MARIADB_USER'@'%' IDENTIFIED VIA mysql_native_password USING PASSWORD('$MARIADB_PASSWORD');"
    if [ -n "$MARIADB_DATABASE" ]; then
        echo "GRANT ALL PRIVILEGES ON \`$MARIADB_DATABASE\`.* TO '$MARIADB_USER'@'%';"
    else
        echo "GRANT ALL PRIVILEGES ON *.* TO '$MARIADB_USER'@'%';"
    fi
fi)
FLUSH PRIVILEGES;
EOF

    echo "Stopping temp MariaDB..."
    kill $PID
    wait $PID
fi

echo "Starting MariaDB in background..."
exec mariadbd --user=mysql --datadir="$DATADIR" &
