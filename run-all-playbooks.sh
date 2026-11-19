#!/bin/bash

# ANSIBLELAB - Complete Network Automation Script
# This script runs all playbooks in the correct order

set -e  # Exit on any error

PLAYBOOKS_DIR="./playbooks"
INVENTORY="./inventory.yml"

echo "======================================"
echo "ANSIBLELAB Network Automation"
echo "======================================"
echo ""

# Function to run a playbook with error checking
run_playbook() {
    local playbook=$1
    local description=$2
    
    echo "----------------------------------------"
    echo "Running: $description"
    echo "Playbook: $playbook"
    echo "----------------------------------------"
    
    if ansible-playbook -i "$INVENTORY" "$playbook"; then
        echo "✅ SUCCESS: $description"
        echo ""
    else
        echo "❌ FAILED: $description"
        echo "Please check the errors above and fix them before continuing."
        exit 1
    fi
}

# Step 0: Test connectivity
echo "Step 0: Testing Ansible connectivity to all devices..."
if ansible all -i "$INVENTORY" -m ping; then
    echo "✅ All devices are reachable via Ansible"
    echo ""
else
    echo "❌ Some devices are not reachable. Please check:"
    echo "   - Network connectivity"
    echo "   - SSH is enabled on devices"
    echo "   - Credentials in inventory.yml are correct"
    exit 1
fi

# Step 1: SSH and Security Setup
run_playbook "$PLAYBOOKS_DIR/00-ssh-setup.yml" \
    "Step 1: SSH and Security Configuration"

# Step 2: VLANs and Trunks
run_playbook "$PLAYBOOKS_DIR/01-vlans-trunks.yml" \
    "Step 2: VLAN and Trunk Configuration"

# Step 3: S2 Layer 3 Configuration
run_playbook "$PLAYBOOKS_DIR/02-s2-routing.yml" \
    "Step 3: S2 Layer 3 Switch Configuration"

# Step 4: EtherChannel Configuration
run_playbook "$PLAYBOOKS_DIR/03-etherchannel.yml" \
    "Step 4: EtherChannel Configuration (S2-S3)"

# Step 5: Access Ports Configuration
run_playbook "$PLAYBOOKS_DIR/04-access-ports.yml" \
    "Step 5: Access Ports Configuration (S4, S5)"

# Step 6: R1 Router Configuration
run_playbook "$PLAYBOOKS_DIR/10-r1-router.yml" \
    "Step 6: R1 Router-on-a-Stick Configuration"

# Step 7: R1 and R3 HSRP Configuration
run_playbook "$PLAYBOOKS_DIR/11-r1-r3-hsrp.yml" \
    "Step 7: R1 and R3 HSRP Configuration"

echo "======================================"
echo "✅ ALL PLAYBOOKS COMPLETED SUCCESSFULLY!"
echo "======================================"
echo ""
echo "Your ANSIBLELAB network is now fully configured with:"
echo "  - VLANs 10, 20, 100"
echo "  - Layer 3 routing on S2"
echo "  - EtherChannel between S2 and S3"
echo "  - Access ports on S4 and S5"
echo "  - Router-on-a-stick on R1"
echo "  - HSRP redundancy on R1, R2, R3"
echo ""
echo "Next steps:"
echo "  - Verify connectivity between PCs"
echo "  - Test HSRP failover"
echo "  - Check routing tables"
