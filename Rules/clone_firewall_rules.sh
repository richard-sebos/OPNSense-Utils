#!/bin/bash
# ==============================================================================
# Sebos Technology - Batch Clone Firewall Rules with Interface Change
# Date: November 19, 2024
# Status: Development, Pretesting
# ==============================================================================
# Description:
# This script clones existing firewall rules on OPNsense, allowing you to 
# specify a new source interface for each cloned rule. It modifies the 
# configuration file and reloads the firewall rules.
#
# Usage:
#   ./clone_firewall_rules.sh -i <source_rule_id> -n <number_of_clones> -s <new_source_interface>
#
# Parameters:
#   -i  ID of the source rule to clone
#   -n  Number of clones to create
#   -s  New source interface for the cloned rules (e.g., LAN, WAN)
#
# Author: Sebos Technology
# ==============================================================================

# Function to display usage instructions
usage() {
    echo "Usage: $0 -i <source_rule_id> -n <number_of_clones> -s <new_source_interface>"
    exit 1
}

# Parse command-line arguments
while getopts "i:n:s:h" opt; do
    case $opt in
        i) SOURCE_RULE_ID=$OPTARG ;;
        n) NUMBER_OF_CLONES=$OPTARG ;;
        s) NEW_SOURCE_INTERFACE=$OPTARG ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Ensure required parameters are provided
if [[ -z "$SOURCE_RULE_ID" || -z "$NUMBER_OF_CLONES" || -z "$NEW_SOURCE_INTERFACE" ]]; then
    echo "Error: Source rule ID, number of clones, and new source interface are required."
    usage
fi

# Path to the OPNsense configuration file
CONFIG_FILE="/conf/config.xml"
BACKUP_FILE="${CONFIG_FILE}.bak.$(date +%F_%T)"

# Backup the current configuration
echo "Backing up current configuration to ${BACKUP_FILE}..."
cp $CONFIG_FILE $BACKUP_FILE

# Extract the source rule
echo "Extracting source rule with ID ${SOURCE_RULE_ID}..."
SOURCE_RULE=$(xmlstarlet sel -t -c "//rule[ruleid='${SOURCE_RULE_ID}']" $CONFIG_FILE)

if [[ -z "$SOURCE_RULE" ]]; then
    echo "Error: Source rule ID ${SOURCE_RULE_ID} not found in configuration."
    exit 1
fi

# Clone the rule with a new source interface
echo "Cloning rule ${SOURCE_RULE_ID} ${NUMBER_OF_CLONES} times with new source interface '${NEW_SOURCE_INTERFACE}'..."
for i in $(seq 1 $NUMBER_OF_CLONES); do
    NEW_RULE_ID=$(uuidgen) # Generate a unique ID for the new rule
    CLONED_RULE=$(echo "$SOURCE_RULE" | sed -e "s/<ruleid>${SOURCE_RULE_ID}<\/ruleid>/<ruleid>${NEW_RULE_ID}<\/ruleid>/" \
                                            -e "s|<interface>.*</interface>|<interface>${NEW_SOURCE_INTERFACE}</interface>|")
    # Inject the cloned rule into the configuration
    xmlstarlet ed -L -s "//filter/rule" -t elem -n rule -v "$CLONED_RULE" $CONFIG_FILE
    echo "Created clone #$i with ID ${NEW_RULE_ID}, interface set to ${NEW_SOURCE_INTERFACE}"
done

# Reload the firewall rules
echo "Reloading the firewall rules..."
configctl filter reload

echo "Cloning completed successfully. Verify the rules in the Web GUI."
