# Stage 1: Source binaries
FROM mariadb:11.8 AS source

# Stage 2: Final OLS image
FROM litespeedtech/openlitespeed:1.8.4-lsphp84

# Install runtime dependencies for MariaDB
# Reuse the same list as our previous Ubuntu 24.04 build
RUN apt-get update && apt-get install -y \
    libncurses6 \
    libedit2 \
    libaio1t64 \
    liburing2 \
    libssl-dev \
    libstdc++6 \
    zlib1g \
    adduser \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Create mysql user/group if they don't exist (OLS image usually runs as root but might have nobody/nogroup)
RUN groupadd -r mysql && useradd -r -g mysql mysql

# Copy MariaDB files from source
COPY --from=source /usr/sbin/mariadbd /usr/sbin/
COPY --from=source /usr/bin/mariadb* /usr/bin/
COPY --from=source /usr/bin/mysql* /usr/bin/
COPY --from=source /usr/bin/my* /usr/bin/
COPY --from=source /usr/bin/resolveip /usr/bin/
COPY --from=source /usr/share/mariadb /usr/share/mariadb
COPY --from=source /usr/lib/mysql /usr/lib/mysql
COPY --from=source /etc/mysql /etc/mysql

# Setup directories and permissions
RUN mkdir -p /var/lib/mysql /run/mysqld \
    && chown -R mysql:mysql /var/lib/mysql /run/mysqld /etc/mysql

# Install phpMyAdmin to /usr/src (will be copied to webroot at runtime)
RUN apt-get update && apt-get install -y wget unzip \
    && wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip -O /tmp/phpmyadmin.zip \
    && unzip /tmp/phpmyadmin.zip -d /usr/src/ \
    && mv /usr/src/phpMyAdmin-5.2.1-all-languages /usr/src/phpmyadmin \
    && rm /tmp/phpmyadmin.zip \
    && apt-get remove -y wget unzip \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Install WordPress to /usr/src (will be copied to webroot at runtime)
RUN apt-get update && apt-get install -y wget unzip \
    && wget https://wordpress.org/latest.zip -O /tmp/wordpress.zip \
    && unzip /tmp/wordpress.zip -d /usr/src/ \
    && rm /tmp/wordpress.zip \
    && apt-get remove -y wget unzip \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Expose ports (OLS uses 7080/8088, MariaDB uses 3306)
EXPOSE 7080 8088 3306



# Copy initialization script
COPY init-mariadb.sh /usr/local/bin/init-mariadb.sh
RUN chmod +x /usr/local/bin/init-mariadb.sh

# Inject MariaDB startup logic into the existing entrypoint
# We match the line starting the litespeed controller and insert our logic before it.
RUN sed -i '/^\/usr\/local\/lsws\/bin\/lswsctrl start/i /usr/local/bin/init-mariadb.sh' /entrypoint.sh
