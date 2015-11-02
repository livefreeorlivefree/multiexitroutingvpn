#!/bin/bash

if [[ $UID -ne 0 ]]
then
    echo "Be a man, run me as root"
    exit 256
fi

. vars/./environment.sh

apt-get install ipset iproute conntrack iptables openvpn

mkdir $SCRIPT_DIR
mkdir $CONFIG_DIR
mkdir $LOG_DIR
cp -r config/* $CONFIG_DIR
cp -r . $SCRIPT_DIR
cp -r vars/* $SCRIPT_DIR
rm -rf $SCRIPT_DIR/config
ln -s /sbin/mevr/mevr.sh /sbin/mevr/mevr

patch /etc/inittab inittab.patch

cp mevr.service /etc/systemd/system/mevr.service

systemctl enable mevr.service
systemctl start mevr.service

echo "installation completed"
