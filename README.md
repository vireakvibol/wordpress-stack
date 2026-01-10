# WordPress Stack

[![Build and Test](https://github.com/vireakvibol/wordpress-stack/actions/workflows/docker-test.yml/badge.svg)](https://github.com/vireakvibol/wordpress-stack/actions/workflows/docker-test.yml)
[![CodeFactor](https://www.codefactor.io/repository/github/vireakvibol/wordpress-stack/badge)](https://www.codefactor.io/repository/github/vireakvibol/wordpress-stack)
[![Docker Image](https://img.shields.io/badge/docker-ghcr.io-blue?logo=docker)](https://ghcr.io/vireakvibol/wordpress-stack)
[![Version](https://img.shields.io/github/v/tag/vireakvibol/wordpress-stack?label=version)](https://github.com/vireakvibol/wordpress-stack/releases)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

A production-ready, all-in-one Docker image combining **OpenLiteSpeed**, **MariaDB**, **WordPress**, and **phpMyAdmin** in a single container.

## Features

- 🚀 **OpenLiteSpeed** - High-performance web server with HTTP/3 support
- 🗄️ **MariaDB 11.8** - Fast, reliable database server
- 📝 **WordPress** - Pre-installed and ready to configure
- 🔧 **phpMyAdmin** - Web-based database management
- 🔒 **Secure by Default** - Random root password generation if not specified
- ⚙️ **Configurable** - Customize versions at build time
- 🎯 **Zero-Config WordPress** - Auto-generates wp-config.php with your database credentials

## Quick Start

```bash
docker run -d \
  -p 80:80 \
  -p 7080:7080 \
  -e MARIADB_ROOT_PASSWORD=your_secure_password \
  -e MARIADB_DATABASE=wordpress \
  -e MARIADB_USER=wp_user \
  -e MARIADB_PASSWORD=wp_password \
  ghcr.io/vireakvibol/wordpress-stack:main
```

## Ports

| Port | Service |
|------|---------|
| 80 | HTTP (WordPress) |
| 7080 | OLS WebAdmin Console |
| 3306 | MariaDB |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MARIADB_ROOT_PASSWORD` | Root password for MariaDB | *Random 32-char* |
| `MARIADB_DATABASE` | Database to create on startup | - |
| `MARIADB_USER` | Additional user to create | - |
| `MARIADB_PASSWORD` | Password for the additional user | - |

> **Note:** If `MARIADB_ROOT_PASSWORD` is not set, a random password is generated and printed to the container logs on first startup.

## Access Points

After starting the container:

- **WordPress**: http://localhost/
- **phpMyAdmin**: http://localhost/phpmyadmin/
- **OLS Admin**: http://localhost:7080/

### WordPress Setup

When you provide `MARIADB_DATABASE`, `MARIADB_USER`, and `MARIADB_PASSWORD` environment variables, WordPress is **automatically configured** with the database credentials. On first access, you'll skip directly to creating your WordPress admin account!

> **Tip:** No manual database configuration needed - just set the environment variables and you're ready to go.

## Custom Builds

Override component versions at build time:

```bash
docker build \
  --build-arg OLS_VERSION=1.8.4-lsphp84 \
  --build-arg MARIADB_VERSION=11.8 \
  --build-arg PHPMYADMIN_VERSION=5.2.1 \
  --build-arg WORDPRESS_VERSION=6.4.2 \
  -t wordpress-stack:custom .
```

### Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `OLS_VERSION` | `1.8.4-lsphp84` | OpenLiteSpeed image tag |
| `MARIADB_VERSION` | `11.8` | MariaDB version |
| `PHPMYADMIN_VERSION` | `5.2.1` | phpMyAdmin version |
| `WORDPRESS_VERSION` | `latest` | WordPress version |

## Persistent Data

Mount volumes to persist data:

```bash
docker run -d \
  -p 80:80 \
  -p 7080:7080 \
  -v wordpress_db:/var/lib/mysql \
  -v wordpress_html:/var/www/vhosts/localhost/html \
  -e MARIADB_ROOT_PASSWORD=secret \
  ghcr.io/vireakvibol/wordpress-stack:main
```

## Security Considerations

- **Change default passwords** - Always set `MARIADB_ROOT_PASSWORD` in production
- **Limit port exposure** - Only expose necessary ports
- **Use volumes** - Persist data between container restarts
- **Restrict OLS Admin** - Port 7080 should not be publicly accessible

## License

This project is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**.

See [LICENSE](LICENSE) for details.

### Bundled Components

This Docker image includes the following open-source software, each under its own license:

| Component | Version | License | Website |
|-----------|---------|---------|---------|
| MariaDB | 11.8 | GPL-2.0 | [mariadb.org](https://mariadb.org/) |
| OpenLiteSpeed | 1.8.x | GPL-3.0 | [openlitespeed.org](https://openlitespeed.org/) |
| WordPress | Latest | GPL-2.0+ | [wordpress.org](https://wordpress.org/) |
| phpMyAdmin | 5.2.x | GPL-2.0+ | [phpmyadmin.net](https://www.phpmyadmin.net/) |
| LSPHP | 8.4 | PHP License | [php.net](https://www.php.net/) |

> **Note:** The AGPL-3.0 license applies to the orchestration code in this repository (Dockerfile, scripts, workflows). Bundled software retains its original license.
