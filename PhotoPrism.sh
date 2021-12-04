#!/bin/sh

# https://docs.photoprism.org/getting-started/freebsd/


MARIADB_JAIL="mariadb"
# MARIADB_IP="10.23.10.61"

PHOTOPRISM_JAIL="photoprism"

SOCKET_DIR="sockets/mysql"
DATA_DIR="servicedata/${PHOTOPRISM_JAIL}"

# initial setup
jail_pool=$(iocage get -p)
jail_path=$(zfs list -o mountpoint ${jail_pool}/iocage | tail -n 1)

# Check if Jail exist and exit if exist

# Check if DB server exist and create if not

# Check if Database exist and create if not

# Create Jail
jail_root=${jail_path}/jails/${PHOTOPRISM_JAIL}/root
iocage create -r 12.2-RELEASE -n ${PHOTOPRISM_JAIL} vnet=On dhcp=On nat=Off \
        interfaces="vnet0:bridge10"
# mkdir -p ${jail_root}/mnt/{homevideo,tvshows,music,movie,downloads,cloud_data}
# mkdir -p ${jail_root}/usr/local/www/nextcloud
mkdir -p ${jail_root}/var/run/{mysql}        
iocage fstab -a ${PHOTOPRISM_JAIL} /mnt/pool01/iocage/sockets/mariadb         /var/run/mysql              nullfs ro 0 0

# Clone Git repository
# zfs create ${jail_pool}/iocage/${DATA_DIR}
# cd ${jail_path}/${DATA_DIR}
mkdir -p ${jail_root}/opt/
cd ${jail_root}/opt/
git clone https://github.com/huo-ju/photoprism-freebsd-port

# install pp
### in jail:
cd /opt/photoprism-freebsd-port
make config
make && make install

# ## Add entries to rc.conf
photoprism_enable="YES"
photoprism_assetspath="/var/db/photoprism/assets"
photoprism_storagepath="/var/db/photoprism/storage"

## Set an initial admin password (fresh install)
photoprism --assets-path=/var/db/photoprism/assets --storage-path=/var/db/photoprism/storage --originals-path=/var/db/photoprism/storage/originals --import-path=/var/db/photoprism/storage/import passwd

## Run the service
service photoprism start
zfs create pool01/iocage/sockets/mysql


jail_pool=$(iocage get -p)
jail_path = $(zfs list -o mountpoint ${jail_pool}/iocage | tail -n 1)
jail_root = ${jail_path}/jails/${jail_name}/root
