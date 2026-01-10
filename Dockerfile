# Arguments for build versions
ARG MARIADB_VERSION=11.8

FROM mariadb:${MARIADB_VERSION}



# Re-declare ARGs after FROM
ARG LSPHP_VERSION=84
ARG PHPMYADMIN_VERSION=5.2.1
ARG WORDPRESS_VERSION=latest

# Install OpenLiteSpeed from official repository
RUN apt-get update \
    && apt-get install -y wget curl ca-certificates \
    && wget -nv -O - https://repo.litespeed.sh | bash \
    && apt-get update \
    && apt-get install -y \
        openlitespeed \
        lsphp${LSPHP_VERSION} \
        lsphp${LSPHP_VERSION}-common \
        lsphp${LSPHP_VERSION}-mysql \
        lsphp${LSPHP_VERSION}-curl \
        lsphp${LSPHP_VERSION}-imagick \
        lsphp${LSPHP_VERSION}-intl \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Configure OLS to use lsphp
RUN ln -sf /usr/local/lsws/lsphp${LSPHP_VERSION}/bin/lsphp /usr/local/lsws/fcgi-bin/lsphp

# Create web root directory
RUN mkdir -p /var/www/vhosts/localhost/html \
    && chown -R nobody:nogroup /var/www/vhosts/localhost/html

# Configure OLS: change listener to port 80, update vhost docRoot, and set lsphp path
RUN sed -i 's/address.*\*:8088/address                  *:80/' /usr/local/lsws/conf/httpd_config.conf \
    && sed -i 's|path.*lsphp83/bin/lsphp|path                            lsphp84/bin/lsphp|' /usr/local/lsws/conf/httpd_config.conf \
    && sed -i 's|vhRoot.*Example/|vhRoot                   /var/www/vhosts/localhost/|' /usr/local/lsws/conf/httpd_config.conf

# Update Example vhost to use html as docRoot and add index.php to indexFiles
RUN sed -i 's|docRoot.*\$VH_ROOT/html/|docRoot                  $VH_ROOT/html/|' /usr/local/lsws/conf/vhosts/Example/vhconf.conf 2>/dev/null || true \
    && sed -i 's|indexFiles index.html|indexFiles index.php, index.html|' /usr/local/lsws/conf/vhosts/Example/vhconf.conf

# Install phpMyAdmin
RUN wget -nv https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.zip -O /tmp/phpmyadmin.zip \
    && unzip /tmp/phpmyadmin.zip -d /usr/src/ \
    && mv /usr/src/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages /usr/src/phpmyadmin \
    && rm /tmp/phpmyadmin.zip

# Install WordPress
RUN if [ "$WORDPRESS_VERSION" = "latest" ]; then \
        wget -nv https://wordpress.org/latest.zip -O /tmp/wordpress.zip; \
    else \
        wget -nv https://wordpress.org/wordpress-${WORDPRESS_VERSION}.zip -O /tmp/wordpress.zip; \
    fi \
    && unzip /tmp/wordpress.zip -d /usr/src/ \
    && rm /tmp/wordpress.zip

# Install PHP CLI for WP-CLI (LSPHP is LSAPI-only)
RUN apt-get update && apt-get install -y php-cli php-mysql php-mbstring php-curl php-xml php-zip

# Install WP-CLI
RUN wget -nv https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -O /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp

# Pre-install plugins (format: "plugin1,plugin2")
# No plugins installed by default. Override with --build-arg WORDPRESS_PLUGINS="..."
ARG WORDPRESS_PLUGINS=""
RUN if [ -n "$WORDPRESS_PLUGINS" ]; then \
        echo "$WORDPRESS_PLUGINS" | tr ',' '\n' | while read plugin_name; do \
            # Backward compatibility: strip :ro/:rw if present (user might still use old format)
            plugin_name=$(echo "$plugin_name" | sed 's/:ro$//' | sed 's/:rw$//'); \
            if [ -n "$plugin_name" ]; then \
                wget -nv -O /tmp/plugin.zip "https://downloads.wordpress.org/plugin/${plugin_name}.zip" \
                && unzip -q /tmp/plugin.zip -d /usr/src/wordpress/wp-content/plugins/ \
                && rm /tmp/plugin.zip; \
            fi; \
        done; \
    fi

# Clean up wget/unzip (keep curl for healthchecks)
RUN apt-get purge -y wget unzip \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Expose ports
EXPOSE 80 7080 3306

# Copy scripts
COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
COPY init-apps.sh /usr/local/bin/init-apps.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh /usr/local/bin/init-apps.sh

# Set custom entrypoint
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["mariadbd"]
