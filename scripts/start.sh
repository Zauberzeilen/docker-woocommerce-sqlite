#!/bin/bash
if [ ! -f /usr/share/nginx/www/wp-config.php ]; then

  # Download and install latest Wordpress
  curl -o /usr/share/nginx/latest.tar.gz https://wordpress.org/latest.tar.gz
  cd /usr/share/nginx/ && tar xvf latest.tar.gz && rm latest.tar.gz
  cp -a /usr/share/nginx/wordpress/* /usr/share/nginx/www
  rm -rf /usr/share/nginx/wordpress
  chown -R www-data:www-data /usr/share/nginx/www

  # Here we generate random passwords (thank you pwgen!).
  # The first are for wordpress admin user, the last batch for random keys in wp-config.php
  SQLITE_DB_FILE="wordpress.db"
  SQLITE_DB_PATH="/usr/share/nginx/www/wp-database/"
  WORDPRESS_PASSWORD=`pwgen -c -n -1 12`
  #This is so the passwords show up in logs.
  echo wordpress password: $WORDPRESS_PASSWORD
  echo $WORDPRESS_PASSWORD > /wordpress-db-pw.txt

  sed -e "/database_name_here/c\define('DB_FILE', '$SQLITE_DB_FILE');
  /username_here/c\define('DB_DIR', '$SQLITE_DB_PATH');
  /password_here/c\define('USE_MYSQL', false);
  /'AUTH_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'SECURE_AUTH_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'LOGGED_IN_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'NONCE_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'AUTH_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'SECURE_AUTH_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'LOGGED_IN_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
  /'NONCE_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/" /usr/share/nginx/www/wp-config-sample.php > /usr/share/nginx/www/wp-config.php

  # Download nginx helper plugin
  curl -O `curl -i -s https://wordpress.org/plugins/nginx-helper/ | egrep -o "https://downloads.wordpress.org/plugin/[^\"]+"`
  unzip -o nginx-helper.*.zip -d /usr/share/nginx/www/wp-content/plugins
  chown -R www-data:www-data /usr/share/nginx/www/wp-content/plugins/nginx-helper

  # Download wp-sqlite-db integration
  curl -LOk https://github.com/aaemnnosttv/wp-sqlite-db/archive/master.zip
  unzip -o master.zip -d /usr/share/nginx/www/wp-content/plugins
  cp -a /usr/share/nginx/www/wp-content/plugins/wp-sqlite-db-master/src/db.php /usr/share/nginx/www/wp-content
  rm -rf /usr/share/nginx/www/wp-content/plugins/wp-sqlite-db-master
  chown -R www-data:www-data /usr/share/nginx/www/wp-content/db.php

  # Download woocommerce plugin
  curl -O `curl -i -s https://wordpress.org/plugins/woocommerce/ | egrep -o "https://downloads.wordpress.org/plugin/[^\"]+"`
  unzip -o  woocommerce.*.zip -d /usr/share/nginx/www/wp-content/plugins
  chown -R www-data:www-data /usr/share/nginx/www/wp-content/plugins/woocommerce

  # Activate nginx plugin once logged in
  cat << ENDL >> /usr/share/nginx/www/wp-config.php
\$plugins = get_option( 'active_plugins' );
if ( count( \$plugins ) === 0 ) {
  require_once(ABSPATH .'/wp-admin/includes/plugin.php');
  \$pluginsToActivate = array( 'nginx-helper/nginx-helper.php', 'woocommerce/woocommerce.php' );
  foreach ( \$pluginsToActivate as \$plugin ) {
    if ( !in_array( \$plugin, \$plugins ) ) {
      activate_plugin( '/usr/share/nginx/www/wp-content/plugins/' . \$plugin );
    }
  }
}
ENDL

  # SQlite database setup
  mkdir -p $SQLITE_DB_PATH
  touch $SQLITE_DB_PATH$SQLITE_DB_FILE
  chown -R www-data:www-data $SQLITE_DB_PATH

  # Wordpress config
  chown www-data:www-data /usr/share/nginx/www/wp-config.php
fi

# Replace environment
envsubst < /etc/nginx/conf.d/mysite.template > /etc/nginx/sites-available/default

# start all the services
/usr/local/bin/supervisord -n
