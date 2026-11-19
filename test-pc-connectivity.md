# PC Connectivity Test

Checks that end hosts reach their gateway and the segments they should, and that
inter-VLAN routing works.

Hosts connect to S4/S5 access ports: Et0/2 in VLAN 10 (users), Et0/3 in VLAN 20
(voice).

## 1. Addressing

Each PC gets an address in its VLAN (DHCP from S2 if configured, otherwise static):

- VLAN 10: 192.168.10.x, gateway 192.168.10.1
- VLAN 20: 192.168.20.x, gateway 192.168.20.1

## 2. Ping the gateway

From a VLAN 10 PC:
```
ping 192.168.10.1
```
Should succeed — this is the SVI on S2.

## 3. Ping across VLANs

From a VLAN 10 PC to a VLAN 20 host:
```
ping 192.168.20.x
```
Should succeed — S2 routes between the SVIs.

## 4. Ping the management gateway

```
ping 192.168.250.1
```
Should succeed — reachable through S2's default route to R1 (the HSRP VIP).

## Expected results

| From a VLAN 10 PC | Target | Reach |
|---|---|---|
| 192.168.10.1 (own gateway) | yes | |
| 192.168.20.x (VLAN 20 host) | yes (routed by S2) | |
| 192.168.250.1 (HSRP VIP) | yes | |

Adjust the host addresses to match your PCs.
