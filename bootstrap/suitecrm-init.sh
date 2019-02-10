#!/bin/bash
set -eu

readonly SUITECRM_HOME="/var/www/html"
readonly CONFIG_SI_FILE="${SUITECRM_HOME}/config_si.php"
readonly CONFIG_FILE="${SUITECRM_HOME}/config.php"
readonly CONFIG_OVERRIDE_FILE="${SUITECRM_HOME}/config_override.php"

CURRENCY_ISO4217="${CURRENCY_ISO4217:-USD}"
CURRENCY_NAME="${CURRENCY_NAME:-US Dollar}"
DATE_FORMAT="${DATE_FORMAT:-d-m-Y}"
EXPORT_CHARSET="${EXPORT_CHARSET:-ISO-8859-1}"
DEFAULT_LANGUAGE="${DEFAULT_LANGUAGE:-en_us}"
DB_ADMIN_PASSWORD="${DB_ADMIN_PASSWORD:-dbpasswd}"
DB_ADMIN_USERNAME="${DB_ADMIN_USERNAME:-dbadmin}"
DATABASE_NAME="${DATABASE_NAME:-suitecrmdb}"
DATABASE_TYPE="${DATABASE_TYPE:-mysql}"
DATABASE_HOST="${DATABASE_HOST:-mysqldb}"
POPULATE_DEMO_DATA="${POPULATE_DEMO_DATA:-false}" # Not yet implemented
SITE_USERNAME="${SITE_USERNAME:-admin}"
SITE_PASSWORD="${SITE_PASSWORD:-password}"
SITE_URL="${SITE_URL:-http://localhost}"
SYSTEM_NAME="${SYSTEM_NAME:-Zentek CRM}"

## Built in functions ##

write_suitecrm_config() {
    echo "Write config_si file..."
    cat <<EOL > ${CONFIG_SI_FILE}
<?php
\$sugar_config_si  = array (
    'dbUSRData' => 'create',
    'default_currency_iso4217' => '${CURRENCY_ISO4217}',
    'default_currency_name' => '${CURRENCY_NAME}',
    'default_currency_significant_digits' => '2',
    'default_currency_symbol' => '$',
    'default_date_format' => '${DATE_FORMAT}',
    'default_decimal_seperator' => '.',
    'default_export_charset' => '${EXPORT_CHARSET}',
    'default_language' => '${DEFAULT_LANGUAGE}',
    'default_locale_name_format' => 's f l',
    'default_number_grouping_seperator' => ',',
    'default_time_format' => 'H:i',
    'export_delimiter' => ',',
    'setup_db_admin_password' => '${DB_ADMIN_PASSWORD}',
    'setup_db_admin_user_name' => '${DB_ADMIN_USERNAME}',
    'setup_db_create_database' => 1,
    'setup_db_database_name' => '${DATABASE_NAME}',
    'setup_db_drop_tables' => 0,
    'setup_db_host_name' => '${DATABASE_HOST}',
    'setup_db_pop_demo_data' => false,
    'setup_db_type' => '${DATABASE_TYPE}',
    'setup_db_username_is_privileged' => true,
    'setup_site_admin_password' => '${SITE_PASSWORD}',
    'setup_site_admin_user_name' => '${SITE_USERNAME}',
    'setup_site_url' => '${SITE_URL}',
    'setup_system_name' => '${SYSTEM_NAME}',
  );
EOL
  chown www-data:www-data ${CONFIG_SI_FILE}

  cat ${CONFIG_SI_FILE}
}

write_suitecrm_oauth2_keys() {
  if cd Api/V8/OAuth2 ; then
    if [[ ! -e private.key ]] ; then 
      if [[ -e /run/secrets/suitecrm_oauth2_private_key ]] ; then 
        echo "OAuth2 keys are now docker secrets"
        ln -Tsf /run/secrets/suitecrm_oauth2_private_key private.key
        ln -Tsf /run/secrets/suitecrm_oauth2_public_key  public.key
      else
        echo "Generating new OAuth2 keys"
        rm -f  private.key public.key
        openssl genrsa -out private.key 2048 && \
        openssl rsa -in private.key -pubout -out public.key
        chmod 600               private.key public.key
        chown www-data:www-data private.key public.key
      fi
    fi
    cd -
  fi
}

check_mysql() {
  until nc -w1 ${DATABASE_HOST} 3306; do
    sleep 3
    echo Using DB host: ${DATABASE_HOST}
    echo "Waiting for MySQL to come up..."
  done

  echo "MySQL is available now."
}

## Main program ##
echo "SYSTEM_NAME: ${SYSTEM_NAME}"
echo "SITE_URL: ${SITE_URL}"

# Generate OAuth keys
write_suitecrm_oauth2_keys

# Waiting for DB to come up
check_mysql

# Run slient install only if config files don't exist
if [ ! -s ${CONFIG_FILE} || ! -s ${CONFIG_OVERRIDE_FILE} ]; then
  echo "Configuring suitecrm for first run..."

  write_suitecrm_config

  echo "##################################################################################"
  echo "##Running silent install, will take a couple of minutes, so go and take a tea...##"
  echo "##################################################################################"

  touch ${SUITECRM_HOME}/conf.d/config.php ${SUITECRM_HOME}/conf.d/config_override.php
  ln -sf ${SUITECRM_HOME}/conf.d/config.php ${CONFIG_FILE}
  ln -sf ${SUITECRM_HOME}/conf.d/config_override.php ${CONFIG_OVERRIDE_FILE}

  chown www-data:www-data -R ${SUITECRM_HOME}/conf.d
  chown www-data:www-data ${SUITECRM_HOME}/config*.php

  su www-data -s /bin/sh -c php <<'__END_OF_INSTALL_PHP__'
    <? 
      $_SERVER['HTTP_HOST'] = 'localhost'; 
      $_SERVER['REQUEST_URI'] = 'install.php';
      $_SERVER['SERVER_SOFTWARE'] = 'Apache'; 
      $_REQUEST = array('goto' => 'SilentInstall', 'cli' => true);
      require_once 'install.php';
    ?>
__END_OF_INSTALL_PHP__

  echo "Silent install completed."
else

echo "##################################################################################"
echo "##SuiteCRM is ready to use, enjoy it##############################################"
echo "##################################################################################"

apache2-foreground

# End of file
# vim: set ts=2 sw=2 noet:
