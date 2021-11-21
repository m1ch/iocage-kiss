#!/bin/bash

MARIADB_JAIL="test_mariadb"
MARIADB_IP="10.23.10.61"

NEXTCLOUD_JAIL="test_nextcloud"

#install mariadb:
iocage fetch --plugin-name "mariadb-kiss" \
    --git_repository https://github.com/m1ch/iocage-plugin-index \
    --branch kiss \
    --name $MARIADB_JAIL \
        interfaces="vnet0:bridge10" \
        ip4_addr="vnet0|$MARIADB_IP/24" \
        vnet=1 defaultrouter="10.23.10.1" \
        resolver="search local;nameserver 1.1.1.1"
        

zfs create pool01/iocage/sockets/mysql
MARIADB_JAIL="mariadb_next"
iocage fetch --plugin-name "mariadb-kiss" \
    --git_repository https://github.com/m1ch/iocage-plugin-index \
    --branch kiss \
    --name $MARIADB_JAIL \
        vnet=On dhcp=Off nat=On
        
iocage fstab -a mariadb /mnt/pool01/iocage/sockets/mariadb /var/run/mysql nullfs rw 0 0
iocage fstab -a nextcloud /mnt/pool01/iocage/sockets/mariadb /var/run/mysql nullfs rw 0 0
iocage fstab -a nextcloud /mnt/pool01/iocage/servicedata/nextcloud /usr/local/www/nextcloud nullfs rw 0 0


# pool01/iocage/sockets/mariadb

iocage exec $MARIADB_JAIL bash -c 'PASS=$(</root/mysqlrootpassword); mysql -u root -p"${PASS}"'
DROP DATABASE  IF EXISTS nextcloud;
CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY '';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';
FLUSH PRIVILEGES;


# Create DB for mariaDB
iocage exec $MARIADB_JAIL bash -c 'PASS=$(</root/mysqlrootpassword); mysql -u root -p"${PASS}"<<EOF
show databases;
DROP DATABASE  IF EXISTS testDB;
CREATE DATABASE testDB;
show databases;
DROP DATABASE  IF EXISTS testDB;
show databases;
EOF'

exit
# install redis
iocage create -r 12.2-RELEASE -n redis vnet=On dhcp=Off nat=On
iocage pkg redis install redis
# https://guides.wp-bullet.com/how-to-configure-redis-to-use-unix-socket-speed-boost/
# ssh -nNT -L $(pwd)/docker.sock:/var/run/docker.sock user@someremote


# install php-fpm


# install nginx



# install nextcloud
jail_name = "nextcloud"

jail_pool = $(iocage get -p)
jail_path = $(zfs list -o mountpoint ${jail_pool}/iocage | tail -n 1)
jail_root = ${jail_path}/jails/${jail_name}/root

iocage create -r 12.2-RELEASE -n ${jail_name} vnet=On dhcp=On nat=Off \
        interfaces="vnet0:bridge10"

mkdir -p ${jail_root}/mnt/{homevideo,tvshows,music,movie,downloads,cloud_data}
mkdir -p ${jail_root}/usr/local/www/nextcloud
mkdir -p ${jail_root}/var/run/{mysql,redis}

iocage fstab -a ${jail_name} /mnt/pool01/homevideo                      /mnt/homevideo              nullfs ro 0 0
iocage fstab -a ${jail_name} /mnt/pool01/tvshows                        /mnt/tvshows                nullfs ro 0 0
iocage fstab -a ${jail_name} /mnt/pool01/music                          /mnt/music                  nullfs rw 0 0
iocage fstab -a ${jail_name} /mnt/pool01/movie                          /mnt/movie                  nullfs ro 0 0
iocage fstab -a ${jail_name} /mnt/pool01/downloads                      /mnt/downloads              nullfs rw 0 0
iocage fstab -a ${jail_name} /mnt/pool01/cloud_data                     /mnt/cloud_data             nullfs rw 0 0
iocage fstab -a ${jail_name} /mnt/pool01/iocage/servicedata/nextcloud   /usr/local/www/nextcloud    nullfs rw 0 0
iocage fstab -a ${jail_name} /mnt/pool01/iocage/sockets/mariadb         /var/run/mysql              nullfs ro 0 0
iocage fstab -a ${jail_name} /mnt/pool01/iocage/sockets/redis           /var/run/redis              nullfs ro 0 0
        
iocage start ${jail_name}
iocage exec ${jail_name} pkg update

iocage pkg ${jail_name} install ffmpeg
# iocage pkg install libreoffice
iocage pkg ${jail_name} install nginx

# PHP module hash (only on FreeBSD)
iocage pkg ${jail_name} install php80 php80-ctype php80-curl php80-dom php80-filter php80-gd php80-iconv php80-pear-Services_JSON php80-pecl-json_post \
    php80-xml php80-xmlreader php80-xmlwriter php80-mbstring php80-openssl php80-posix php80-session php80-simplexml php80-zip php80-zlib \
    php80-pdo php80-pdo_mysql \
    php80-fileinfo php80-bz2 php80-intl \
    php80-ldap php80-pecl-smbclient php80-ftp php80-imap php80-bcmath php80-gmp \
    php80-exif \
    php80-pecl-redis \
    php80-pecl-imagick-im7 \
    php80-pcntl \
    php80-phar \
    php80-opcache \
    php80-xsl


iocage exec ${jail_name} sysrc -f /etc/rc.conf nginx_enable="YES"
iocage exec ${jail_name} sysrc -f /etc/rc.conf php_fpm_enable="YES"

iocage stop ${jail_name}

cp ${jail_root}/usr/local/etc/php.ini-production ${jail_root}/usr/local/etc/php.ini
sed -i '' -E 's/.*memory_limit.*/memory_limit=4G/' ${jail_root}/usr/local/etc/php.ini
sed -i '' -E 's/.*opcache.enable=.*/opcache.enable=1/' ${jail_root}/usr/local/etc/php.ini
sed -i '' -E 's/.*opcache.enable_cli=.*/opcache.enable_cli=1/' ${jail_root}/usr/local/etc/php.ini
sed -i '' -E 's/.*opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=8/' ${jail_root}/usr/local/etc/php.ini
sed -i '' -E 's/.*opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/' ${jail_root}/usr/local/etc/php.ini
sed -i '' -E 's/.*opcache.memory_consumption=.*/opcache.memory_consumption=128/' ${jail_root}/usr/local/etc/php.ini
sed -i '' -E 's/.*opcache.save_comments=.*/opcache.save_comments=1/' ${jail_root}/usr/local/etc/php.ini
sed -i '' -E 's/.*opcache.revalidate_freq=.*/opcache.revalidate_freq=1/' ${jail_root}/usr/local/etc/php.ini

mkdir -p ${jail_root}/usr/local/etc/php-fpm.d ${jail_root}/usr/local/etc/nginx/conf.d
curl https://raw.githubusercontent.com/m1ch/iocage-plugin-nextcloud/master/overlay/usr/local/etc/php-fpm.conf > ${jail_root}/usr/local/etc/php-fpm.conf
curl https://raw.githubusercontent.com/m1ch/iocage-plugin-nextcloud/master/overlay/usr/local/etc/php-fpm.d/nextcloud.conf > ${jail_root}/usr/local/etc/php-fpm.d/nextcloud.conf
curl https://raw.githubusercontent.com/m1ch/iocage-plugin-nextcloud/master/overlay/usr/local/etc/nginx/nginx.conf > ${jail_root}/usr/local/etc/nginx/nginx.conf
curl https://raw.githubusercontent.com/m1ch/iocage-plugin-nextcloud/master/overlay/usr/local/etc/nginx/conf.d/nextcloud.conf.template > ${jail_root}/usr/local/etc/nginx/conf.d/nextcloud.conf
curl https://raw.githubusercontent.com/m1ch/iocage-plugin-nextcloud/master/overlay/usr/local/bin/occ > ${jail_root}/usr/local/bin/occ
chmod +x ${jail_root}/usr/local/bin/occ


sed -i '' -E 's#^;?emergency_restart_threshold .*$#emergency_restart_threshold = 10#' ${jail_root}/usr/local/etc/php-fpm.conf
sed -i '' -E 's#^;?emergency_restart_interval.*$#emergency_restart_interval = 1m#' ${jail_root}/usr/local/etc/php-fpm.conf
sed -i '' -E 's#^;?process_control_timeout.*$#process_control_timeout = 10s#' ${jail_root}/usr/local/etc/php-fpm.conf
sed -i '' -E 's#^;?include.*$#include=/usr/local/etc/php-fpm.d/*/*.conf#' ${jail_root}/usr/local/etc/php-fpm.conf
sed -i '' 's/.*pm.max_children.*/pm.max_children=10/' ${jail_root}/usr/local/etc/php-fpm.d/nextcloud.conf

iocage exec ${jail_name} echo "env[PATH] = $PATH" >> /usr/local/etc/php-fpm.d/nextcloud.conf




# create sessions tmp dir outside nextcloud installation
mkdir -p /usr/local/www/nextcloud-sessions-tmp >/dev/null 2>/dev/null
chmod o-rwx /usr/local/www/nextcloud-sessions-tmp
chown -R www:www /usr/local/www/nextcloud-sessions-tmp
chown -R www:www /usr/local/www/nextcloud/apps-pkg

chmod -R o-rwx /usr/local/www/nextcloud

#updater needs this
chown -R www:www /usr/local/www/nextcloud










iocage stop $NEXTCLOUD_JAIL

# Mount sockets
iocage fstab -l nextcloud
iocage fstab -a darkhorse /medialake2/movies /mnt/movies nullfs rw 0 0
iocage fstab -a nextcloud /mnt/pool01/iocage/jails/mariadb/root/tmp/ /var/run/mysql nullfs rw 0 0
/mnt/pool01/iocage/jails/mariadb/root/tmp/


