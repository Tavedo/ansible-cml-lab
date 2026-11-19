# Security Notes

This setup works for a lab, but it isn't hardened. These are the gaps and how I'd
close them for anything real.

## 1. Default credentials

All devices use `cisco/cisco`, a well-known default.
Fix: use strong, unique passwords and local accounts with secret hashing.
```
username admin secret <strong_password>
```

## 2. Unsecured management access

SSH is on, but there are no login banners and no access control on the VTY lines.
Fix:
```
banner login ^C Unauthorized Access Prohibited ^C
line vty 0 4
 access-class 1 in
!
access-list 1 permit 192.168.255.0 0.0.0.255
```

## 3. Open trunks / VLAN hopping

Trunks that allow all VLANs are a VLAN-hopping risk if someone reaches a trunk port.
Fix: allow only the VLANs that are needed, and disable DTP on access ports.
```
switchport trunk allowed vlan 10,20,100
switchport nonegotiate
```

## 4. No port security on access ports

Nothing stops an unauthorized device plugging into an access port.
Fix:
```
interface e0/2
 switchport port-security
 switchport port-security maximum 1
 switchport port-security mac-address sticky
```

## 5. BPDU Guard not enabled

A rogue switch could influence spanning tree.
Fix, on access ports:
```
spanning-tree portfast
spanning-tree bpduguard enable
```

## 6. ICMP and CDP

Excessive ICMP or CDP can help reconnaissance.
Fix: limit ICMP where it isn't needed, or filter it at the edge.

## 7. No logging or monitoring

Logs are local only, with no central collection.
Fix:
```
logging 192.168.255.81
logging trap informational
```

## Summary

For production these would be required fixes. In the lab they're still good habits
to practice.
