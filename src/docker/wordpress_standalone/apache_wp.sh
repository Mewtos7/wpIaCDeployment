#!/bin/bash

## Variables ##
mysqlpassword=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13; echo)
unique=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13; echo)
mysqlhost="127.0.0.1"

apt-get update
apt-get upgrade -y

if [ -d "/srv/www/wordpress" ]; then
    echo "/srv/www/wordpress does exist."
else
    echo "/srv/www/wordpress does not exist."
    curl https://wordpress.org/latest.tar.gz | tar zx -C /srv/www
    cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php
fi

service mysql start
mysql -u root -Bse "CREATE DATABASE IF NOT EXISTS wordpress; CREATE USER IF NOT EXISTS wordpress@localhost IDENTIFIED BY '$mysqlpassword'; GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER ON wordpress.* TO 'wordpress'@'localhost'; FLUSH PRIVILEGES;"

sed -i 's/database_name_here/wordpress/' /srv/www/wordpress/wp-config.php
sed -i 's/username_here/wordpress/' /srv/www/wordpress/wp-config.php
sed -i "s/localhost/$mysqlhost/" /srv/www/wordpress/wp-config.php
sed -i "s/password_here/$mysqlpassword/" /srv/www/wordpress/wp-config.php
sed -i "s/put your unique phrase here/$unique/" /srv/www/wordpress/wp-config.php
chown --recursive www-data: /srv/www

a2enmod rewrite
a2dissite 000-default

if [ -z $DOMAIN ]; then
    echo "Variable DOMAIN is unset, using localhost and no SSL"
    a2ensite wordpress
else
    echo "Domain was added as $DOMAIN, using $DOMAIN and www.$DOMAIN and SSL"
    sed -i "s/domainchangeme/$DOMAIN/" /etc/apache2/sites-available/wordpress_domain.conf
    a2ensite wordpress_domain
    service apache2 restart
    certbot --apache --non-interactive --agree-tos --domains $DOMAIN --email $MAIL
fi

service apache2 stop
apachectl -D FOREGROUND