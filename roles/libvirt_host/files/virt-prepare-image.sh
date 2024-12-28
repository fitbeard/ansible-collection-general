#!/bin/bash

MOUNTPATH="./$1"
IMAGE="./$1.qcow2"
FQDN="$1"
IP="$2"
PREFIX="$3"
GATEWAY="$4"

echo "* Mount image"
sudo LIBGUESTFS_BACKEND=direct guestmount -a $IMAGE -m /dev/sda2 $MOUNTPATH

echo "* Set nameserver"
echo "nameserver 8.8.8.8" | sudo tee $MOUNTPATH/etc/resolv.conf

echo "* Set hostname"
echo $FQDN | sudo tee $MOUNTPATH/etc/hostname

echo "* Wipe network configuration"
rm -fr $MOUNTPATH/etc/systemd/network/*

echo "* Set network configuration"
echo "* 001-link-mgmt.link"
sudo tee $MOUNTPATH/etc/systemd/network/001-link-mgmt.link <<EOF
[Match]
Path=pci-0000:01:00.0

[Link]
Description=Management interface
Name=mgmt
EOF

echo "* 201-link-mgmt.network"
sudo tee $MOUNTPATH/etc/systemd/network/201-link-mgmt.network <<EOF
[Match]
Name=mgmt

[Network]
DHCP=no
Address=$IP/$PREFIX
Gateway=$GATEWAY
EOF

echo "* Unmount image"
sudo umount $MOUNTPATH
