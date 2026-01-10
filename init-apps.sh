#!/bin/bash
# init-apps.sh - Configure WordPress wp-config.php with database credentials

WP_CONFIG="/var/www/vhosts/localhost/html/wp-config.php"
WP_CONFIG_SAMPLE="/var/www/vhosts/localhost/html/wp-config-sample.php"

# Configure wp-config.php if database credentials are provided
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
    chown nobody:nogroup "$WP_CONFIG"
    
    echo "WordPress configured with database: $DB_NAME, user: $DB_USER"
fi
