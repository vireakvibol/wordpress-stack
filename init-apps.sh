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

# Install WordPress core if not already installed (creates admin user)
if [ -f "$WP_CONFIG" ] && ! wp core is-installed --path=/var/www/vhosts/localhost/html --allow-root 2>/dev/null; then
    echo "Installing WordPress Core..."
    
    # Sanitize WORDPRESS_URL: Ensure it has a protocol
    WP_URL="${WORDPRESS_URL:-http://localhost}"
    if [[ "$WP_URL" != http* ]]; then
        WP_URL="http://$WP_URL"
    fi
    
    wp core install \
        --url="$WP_URL" \
        --title="${WORDPRESS_TITLE:-Docker WordPress}" \
        --admin_user="${WORDPRESS_ADMIN_USER:-admin}" \
        --admin_password="${WORDPRESS_ADMIN_PASSWORD:-password}" \
        --admin_email="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}" \
        --path=/var/www/vhosts/localhost/html \
        --allow-root
        
    echo "WordPress installed successfully."
    echo "Site URL: $WP_URL"
    echo "Admin User: ${WORDPRESS_ADMIN_USER:-admin}"
    echo "Admin Password: ${WORDPRESS_ADMIN_PASSWORD:-password}"
fi

# Activate all plugins except defaults (hello, akismet) individually for robustness
if [ -f "$WP_CONFIG" ]; then
    echo "Activating plugins..."
    # Get all inactive plugins and activate them, skipping defaults
    INACTIVE_PLUGINS=$(wp plugin list --status=inactive --field=name --path=/var/www/vhosts/localhost/html --allow-root)
    for plugin in $INACTIVE_PLUGINS; do
        # Skip default plugins explicitly
        if [ "$plugin" = "hello" ] || [ "$plugin" = "akismet" ]; then
             continue
        fi

        echo "Activating plugin: $plugin"
        wp plugin activate "$plugin" --path=/var/www/vhosts/localhost/html --allow-root || echo "Warning: Failed to activate $plugin"
    done
fi

# Protect plugins marked as :ro (readonly) from deletion
PLUGIN_DIR="/var/www/vhosts/localhost/html/wp-content/plugins"
if [ -n "$WORDPRESS_PLUGINS_CONFIG" ]; then
    echo "$WORDPRESS_PLUGINS_CONFIG" | tr ',' '\n' | while read plugin_entry; do
        # Check if plugin is marked as readonly (:ro)
        if echo "$plugin_entry" | grep -q ':ro$'; then
            plugin_name=$(echo "$plugin_entry" | sed 's/:ro$//')
            if [ -d "$PLUGIN_DIR/$plugin_name" ]; then
                echo "Protecting plugin (readonly): $plugin_name"
                chown -R root:root "$PLUGIN_DIR/$plugin_name"
                chmod -R 755 "$PLUGIN_DIR/$plugin_name"
            fi
        fi
    done
fi

# Apply Runtime Read-Only Mode if requested
# Defaults to 0 (Normal mode)
if [ "$WORDPRESS_READONLY" = "1" ]; then
    echo "Enforcing Runtime Read-Only Mode (Files: 444, Dirs: 555)..."
    # Recursive chmod is skipped in favor of find to separate files/dirs
    # Target: Web Root
    WEB_ROOT="/var/www/vhosts/localhost/html"
    
    find "$WEB_ROOT" -type d -exec chmod 555 {} +
    find "$WEB_ROOT" -type f -exec chmod 444 {} +
    
    echo "Read-Only Mode applied."
else
    echo "Ensuring Normal Permission Mode (Files: 644, Dirs: 755)..."
    WEB_ROOT="/var/www/vhosts/localhost/html"
    
    # Restore write permissions for owner (nobody)
    find "$WEB_ROOT" -type d -exec chmod 755 {} +
    find "$WEB_ROOT" -type f -exec chmod 644 {} +
    
    # Ensure ownership is correct (in case it was messed up)
    chown -R nobody:nogroup "$WEB_ROOT"
    
    echo "Normal Permission Mode applied."
fi
