# HSRP Failover Test

Checks that the gateway fails over from R1 to R3 when R1 goes down, and fails back
when R1 comes back.

Steady state: R1 is active (priority 110), R3 is standby (priority 90), virtual IP
192.168.250.1.

## 1. Check the starting state

On R1:
```
show standby brief
```
R1 should show Active on Et0/1.100, group 1, VIP 192.168.250.1.

On R3:
```
show standby brief
```
R3 should show Standby.

## 2. Start a continuous ping to the VIP

From S2, or any host on VLAN 100:
```
ping 192.168.250.1 repeat 100000
```
Leave it running during the test.

## 3. Fail the active router

Stop R1 in CML, or shut its sub-interface:
```
interface Ethernet0/1.100
 shutdown
```

## 4. Watch the failover

- The ping drops one or two packets, then keeps going.
- On R3, `show standby brief` now shows R3 as Active.

## 5. Restore R1

Start R1 again, or `no shutdown` the sub-interface. Preempt is set, so R1 takes back
Active and R3 goes back to Standby.

## Optional: interface tracking

To fail over when R1's upstream link drops, not only when R1 itself dies:
```
track 1 interface Ethernet0/0 line-protocol
interface Ethernet0/1.100
 standby 1 track 1 decrement 20
```
If Et0/0 goes down, R1's priority drops by 20 and R3 takes over.
