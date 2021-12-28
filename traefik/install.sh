#!/bin/sh

## Run as root for port 80/443 to work!


# install nextcloud
jail_name = "traefik"
jail_release = "12.2-RELEASE"

jail_pool = $(iocage get -p)
jail_path = $(zfs list -o mountpoint ${jail_pool}/iocage | tail -n 1)
jail_root = ${jail_path}/jails/${jail_name}/root

iocage create -r ${jail_release} -n ${jail_name} vnet=On dhcp=On nat=Off \
        interfaces="vnet0:bridge10"ll

mkdir -p ${jail_root}/usr/local/etc/traefik.d
mkdir -p ${jail_root}/var/log/traefik
mkdir -p ${jail_root}/usr/local/etc/newsyslog.conf.d
toutch ${jail_root}/usr/local/etc/newsyslog.conf.d/traefik.conf

iocage start ${jail_name}
iocage exec ${jail_name} pkg update

iocage pkg ${jail_name} install \
  curl \
  traefik
  
  # logrotate

iocage exec ${jail_name} chown traefik:traefik /var/log/traefik
iocage exec ${jail_name} chmod 750 /var/log/traefik

cat << EOF > /mnt/pool01/iocage/jails/traefik12/root/usr/local/etc/newsyslog.conf.d/traefik.conf
# logfilename                         [owner:group]     mode count size when  flags [/pid_file]          [sig_num]
/var/log/traefik/traefik.log          traefik:traefik   640  5     1000 *     J     /var/run/traefik.pid 30
/var/log/traefik/traefik_access.log   traefik:traefik   640  5     1000 *     J     /var/run/traefik.pid 30

EOF
