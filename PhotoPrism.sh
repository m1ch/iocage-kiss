#!/bin/sh

# https://docs.photoprism.org/getting-started/freebsd/

PHOTOPRISM_JAIL="photoprism"
MARIADB_JAIL="mariadb"

# MARIADB_IP="10.23.10.61"
PHOTOPRISM_DB=$PHOTOPRISM_JAIL

SOCKET_DIR="sockets/mysql"
DATA_DIR="servicedata/${PHOTOPRISM_JAIL}"


# initial setup
jail_pool=$(iocage get -p)
jail_dataset="${jail_pool}/iocage"
jail_path=$(zfs list -o mountpoint ${jail_dataset} | tail -n 1)

if test ! -d $jail_path/sockets; then
  echo "Create sockets dir";
  zfs create ${jail_dataset}/sockets
fi
if test ! -d $jail_path/servicedata; then
  echo "Create servicedata dir";
  zfs create ${jail_dataset}/servicedata
fi
if test ! -d $jail_path/passwords; then
  echo "Create passwords dir";
  zfs create ${jail_dataset}/passwords
fi
if test ! -d $jail_path/servicedata/${PHOTOPRISM_JAIL}; then
  echo "Create servicedata dir ${PHOTOPRISM_JAIL}";
  zfs create ${jail_dataset}/servicedata/${PHOTOPRISM_JAIL}
fi

# Passwords
if test ! -f $jail_path/passwords/photoprism.db.pw; then
  echo "Create passwords file $jail_path/passwords/photoprism.db.pw";
  echo $(cat /dev/urandom | strings | tr -dc A-Za-z0-9\?\!\.\#\(\) | head -c86; echo) > $jail_path/passwords/photoprism.db.pw
fi
PHOTOPRISM_DB_PW=$(cat $jail_path/passwords/photoprism.db.pw)

if test ! -f $jail_path/passwords/photoprism.pw; then
  echo "Create passwords file $jail_path/passwords/photoprism.pw";
  echo $(cat /dev/urandom | strings | tr -dc A-Za-z0-9\?\!\.\#\(\) | head -c86; echo) > $jail_path/passwords/photoprism.pw
fi
PHOTOPRISM_PW=$(cat $jail_path/passwords/photoprism.pw)

# Check if Jail exist and exit if exist
if iocage list | grep " ${PHOTOPRISM_JAIL} " > /dev/null; then 
  echo "Jail ${PHOTOPRISM_JAIL} allready exist ... exit"
  exit;
fi

# Check if DB server exist and create if not
if (iocage list | grep " x${MARIADB_JAIL} " > /dev/null); then 
  echo "${MARIADB_JAIL} exist ... continue";  
else
  echo "TODO: install mariadb"; 
fi

PW_MARIADB=$(cat ${jail_path}/jails/${MARIADB_JAIL}/root/root/mysqlrootpassword)
# iocage exec $MARIADB_JAIL bash -c "mysql -u root -p\"$PW_MARIADB\""<<EOF
# SHOW DATABASES;
# EOF

# Check if Database exist and create if not

iocage exec $MARIADB_JAIL bash -c "mysql -u root -p\"$PW_MARIADB\""<<EOF
# DROP DATABASE IF EXISTS ${PHOTOPRISM_DB};
# DROP USER IF EXISTS 'photoprism'@'%';
SHOW DATABASES;
select user, host from mysql.user;
EOF

createDB()
{
iocage exec $MARIADB_JAIL bash -c "mysql -u root -p\"$PW_MARIADB\""<<EOF
CREATE DATABASE ${PHOTOPRISM_DB}
  CHARACTER SET = 'utf8mb4'
  COLLATE = 'utf8mb4_unicode_ci';
CREATE USER 'photoprism'@'%' IDENTIFIED BY "${PHOTOPRISM_DB_PW}";
GRANT ALL PRIVILEGES ON ${PHOTOPRISM_DB}.* to 'photoprism'@'%';
FLUSH PRIVILEGES;
EOF
}

t=$(iocage exec $MARIADB_JAIL bash -c "mysql -u root -p\"$PW_MARIADB\""<<EOF | grep "^${PHOTOPRISM_DB}$"
show databases;
EOF
)
if test $t -a $t = "${PHOTOPRISM_DB}"; then
  echo "DB exist ... continue";
else
  echo "Create DB ${PHOTOPRISM_DB}"
  createDB
fi

# Create Jail
jail_root=${jail_path}/jails/${PHOTOPRISM_JAIL}/root
iocage create -r 12.2-RELEASE -n ${PHOTOPRISM_JAIL} vnet=On dhcp=On nat=Off \
        interfaces="vnet0:bridge10"
# mkdir -p ${jail_root}/mnt/{homevideo,tvshows,music,movie,downloads,cloud_data}
# mkdir -p ${jail_root}/usr/local/www/nextcloud
mkdir -p ${jail_root}/var/run/mysql
mkdir -p ${jail_root}/var/db/photoprism
iocage fstab -a ${PHOTOPRISM_JAIL} ${jail_path}/sockets/mariadb                   /var/run/mysql      nullfs ro 0 0
iocage fstab -a ${PHOTOPRISM_JAIL} ${jail_path}/servicedata/${PHOTOPRISM_JAIL}    /var/db/photoprism  nullfs rw 0 0


# Clone Git repository
# zfs create ${jail_pool}/iocage/${DATA_DIR}
# cd ${jail_path}/${DATA_DIR}
mkdir -p ${jail_root}/opt/
cd ${jail_root}/opt/
# git clone https://github.com/huo-ju/photoprism-freebsd-port
fetch https://github.com/psa/photoprism-freebsd-port/releases/download/2021-11-30/photoprism-g20211130-FreeBSD-12.2-noAVX.pkg
cd ${jail_path}

# install pp
iocage start ${PHOTOPRISM_JAIL}

### in jail:
iocage exec ${PHOTOPRISM_JAIL} sh<<EOF
uname -a
export ASSUME_ALWAYS_YES="yes"
pkg update
# pkg install -y bash bazel029 git gmake go npm-node14 wget python38 build
# pkg install -y p5-Image-ExifTool ffmpeg

# wget https://github.com/psa/photoprism-freebsd-port/releases/download/2021-11-30/photoprism-g20211130-FreeBSD-12.2-noAVX.pkg
pkg install /opt/photoprism-g20211130-FreeBSD-12.2-noAVX.pkg

# cd /opt/photoprism-freebsd-port
# make config
# make && make install

echo "" >> /etc/rc.conf
echo 'photoprism_enable="YES"' >> /etc/rc.conf
echo 'photoprism_assetspath="/var/db/photoprism/assets"' >> /etc/rc.conf
echo 'photoprism_storagepath="/var/db/photoprism/storage"' >> /etc/rc.conf
EOF

iocage exec ${PHOTOPRISM_JAIL} sh<<EOF
photoprism --assets-path=/var/db/photoprism/assets\
           --storage-path=/var/db/photoprism/storage\
           --originals-path=/var/db/photoprism/storage/originals\
           --import-path=/var/db/photoprism/storage/import\
           passwd
#           ${PHOTOPRISM_PW}

EOF

iocage exec ${PHOTOPRISM_JAIL} sh<<EOF
photoprism config
EOF

exit

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
