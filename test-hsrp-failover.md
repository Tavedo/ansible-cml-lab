# HSRP Failover Testing Guide

## 🎯 Objective
Test that HSRP provides gateway redundancy by failing over from R1 to R2, then to R3.

---

## 📋 Pre-Test Verification

### Step 1: Check Initial HSRP State
Connect to each router and verify HSRP status:

**On R1:**
```bash
ssh cisco@192.168.255.101
enable
show standby brief
```

**Expected:**
```
Interface   Grp  Pri P State    Active          Standby         Virtual IP
Et0/1.100   1    110 P Active   local           192.168.250.12  192.168.250.1
```
R1 should be **Active** with priority **110**

---

**On R2:**
```bash
ssh cisco@192.168.255.102
enable
show standby brief
```

**Expected:**
```
Interface   Grp  Pri P State    Active          Standby         Virtual IP
Et0/1.100   1    100 P Standby  192.168.250.11  local           192.168.250.1
```
R2 should be **Standby** with priority **100**

---

**On R3:**
```bash
ssh cisco@192.168.255.103
enable
show standby brief
```

**Expected:**
```
Interface   Grp  Pri P State    Active          Standby         Virtual IP
Et0/1.100   1    90    Listen   192.168.250.11  192.168.250.12  192.168.250.1
```
R3 should be **Listen** with priority **90**

---

## 🧪 Test 1: R1 Failure (Active → Standby Failover)

### Step 1: Setup continuous ping
From Ubuntu-Ansible or S2:
```bash
ping 192.168.250.1 -i 0.5
```
Leave this running in a separate window to monitor connectivity.

### Step 2: Shutdown R1's sub-interface
On R1:
```bash
ssh cisco@192.168.255.101
enable
configure terminal
interface Ethernet0/1.100
shutdown
end
```

### Step 3: Observe failover
Watch the ping output - you should see:
- Brief packet loss (1-3 seconds)
- Ping resumes as R2 takes over

### Step 4: Verify R2 is now Active
On R2:
```bash
show standby brief
```

**Expected:**
```
Interface   Grp  Pri P State    Active          Standby         Virtual IP
Et0/1.100   1    100 P Active   local           192.168.250.13  192.168.250.1
```
R2 should now be **Active**

### Step 5: Verify R3 is now Standby
On R3:
```bash
show standby brief
```

**Expected:**
```
Interface   Grp  Pri P State    Active          Standby         Virtual IP
Et0/1.100   1    90    Standby  192.168.250.12  local           192.168.250.1
```
R3 should now be **Standby**

---

## 🧪 Test 2: R2 Failure (Standby → Listen Failover)

### Step 1: Shutdown R2's sub-interface
On R2:
```bash
configure terminal
interface Ethernet0/1.100
shutdown
end
```

### Step 2: Observe failover
Watch the ping output - you should see:
- Brief packet loss (1-3 seconds)
- Ping resumes as R3 takes over

### Step 3: Verify R3 is now Active
On R3:
```bash
show standby brief
```

**Expected:**
```
Interface   Grp  Pri P State    Active          Standby         Virtual IP
Et0/1.100   1    90    Active   local           unknown         192.168.250.1
```
R3 should now be **Active**

---

## 🔄 Test 3: Recovery and Preemption

### Step 1: Bring R2 back up
On R2:
```bash
configure terminal
interface Ethernet0/1.100
no shutdown
end
```

### Step 2: Verify R2 becomes Active
Wait 10-20 seconds, then check:
```bash
show standby brief
```

R2 should preempt R3 and become **Active** again (priority 100 > 90)

### Step 3: Bring R1 back up
On R1:
```bash
configure terminal
interface Ethernet0/1.100
no shutdown
end
```

### Step 4: Verify R1 preempts and becomes Active
Wait 10-20 seconds, then check:
```bash
show standby brief
```

R1 should preempt R2 and become **Active** again (priority 110 > 100)

---

## 📊 Expected Failover Timing

| Event | Expected Behavior | Typical Time |
|-------|------------------|--------------|
| Active Router Fails | Standby becomes Active | 1-3 seconds |
| Standby Router Fails | Listen becomes Standby | 1-3 seconds |
| Higher Priority Router Returns | Preempts lower priority | 10-20 seconds |

---

## 🔍 Detailed HSRP Status Commands

### Full HSRP Details
```bash
show standby
```

### HSRP Statistics
```bash
show standby statistics
```

### HSRP Timers
```bash
show standby | include Hello\|Hold
```

### Track Interface Status
```bash
show track
```

---

## 📝 Troubleshooting

### If failover doesn't occur:
1. **Check interface status:**
   ```bash
   show ip interface brief | include Ethernet0/1
   ```

2. **Verify HSRP configuration:**
   ```bash
   show run interface Ethernet0/1.100
   ```

3. **Check for HSRP messages:**
   ```bash
   debug standby events
   ```
   (Remember to `undebug all` when done!)

### If preemption doesn't work:
1. **Verify preempt is configured:**
   ```bash
   show run interface Ethernet0/1.100 | include preempt
   ```
   Should show: `standby 1 preempt`

2. **Check priorities:**
   ```bash
   show standby brief
   ```
   Verify: R1=110, R2=100, R3=90

### If virtual IP doesn't respond:
1. **Check ARP:**
   ```bash
   show ip arp 192.168.250.1
   ```

2. **Verify routing:**
   ```bash
   show ip route
   ```

---

## ✅ Success Criteria

Your HSRP is working correctly if:
- [ ] R1 is Active by default (priority 110)
- [ ] When R1 fails, R2 becomes Active (priority 100)
- [ ] When R2 fails, R3 becomes Active (priority 90)
- [ ] When R1 recovers, it preempts and becomes Active again
- [ ] Ping to 192.168.250.1 has minimal interruption during failover
- [ ] All routers show the correct virtual IP (192.168.250.1)

---

## 📈 Advanced Testing

### Test Load Distribution
In production, you could configure multiple HSRP groups:
- HSRP Group 1: R1 Active, R2 Standby (for VLAN 10)
- HSRP Group 2: R2 Active, R1 Standby (for VLAN 20)

This distributes load across both routers.

### Test Interface Tracking
Configure HSRP to track upstream interfaces:
```bash
track 1 interface Ethernet0/0 line-protocol
!
interface Ethernet0/1.100
 standby 1 track 1 decrement 20
```

This reduces R1's priority by 20 if E0/0 goes down, forcing failover.

---

## 🎉 Congratulations!

If all tests pass, you have a fully functional HSRP redundant gateway configuration!
