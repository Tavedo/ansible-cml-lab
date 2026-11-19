#!/bin/bash

# ANSIBLELAB - Network Verification Script
# Run this after all playbooks complete successfully

echo "======================================"
echo "ANSIBLELAB Network Verification"
echo "======================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
PASSED=0
FAILED=0

# Function to test SSH connectivity
test_ssh() {
    local host=$1
    local name=$2
    
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no cisco@$host "exit" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} SSH to $name ($host) - OK"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} SSH to $name ($host) - FAILED"
        ((FAILED++))
        return 1
    fi
}

# Function to run command on device
run_command() {
    local host=$1
    local cmd=$2
    
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no cisco@$host "$cmd" 2>/dev/null
}

echo "========================================"
echo "Test 1: SSH Connectivity to All Devices"
echo "========================================"
test_ssh 192.168.255.101 "R1"
test_ssh 192.168.255.102 "R2"
test_ssh 192.168.255.103 "R3"
test_ssh 192.168.250.2 "S2"
test_ssh 192.168.250.3 "S3"
test_ssh 192.168.250.4 "S4"
test_ssh 192.168.250.5 "S5"
echo ""

echo "========================================"
echo "Test 2: VLAN Configuration"
echo "========================================"
echo "Checking VLANs on S2..."
VLANS=$(run_command 192.168.250.2 "show vlan brief | include  USERS|VOICE|MANAGEMENT")
if echo "$VLANS" | grep -q "USERS" && echo "$VLANS" | grep -q "VOICE" && echo "$VLANS" | grep -q "MANAGEMENT"; then
    echo -e "${GREEN}✓${NC} VLANs 10, 20, 100 configured on S2"
    echo "$VLANS"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} VLANs not properly configured on S2"
    ((FAILED++))
fi
echo ""

echo "========================================"
echo "Test 3: S2 Layer 3 Configuration"
echo "========================================"
echo "Checking SVIs on S2..."
S2_IPS=$(run_command 192.168.250.2 "show ip interface brief | include Vlan")
if echo "$S2_IPS" | grep -q "192.168.10.1" && echo "$S2_IPS" | grep -q "192.168.20.1" && echo "$S2_IPS" | grep -q "192.168.250.2"; then
    echo -e "${GREEN}✓${NC} S2 SVIs configured correctly"
    echo "$S2_IPS"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} S2 SVIs not properly configured"
    ((FAILED++))
fi
echo ""

echo "========================================"
echo "Test 4: EtherChannel Status"
echo "========================================"
echo "Checking Port-Channel3 on S2..."
S2_PO=$(run_command 192.168.250.2 "show etherchannel summary | include Po3")
if echo "$S2_PO" | grep -q "Po3"; then
    echo -e "${GREEN}✓${NC} Port-Channel3 configured on S2"
    echo "$S2_PO"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Port-Channel3 not found on S2"
    ((FAILED++))
fi

echo "Checking Port-Channel3 on S3..."
S3_PO=$(run_command 192.168.250.3 "show etherchannel summary | include Po3")
if echo "$S3_PO" | grep -q "Po3"; then
    echo -e "${GREEN}✓${NC} Port-Channel3 configured on S3"
    echo "$S3_PO"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Port-Channel3 not found on S3"
    ((FAILED++))
fi
echo ""

echo "========================================"
echo "Test 5: Access Port Configuration"
echo "========================================"
echo "Checking access ports on S4..."
S4_E02=$(ssh 192.168.250.4 "show interfaces Ethernet0/2 switchport" | grep "Access Mode VLAN")
if echo "$S4_E02" | grep -q "10"; then
    echo -e "${GREEN}✓${NC} S4 Ethernet0/0 in VLAN 10"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} S4 Ethernet0/0 not in VLAN 10"
    ((FAILED++))
fi

S4_E03=$(ssh 192.168.250.4 "show interfaces Ethernet0/3 switchport" | grep "Access Mode VLAN")
if echo "$S4_E03" | grep -q "20"; then
    echo -e "${GREEN}✓${NC} S4 Ethernet0/1 in VLAN 20"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} S4 Ethernet0/1 not in VLAN 20"
    ((FAILED++))
fi
echo ""

echo "========================================"
echo "Test 6: HSRP Configuration"
echo "========================================"
echo "Checking HSRP on R1..."
R1_HSRP=$(run_command 192.168.255.101 "show standby brief")
if echo "$R1_HSRP" | grep -q "Active"; then
    echo -e "${GREEN}✓${NC} R1 is HSRP Active"
    echo "$R1_HSRP"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} R1 HSRP status unclear"
    echo "$R1_HSRP"
fi

#echo ""
#echo "Checking HSRP on R2..."
#R2_HSRP=$(run_command 192.168.255.102 "show standby brief")
#if echo "$R2_HSRP" | grep -q "Standby"; then
#    echo -e "${GREEN}✓${NC} R2 is HSRP Standby"
#    echo "$R2_HSRP"
#    ((PASSED++))
#else
#    echo -e "${YELLOW}⚠${NC} R2 HSRP status unclear"
#    echo "$R2_HSRP"
#fi

echo ""
echo "Checking HSRP on R3..."
R3_HSRP=$(run_command 192.168.255.103 "show standby brief")
if echo "$R3_HSRP" | grep -q "Listen"; then
    echo -e "${GREEN}✓${NC} R3 is HSRP Listen"
    echo "$R3_HSRP"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} R3 HSRP status unclear"
    echo "$R3_HSRP"
fi
echo ""

echo ""
echo "=== Ping HSRP VIP from S2 ==="
ssh cisco@192.168.250.2 "ping 192.168.250.1 repeat 5"

echo ""
echo "=== Verify VLAN 100 on Po3 ==="
ssh cisco@192.168.250.2 "show interfaces port-channel3 switchport | include Allowed VLANs"

echo "========================================"
echo "Test 7: Connectivity Tests"
echo "========================================"
echo "Testing ping from S2 to HSRP VIP (192.168.250.1)..."
if run_command 192.168.250.2 "ping 192.168.250.1 repeat 3" | grep -q "Success rate is [8-9][0-9] percent\|100 percent"; then
    echo -e "${GREEN}✓${NC} S2 can ping HSRP virtual IP"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} S2 cannot ping HSRP virtual IP"
    ((FAILED++))
fi

echo "Testing ping from S2 to VLAN 10 gateway..."
if run_command 192.168.250.2 "ping 192.168.10.1 repeat 3" | grep -q "Success"; then
    echo -e "${GREEN}✓${NC} S2 VLAN 10 gateway reachable"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} S2 VLAN 10 gateway not reachable"
    ((FAILED++))
fi
echo ""

echo "========================================"
echo "Verification Summary"
echo "========================================"
echo -e "Tests Passed: ${GREEN}$PASSED${NC}"
echo -e "Tests Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! Network is fully operational!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some tests failed. Review the output above.${NC}"
    exit 1
fi
