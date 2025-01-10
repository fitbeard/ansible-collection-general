#!/bin/bash

# Set default values
DEFAULT_IMAGE_NET_PREFIX="24" # Default IPv4 network prefix (255.255.255.0)
DEFAULT_IMAGE_DNS_SERVER="8.8.8.8" # Default DNS server

# Initialize variables with default values
IMAGE_NAME=""
IMAGE_NET_IP=""
IMAGE_NET_GW=""
IMAGE_NET_PREFIX="$DEFAULT_IMAGE_NET_PREFIX"
IMAGE_DNS_SERVER="$DEFAULT_IMAGE_DNS_SERVER"

# Function to display usage information
function usage {
    echo "Usage: $0 [--name <image_name>] [--ip <image_net_ip>] [--prefix <image_net_prefix>]"
    echo "          [--gateway <image_net_gw>] [--dns <image_net_dns>]"
    echo "  --name <image_name>          Name of the QCOW2 image without .qcow2 suffix (mandatory)"
    echo "  --ip <image_net_ip>          IPv4 address which will be injected (mandatory)"
    echo "  --prefix <image_net_prefix>  IPv4 network prefix which will be injected (default: $DEFAULT_IMAGE_NET_PREFIX)"
    echo "  --gateway <image_net_gw>     IPv4 gateway address which will be injected (mandatory)"
    echo "  --dns <image_net_dns>        Dns server address which will be injected (default: $DEFAULT_IMAGE_DNS_SERVER)"
    exit 1
}

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --ip)
            IMAGE_NET_IP="$2"
            shift 2
            ;;
        --prefix)
            IMAGE_NET_PREFIX="$2"
            shift 2
            ;;
        --gateway)
            IMAGE_NET_GW="$2"
            shift 2
            ;;
        --dns)
            IMAGE_DNS_SERVER="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

# Check if IMAGE_NAME is set
if [[ -z "$IMAGE_NAME" ]]; then
    echo "Error: --name <image_name> is mandatory."
    usage
fi

# Check if IMAGE_NET_IP is set
if [[ -z "$IMAGE_NET_IP" ]]; then
    echo "Error: --ip <image_net_ip> is mandatory."
    usage
fi

# Check if IMAGE_NET_GW is set
if [[ -z "$IMAGE_NET_GW" ]]; then
    echo "Error: --gateway <image_net_gw> is mandatory."
    usage
fi

# Check if the temporary mount directory already exists
if [[ -e "$IMAGE_NAME" ]]; then
    read -p "Warning: $PWD/$IMAGE_NAME already exists. Use it for image mounting? (y/n) " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborting."
        exit 1
    fi
fi

echo "* Create directory for image mounting $PWD/$IMAGE_NAME"
mkdir -p $PWD/$IMAGE_NAME

MOUNTPATH="./$IMAGE_NAME"
IMAGE="./$IMAGE_NAME.qcow2"
FQDN="$IMAGE_NAME"
IP="$IMAGE_NET_IP"
PREFIX="$IMAGE_NET_PREFIX"
GATEWAY="$IMAGE_NET_GW"
DNS="$IMAGE_DNS_SERVER"

echo "* Mount image"
sudo LIBGUESTFS_BACKEND=direct guestmount -a $IMAGE -m /dev/sda2 $MOUNTPATH

echo "* Set nameserver"
echo "nameserver $DNS" | sudo tee $MOUNTPATH/etc/resolv.conf

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
