# PC Connectivity Testing Guide

## 🎯 Objective
Verify that end devices (PCs) can communicate through the network with proper VLAN segmentation and inter-VLAN routing.

---

## 📋 Expected PC Configuration

Based on your network design:

| PC | Connected to Switch | Port | VLAN | Expected Subnet | Gateway |
|----|---------------------|------|------|-----------------|---------|
| PC-1 | S4 | Ethernet0/2 | 10 | 192.168.10.0/24 | 192.168.10.1 |
| PC-2 | S4 | Ethernet0/3 | 20 | 192.168.20.0/24 | 192.168.20.1 |
| PC-3 | S5 | Ethernet0/2 | 10 | 192.168.10.0/24 | 192.168.10.1 |
| PC-4 | S5 | Ethernet0/3 | 20 | 192.168.20.0/24 | 192.168.20.1 |

---

## 🔧 Step 1: Configure PC IP Addresses

### Connect to PCs via VNC or Console

**PC-1 Configuration:**
```bash
# Access PC-1 console or VNC
# Assuming Alpine Linux

# Configure static IP
sudo ip addr add 192.168.10.10/24 dev eth0
sudo ip link set eth0 up
sudo ip route add default via 192.168.10.1

# Verify
ip addr show eth0
ip route
```

**PC-2 Configuration:**
```bash
# Access PC-2 console or VNC

sudo ip addr add 192.168.20.10/24 dev eth0
sudo ip link set eth0 up
sudo ip route add default via 192.168.20.1

ip addr show eth0
ip route
```

**PC-3 Configuration:**
```bash
# Access PC-3 console or VNC

sudo ip addr add 192.168.10.20/24 dev eth0
sudo ip link set eth0 up
sudo ip route add default via 192.168.10.1

ip addr show eth0
ip route
```

**PC-4 Configuration:**
```bash
# Access PC-4 console or VNC

sudo ip addr add 192.168.20.20/24 dev eth0
sudo ip link set eth0 up
sudo ip route add default via 192.168.20.1

ip addr show eth0
ip route
```

---

## 🧪 Test 2: Intra-VLAN Connectivity

### Test VLAN 10 Communication (PC-1 to PC-3)

**On PC-1:**
```bash
ping 192.168.10.20 -c 5
```

**Expected:** 
- ✅ Success rate should be 100%
- Both PCs are in VLAN 10, so they communicate via Layer 2

**On PC-3:**
```bash
ping 192.168.10.10 -c 5
```

**Expected:**
- ✅ Success rate should be 100%

---

### Test VLAN 20 Communication (PC-2 to PC-4)

**On PC-2:**
```bash
ping 192.168.20.20 -c 5
```

**Expected:**
- ✅ Success rate should be 100%
- Both PCs are in VLAN 20

**On PC-4:**
```bash
ping 192.168.20.10 -c 5
```

**Expected:**
- ✅ Success rate should be 100%

---

## 🧪 Test 3: Gateway Connectivity

### Test PC-1 to its Gateway (S2)

**On PC-1:**
```bash
ping 192.168.10.1 -c 5
```

**Expected:**
- ✅ Should reach S2's VLAN 10 SVI

### Test PC-2 to its Gateway (S2)

**On PC-2:**
```bash
ping 192.168.20.1 -c 5
```

**Expected:**
- ✅ Should reach S2's VLAN 20 SVI

---

## 🧪 Test 4: Inter-VLAN Routing

### Test VLAN 10 to VLAN 20 (PC-1 to PC-2)

**On PC-1:**
```bash
ping 192.168.20.10 -c 5
```

**Expected:**
- ✅ Success! Traffic should route through S2
- Path: PC-1 → S4 → S2 (VLAN 10 SVI) → S2 (VLAN 20 SVI) → S4 → PC-2

### Test VLAN 20 to VLAN 10 (PC-2 to PC-1)

**On PC-2:**
```bash
ping 192.168.10.10 -c 5
```

**Expected:**
- ✅ Success! Traffic should route through S2

---

## 🧪 Test 5: Test Through HSRP Gateway

### Test PC to Management VLAN (through R1)

**On PC-1:**
```bash
ping 192.168.250.1 -c 5
```

**Expected:**
- ✅ Should reach HSRP virtual IP on R1

### Test PC to Switch Management IPs

**On PC-1:**
```bash
ping 192.168.250.2 -c 5  # S2
ping 192.168.250.3 -c 5  # S3
ping 192.168.250.4 -c 5  # S4
```

**Expected:**
- ⚠️ May fail if routing not configured for 192.168.250.0/24 from data VLANs
- This would require additional routes on S2

---

## 🧪 Test 6: Traceroute Analysis

### Trace path from PC-1 to PC-2 (Inter-VLAN)

**On PC-1:**
```bash
traceroute 192.168.20.10
```

**Expected Path:**
```
1. 192.168.10.1 (S2 VLAN 10 SVI)
2. 192.168.20.10 (PC-2)
```

### Trace path from PC-1 to PC-3 (Same VLAN)

**On PC-1:**
```bash
traceroute 192.168.10.20
```

**Expected:**
```
1. 192.168.10.20 (PC-3) - Direct Layer 2 communication
```

---

## 🔍 Troubleshooting

### If PCs cannot ping their gateway:

1. **Verify VLAN assignment on switch:**
   ```bash
   # On S4/S5
   show vlan brief
   show interfaces Ethernet0/2 switchport
   ```

2. **Verify SVI is up on S2:**
   ```bash
   # On S2
   show ip interface brief | include Vlan
   show interfaces Vlan10
   ```

3. **Check PC IP configuration:**
   ```bash
   # On PC
   ip addr show
   ip route
   ```

### If PCs cannot ping each other (same VLAN):

1. **Verify both are in same VLAN:**
   ```bash
   # On S4/S5
   show vlan id 10
   ```

2. **Check trunk connectivity:**
   ```bash
   # On S4
   show interfaces trunk
   ```

3. **Verify STP is converged:**
   ```bash
   show spanning-tree vlan 10
   ```

### If Inter-VLAN routing doesn't work:

1. **Verify IP routing is enabled on S2:**
   ```bash
   # On S2
   show ip route
   show run | include ip routing
   ```

2. **Check S2 can reach both VLANs:**
   ```bash
   # From S2
   ping 192.168.10.1
   ping 192.168.20.1
   ```

3. **Verify PC default gateway:**
   ```bash
   # On PC
   ip route
   # Should show: default via 192.168.10.1 (or .20.1)
   ```

---

## 📊 Expected Results Summary

| Test | Source | Destination | Expected Result |
|------|--------|-------------|-----------------|
| Intra-VLAN | PC-1 (VLAN 10) | PC-3 (VLAN 10) | ✅ Success (L2) |
| Intra-VLAN | PC-2 (VLAN 20) | PC-4 (VLAN 20) | ✅ Success (L2) |
| Gateway | PC-1 | 192.168.10.1 | ✅ Success |
| Gateway | PC-2 | 192.168.20.1 | ✅ Success |
| Inter-VLAN | PC-1 (VLAN 10) | PC-2 (VLAN 20) | ✅ Success (L3) |
| Inter-VLAN | PC-2 (VLAN 20) | PC-1 (VLAN 10) | ✅ Success (L3) |
| Cross-Switch | PC-1 (S4) | PC-4 (S5) | ✅ Success |
| HSRP VIP | Any PC | 192.168.250.1 | ⚠️ May need route |

---

## 🎉 Success Criteria

Your network is working correctly if:
- [ ] PCs in the same VLAN can communicate (Layer 2)
- [ ] PCs in different VLANs can communicate (Layer 3 via S2)
- [ ] All PCs can reach their default gateway
- [ ] Inter-VLAN routing works through S2
- [ ] Traffic flows correctly through trunk links
- [ ] EtherChannel between S2-S3 is utilized

---

## 📈 Advanced Testing

### Load Testing
Generate traffic between PCs to test EtherChannel load balancing:
```bash
# On PC-1, send large file to PC-3
dd if=/dev/zero bs=1M count=100 | nc -l 5000

# On PC-3
nc 192.168.10.10 5000 > /dev/null

# On S2, check EtherChannel distribution
show etherchannel 3 summary
show etherchannel 3 load-balance
```

### Broadcast Domain Test
```bash
# On PC-1
ping -b 192.168.10.255

# Should reach only VLAN 10 devices (PC-1, PC-3)
# Should NOT reach VLAN 20 devices
```

---

## 🔒 Security Verification

### Verify VLAN Isolation
From PC-1 (VLAN 10), attempt to send raw packets to PC-2 (VLAN 20):
- Should fail at Layer 2
- Only Layer 3 routing through S2 should work

### Verify PortFast/BPDU Guard
On S4/S5, try connecting a switch to access ports:
- Should see port err-disabled if BPDU received
- Confirms BPDU Guard is working

---

**Great job on completing the automation! Now verify everything works as designed! 🎯**
