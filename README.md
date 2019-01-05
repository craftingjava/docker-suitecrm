# SuiteCRM Docker Image

This image provides a SuiteCRM Server. The image is based on php:apache docker image. It depends on a mysql (mariadb) database and performs a silent install of SuiteCRM.

# Quickstart
Run mysql database
Run suitecrm
```bash
docker build -t blacs30/suitecrm .
docker run -d --name mariadb -e MYSQL_USER=dbadmin -e MYSQL_PASSWORD=dbpasswd -e MYSQL_ALLOW_EMPTY_PASSWORD=false -e MYSQL_DATABASE=suitecrm mariadb:10.3
docker run -d -p 80:80 --link mariadb -e SYSTEM_NAME=MyCRM -e DATABASE_TYPE=mysql -e DATABASE_HOST=mariadb -e DATABASE_NAME=suitecrm -e DB_ADMIN_USERNAME=dbadmin -e DB_ADMIN_PASSWORD=dbpasswd -e SITE_USERNAME=admin -e SITE_PASSWORD=password blacs30/suitecrm
```

# Features
 - Silent install
 - Exposed volumes
 - Image size of ~800MB

# Usage
There are several parameters available to configure your CRM instance, you can use the following docker compose template:
```
version: 3

services:
  mariadb:
    image: mariadb:10.3
    container_name: mysql.crm
    ports:
    - "3306:3306"
    volumes:
    - db-volume:/var/lib/mysql:Z
    environment:
    - MYSQL_USER=admin
    - MYSQL_PASSWORD=secret
    - MYSQL_ROOT_PASSWORD=secret
    - MYSQL_DATABASE=suitecrmdb

  suitecrm:
    image: blacs30/suitecrm:7.10.4
    container_name: suitecrm.crm
    depends_on:
    - mariadb
    ports:
    - 80:80
    tty: true
    environment:
    - CURRENCY_ISO4217=MXN
    - CURRENCY_NAME=MX Peso
    - DATE_FORMAT=d-m-Y
    - EXPORT_CHARSET=ISO-8859-1
    - DEFAULT_LANGUAGE=en_us
    - DATABASE_TYPE=mysql
    - DATABASE_HOST=mariadb
    - DB_ADMIN_PASSWORD=secret
    - DB_ADMIN_USERNAME=admin
    - DATABASE_NAME=suitecrmdb
    - SITE_USERNAME=admin
    - SITE_PASSWORD=password
    - SITE_URL=http://localhost
    - SYSTEM_NAME=Zentek CRM

volumes:
    db-volume:
```

# Exposed ports
 * 80

# Exposed volumes
 * /var/www/html/upload
 * /var/www/html/conf.d

