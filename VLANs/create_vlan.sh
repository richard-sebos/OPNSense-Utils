#!/bin/bash
# ==============================================================================
# Sebos Technology - Persistent VLAN Creation Script
# Date: November 19, 2024
# Status: Development, Pretesting
# ==============================================================================
# Description:
# This script creates a VLAN configuration in OPNsense and makes it persistent
# by updating the /conf/config.xml file. After modification, it reloads
# the configuration to apply changes.
#
# Usage:
#   ./create_vlan_persistent.sh -i <parent_interface> -v <vlan_id> [-a <ip_address>] [-n <netmask>]
#
# Parameters:
#   -i  Parent interface (e.g., em0, igb1)
#   -v  VLAN ID (e.g., 10, 20)
#   -a  IP address to assign to VLAN (optional)
#   -n  Netmask to assign to VLAN (optional, default: 255.255.255.0)
#
# Author: Sebos Technology
# ==============================================================================

# Function to print usage instructions
usage() {
    echo "Usage: $0 -i <parent_interface> -v <vlan_id> [-a <ip_address>] [-n <netmask>]"
    echo "  -i  Parent interface (e.g., em0, igb1)"
    echo "  -v  VLAN ID (e.g., 10, 20)"
    echo "  -a  IP address to assign to VLAN (optional)"
    echo "  -n  Netmask to assign to VLAN (optional, default: 255.255.255.0)"
    exit 1
}

# Default values
NETMASK="255.255.255.0"

# Parse command-line arguments
while getopts "i:v:a:n:h" opt; do
    case $opt in
        i) PARENT_INTERFACE=$OPTARG ;;
        v) VLAN_ID=$OPTARG ;;
        a) IP_ADDRESS=$OPTARG ;;
        n) NETMASK=$OPTARG ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Check mandatory parameters
if [[ -z "$PARENT_INTERFACE" || -z "$VLAN_ID" ]]; then
    echo "Error: Parent interface and VLAN ID are required."
    usage
fi

# Path to the OPNsense configuration file
CONFIG_FILE="/conf/config.xml"

# Backup the original configuration file
echo "Backing up the current configuration..."
cp $CONFIG_FILE ${CONFIG_FILE}.bak.$(date +%F_%T)

# Check if VLAN configuration already exists
if grep -q "<vlan><if>$PARENT_INTERFACE</if><tag>$VLAN_ID</tag>" $CONFIG_FILE; then
    echo "VLAN $VLAN_ID on $PARENT_INTERFACE already exists in the configuration."
    exit 0
fi

# Add VLAN configuration to the config.xml file
echo "Adding VLAN $VLAN_ID on $PARENT_INTERFACE to the configuration..."
XML_ENTRY="
<vlan>
  <if>$PARENT_INTERFACE</if>
  <tag>$VLAN_ID</tag>
  <descr>VLAN_$VLAN_ID</descr>
</vlan>
"

# Inject the VLAN configuration
sed -i "/<vlans>/a ${XML_ENTRY}" $CONFIG_FILE

# Add interface assignment if IP address is specified
if [[ -n "$IP_ADDRESS" ]]; then
    INTERFACE_NAME="vlan${VLAN_ID}"
    echo "Adding interface assignment for VLAN ${VLAN_ID} with IP ${IP_ADDRESS}..."
    INTERFACE_ENTRY="
    <interface>
      <if>$INTERFACE_NAME</if>
      <descr>VLAN_$VLAN_ID</descr>
      <enable>1</enable>
      <ipaddr>$IP_ADDRESS</ipaddr>
      <subnet>${NETMASK}</subnet>
    </interface>
    "
    sed -i "/<interfaces>/a ${INTERFACE_ENTRY}" $CONFIG_FILE
fi

# Reload the configuration
echo "Reloading the configuration to apply changes..."
/usr/local/etc/rc.reload_all

# Confirm success
echo "VLAN $VLAN_ID on $PARENT_INTERFACE has been successfully added and made persistent."
echo "You can verify this in the OPNsense Web GUI or by inspecting /conf/config.xml."
