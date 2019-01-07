#!/bin/bash
set -eu

readonly DOCKER_BOOTSTRAPPED="/bootstrap/docker_bootstrapped"
readonly WAIT_FOR="/bootstrap/wait-for-it"
readonly CONFIG_SI_FILE="/var/www/html/config_si.php"

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

## Main program ##
echo "SYSTEM_NAME: ${SYSTEM_NAME}"
echo "SITE_URL: ${SITE_URL}"

if [ ! -e ${DOCKER_BOOTSTRAPPED} ]; then
  echo "Configuring suitecrm for first run"
	write_suitecrm_config
	cat ${CONFIG_SI_FILE}
	write_suitecrm_oauth2_keys

  until nc ${DATABASE_HOST} 3306; do sleep 3; echo Using DB host: ${DATABASE_HOST}; echo "Waiting for DB to come up..."; done
  echo "DB is available now."

  echo "##################################################################################"
  echo "##Running silent install, will take a couple of minutes, so go and take a tea...##"
  echo "##################################################################################"

	php -r "\$_SERVER['HTTP_HOST'] = 'localhost'; \$_SERVER['REQUEST_URI'] = 'install.php';\$_REQUEST = array('goto' => 'SilentInstall', 'cli' => true);require_once 'install.php';";
	chown -R www-data:www-data . && chmod -R 755 . && chmod -R 775 cache custom modules themes data upload

  echo "##################################################################################"
  echo "##SuiteCRM is ready to use, enjoy it##############################################"
  echo "##################################################################################"

  touch ${DOCKER_BOOTSTRAPPED}
	apache2-foreground
else
  echo "Ready to use suitecrm..."
	apache2-foreground
fi
# End of file
# vim: set ts=2 sw=2 noet:
