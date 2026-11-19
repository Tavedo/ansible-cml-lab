Security Concerns in This Lab
While this setup works for a lab environment, here are some security considerations to keep in mind:

1. Default Credentials
All devices use cisco/cisco — this is a well-known default.
✅ Fix: Change to strong, unique passwords or use local user accounts with secret hashing:
username admin secret MyStrongPass123

2. Unsecured Management Access
SSH is enabled, but:
No login banners (missing legal notice).
No access control on VTY lines.
✅ Fix:
banner login ^C Unauthorized Access Prohibited ^C
line vty 0 4
 access-class 1 in  (allow only management subnet)

With ACL:
access-list 1 permit 192.168.255.0 0.0.0.255

3. Open Trunks and VLAN Hopping
Trunk ports allow all VLANs (1-4094) or multiple VLANs without pruning.
Risk of VLAN hopping if an attacker gains access to a trunk port.
✅ Fix:
Only allow necessary VLANs:
switchport trunk allowed vlan 10,20,100

Disable DTP on access ports:
switchport nonegotiate

4. Port Security (Missing on Access Ports)
PC ports have no protection against unauthorized devices.
✅ Fix:
interface e0/2
 switchport port-security
 switchport port-security maximum 1
 switchport port-security mac-address sticky

5. BPDU Guard Not Enabled
STP can be exploited if a rogue switch is connected.
✅ Fix: Enable BPDU Guard on all access ports:
spanning-tree portfast
spanning-tree bpduguard enable

6. ICMP and Debugging Enabled
While useful for troubleshooting, excessive ICMP or CDP can aid reconnaissance.
✅ Fix: Limit ICMP if not needed, or filter at edge.
7. No Logging or Monitoring
No centralized logging; all logs are local.
✅ Fix: Set up syslog:
logging 192.168.255.81
logging trap informational

Summary
For a production network, these would be critical fixes. In a lab, they're still good practice to reinforce secure configuration habits.

You now have full connectivity.
