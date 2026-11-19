#!/bin/bash
echo "=== R1 HSRP Status ==="
ssh cisco@192.168.255.101 "show standby brief"

echo ""
echo "=== R3 HSRP Status ==="
ssh cisco@192.168.255.103 "show standby brief"

echo ""
echo "=== Ping HSRP VIP from S2 ==="
ssh cisco@192.168.250.2 "ping 192.168.250.1 repeat 5"

echo ""
echo "=== Verify VLAN 100 on Po3 ==="
ssh cisco@192.168.250.2 "show interfaces Port-channel3 trunk | include 100"
