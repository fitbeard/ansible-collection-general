#!/bin/bash

# Set default values
DEFAULT_VM_RAM="2048"             # Default RAM in MB
DEFAULT_VM_CPU="2"                # Default number of CPUs
DEFAULT_VM_OS="rocky9"            # Default OS type
DEFAULT_VM_INTERFACE1="br.mgmt"   # Default first network interface
DEFAULT_VM_IMAGE_PATH="/data/vms" # Default QCOW2 image location

# Initialize variables with default values
VM_NAME=""
VM_RAM="$DEFAULT_VM_RAM"
VM_CPU="$DEFAULT_VM_CPU"
VM_OS="$DEFAULT_VM_OS"
VM_INTERFACE1="$DEFAULT_VM_INTERFACE1"
VM_IMAGE_PATH="$DEFAULT_VM_IMAGE_PATH"

# Function to display usage information
function usage {
    echo "Usage: $0 [--name <vm_name>] [--ram <ram_size>] [--cpu <cpu_count>]"
    echo "          [--os <os_type>] [--path <path_to_image>]"
    echo "          [--interface1 <interface>] [--interface2 <interface>]"
    echo "          [--interface3 <interface>] [--interface4 <interface>]"
    echo "  --name <vm_name>          Name of the virtual machine (mandatory)"
    echo "  --ram <ram_size>          Amount of RAM for the VM in MB (default: $DEFAULT_VM_RAM)"
    echo "  --cpu <cpu_count>         Number of CPUs for the VM (default: $DEFAULT_VM_CPU)"
    echo "  --os <os_type>            Operating system type (default: $DEFAULT_VM_OS)"
    echo "  --path <path_to_image>    QCOW2 image location (default: $DEFAULT_VM_IMAGE_PATH)"
    echo "  --interface1 <interface>  First network interface (default: $DEFAULT_VM_INTERFACE1)"
    echo "  --interface2 <interface>  Second network interface"
    echo "  --interface3 <interface>  Third network interface"
    echo "  --interface4 <interface>  Fourth network interface"
    exit 1
}

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            VM_NAME="$2"
            shift 2
            ;;
        --ram)
            VM_RAM="$2"
            shift 2
            ;;
        --cpu)
            VM_CPU="$2"
            shift 2
            ;;
        --os)
            VM_OS="$2"
            shift 2
            ;;
        --path)
            VM_IMAGE_PATH="$2"
            shift 2
            ;;
        --interface1)
            VM_INTERFACE1="$2"
            shift 2
            ;;
        --interface2)
            VM_INTERFACE2="$2"
            shift 2
            ;;
        --interface3)
            VM_INTERFACE3="$2"
            shift 2
            ;;
        --interface4)
            VM_INTERFACE4="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

# Check if VM_NAME is set
if [[ -z "$VM_NAME" ]]; then
    echo "Error: --name <vm_name> is mandatory."
    usage
fi

VM_SCRIPT="${VM_NAME}.sh"

# Check if the script file already exists
if [[ -e "$VM_SCRIPT" ]]; then
    read -p "Warning: $PWD/$VM_SCRIPT already exists. Overwrite? (y/n) " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborting script generation."
        exit 1
    fi
fi

# Function to get VNC ports from QEMU domain XML files
function get_vnc_ports {
  local vnc_ports=()
  local qemu_dir="/etc/libvirt/qemu/"

  # Iterate through all XML files in the QEMU directory
  if [[ -d "$qemu_dir" ]]; then
    for xml_file in "$qemu_dir"/*.xml; do
      if [[ -f "$xml_file" ]]; then  # Check if the file exists
        # Extract all 'port' attributes from <graphics type='vnc'> tags
        ports_in_file=$(grep -oP "<graphics[^>]+type='vnc'[^>]+port='[0-9]+'" "$xml_file" | sed -n "s/.*port='\([0-9]\+\)'.*/\1/p")

        # Append the extracted ports to the vnc_ports array
        vnc_ports+=($ports_in_file)
      fi
    done
  fi

  echo "${vnc_ports[@]}"
}

# Function to find random free TCP ports
function random_free_tcp_port {
  local ports="${1:-1}" interim="${2:-2048}" spacing=32
  local free_ports=()

  # Get taken ports from ss and VNC ports from QEMU domain XMLs
  local taken_ports=($(ss -tanl | awk '/LISTEN/ {print $4}' | grep -o '[0-9]*$' | sort -n | uniq))
  local vnc_ports=($(get_vnc_ports))

  # Merge taken and VNC ports, then sort and remove duplicates
  local all_taken_ports=($(echo "${taken_ports[@]}" "${vnc_ports[@]}" | tr ' ' '\n' | sort -n | uniq))

  interim=$(( interim + (RANDOM % spacing) ))

  for taken in "${all_taken_ports[@]}" 65535; do
    while [[ $interim -lt $taken && ${#free_ports[@]} -lt $ports ]]; do
      free_ports+=($interim)
      interim=$(( interim + spacing + (RANDOM % spacing) ))
    done
    interim=$(( interim > taken + spacing ? interim : taken + spacing + (RANDOM % spacing) ))
  done

  [[ ${#free_ports[@]} -ge $ports ]] || return 2

  printf '%d\n' "${free_ports[@]}"
}

# Function to generate MAC address suffix
generate_mac_suffix() {
    hexchars="0123456789ABCDEF"
    end=$( for i in {1..6}; do echo -n "${hexchars:$((RANDOM % 16)):1}"; done | sed 's/../:&/g' )
    echo "52:54:00$end"
}

VM_VNCPORT=$(random_free_tcp_port 1 6000)
VM_MAC1=$(generate_mac_suffix)

echo "virt-install \\" > "$VM_SCRIPT"
echo "  --autostart \\" >> "$VM_SCRIPT"
echo "  --name $VM_NAME \\" >> "$VM_SCRIPT"
echo "  --memory $VM_RAM \\" >> "$VM_SCRIPT"
echo "  --disk path=$VM_IMAGE_PATH/$VM_NAME.qcow2,bus=virtio,format=qcow2 \\" >> "$VM_SCRIPT"
echo "  --vcpus $VM_CPU \\" >> "$VM_SCRIPT"
echo "  --noautoconsole \\" >> "$VM_SCRIPT"
echo "  --machine q35 \\" >> "$VM_SCRIPT"
echo "  --os-variant $VM_OS --graphics vnc,listen=0.0.0.0,password=password,port=$VM_VNCPORT \\" >> "$VM_SCRIPT"

if [[ $VM_INTERFACE1 =~ "sriov-" ]]
then
	echo "  --network network=$VM_INTERFACE1,mac=$VM_MAC1,address.type=pci,address.domain=0,address.bus=1,address.slot=0,address.function=0 \\" >> "$VM_SCRIPT"
elif [[ $VM_INTERFACE1 =~ "macvtap-" ]]
then
	echo "  --network network=$VM_INTERFACE1,mac=$VM_MAC1,address.type=pci,address.domain=0,address.bus=1,address.slot=0,address.function=0,trustGuestRxFilters=yes \\" >> "$VM_SCRIPT"
elif [[ $VM_INTERFACE1 =~ "nat-" ]]
then
	echo "  --network network=$VM_INTERFACE1,mac=$VM_MAC1,address.type=pci,address.domain=0,address.bus=1,address.slot=0,address.function=0 \\" >> "$VM_SCRIPT"
else
	echo "  --network bridge=$VM_INTERFACE1,mac=$VM_MAC1,address.type=pci,address.domain=0,address.bus=1,address.slot=0,address.function=0 \\" >> "$VM_SCRIPT"
fi

if [ -n "${VM_INTERFACE2}" ]; then
   VM_MAC2=$(generate_mac_suffix)
if [[ $VM_INTERFACE2 =~ "sriov-" ]]
then
	echo "  --network network=$VM_INTERFACE2,mac=$VM_MAC2,address.type=pci,address.domain=0,address.bus=2,address.slot=0,address.function=0 \\" >> "$VM_SCRIPT"
elif [[ $VM_INTERFACE2 =~ "macvtap-" ]]
then
	echo "  --network network=$VM_INTERFACE2,mac=$VM_MAC2,address.type=pci,address.domain=0,address.bus=2,address.slot=0,address.function=0,trustGuestRxFilters=yes \\" >> "$VM_SCRIPT"
elif [[ $VM_INTERFACE2 =~ "nat-" ]]
then
	echo "  --network network=$VM_INTERFACE2,mac=$VM_MAC2,address.type=pci,address.domain=0,address.bus=2,address.slot=0,address.function=0 \\" >> "$VM_SCRIPT"
else
	echo "  --network bridge=$VM_INTERFACE2,mac=$VM_MAC2,address.type=pci,address.domain=0,address.bus=2,address.slot=0,address.function=0 \\" >> "$VM_SCRIPT"
fi
fi

if [ -n "${VM_INTERFACE3}" ]; then
   VM_MAC3=$(generate_mac_suffix)
if [[ $VM_INTERFACE3 =~ "sriov-" ]]
then
	echo "  --network network=$VM_INTERFACE3,mac=$VM_MAC3,address.type=pci,address.domain=0,address.bus=3,address.slot=0,address.function=0 \\" >> "$VM_SCRIPT"
elif [[ $VM_INTERFACE3 =~ "macvtap-" ]]
then
	echo "  --network network=$VM_INTERFACE3,mac=$VM_MAC3,address.type=pci,address.domain=0,address.bus=3,address.slot=0,address.function=0,trustGuestRxFilters=yes \\" >> "$VM_SCRIPT"
elif [[ $VM_INTERFACE3 =~ "nat-" ]]
then
	echo "  --network network=$VM_INTERFACE3,mac=$VM_MAC3,address.type=pci,address.domain=0,address.bus=3,address.slot=0,address.function=0 \\" >> "$VM_SCRIPT"
else
	echo "  --network bridge=$VM_INTERFACE3,mac=$VM_MAC3,address.type=pci,address.domain=0,address.bus=3,address.slot=0,address.function=0 \\" >> "$VM_SCRIPT"
fi
fi

if [ -n "${VM_INTERFACE4}" ]; then
   VM_MAC4=$(generate_mac_suffix)
if [[ $VM_INTERFACE4 =~ "sriov-" ]]
then
	echo "  --network network=$VM_INTERFACE4,mac=$VM_MAC4,address.type=pci,address.domain=0,address.bus=4,address.slot=0,address.function=0 \\" >> "$VM_SCRIPT"
elif [[ $VM_INTERFACE4 =~ "macvtap-" ]]
then
	echo "  --network network=$VM_INTERFACE4,mac=$VM_MAC4,address.type=pci,address.domain=0,address.bus=4,address.slot=0,address.function=0,trustGuestRxFilters=yes \\" >> "$VM_SCRIPT"
elif [[ $VM_INTERFACE4 =~ "nat-" ]]
then
	echo "  --network network=$VM_INTERFACE4,mac=$VM_MAC4,address.type=pci,address.domain=0,address.bus=4,address.slot=0,address.function=0 \\" >> "$VM_SCRIPT"
else
	echo "  --network bridge=$VM_INTERFACE4,mac=$VM_MAC4,address.type=pci,address.domain=0,address.bus=4,address.slot=0,address.function=0 \\" >> "$VM_SCRIPT"
fi
fi

echo "  --boot hd" >> "$VM_SCRIPT"
echo "*   Script $PWD/$VM_SCRIPT is generated and ready to use"
