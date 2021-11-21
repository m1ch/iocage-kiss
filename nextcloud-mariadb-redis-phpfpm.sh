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


pool01/iocage/sockets/mariadb

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


iocage stop $NEXTCLOUD_JAIL

# Mount sockets
iocage fstab -l nextcloud
iocage fstab -a darkhorse /medialake2/movies /mnt/movies nullfs rw 0 0
iocage fstab -a nextcloud /mnt/pool01/iocage/jails/mariadb/root/tmp/ /var/run/mysql nullfs rw 0 0
/mnt/pool01/iocage/jails/mariadb/root/tmp/


