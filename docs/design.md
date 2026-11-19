# Design

How the lab is laid out and how it was built.

## Network layout

```
Management VLAN (VLAN 100) - 192.168.250.0/24
  S2 .2   S3 .3   S4 .4   S5 .5
  R1 sub-int .11   R3 sub-int .13   HSRP VIP .1

Data VLANs
  VLAN 10 Users  - SVI 192.168.10.1 (on S2)
  VLAN 20 Voice  - SVI 192.168.20.1 (on S2)

Layer 3
  S2: ip routing enabled
  Switches default route -> 192.168.250.1 (HSRP VIP on R1/R3)
  R1: static routes for 192.168.10.0/24 and 192.168.20.0/24 -> 192.168.250.2 (S2)

Inter-switch links
  Po3 EtherChannel between S2 and S3 (LACP: S2 passive, S3 active)
  S4, S5 -> S2 via trunk (e0/0)
  Trunks allow VLANs 10, 20, 100

Router-on-a-stick (R1)
  e0/1.100 dot1q 100 -> 192.168.250.11

Access ports
  S4 / S5: e0/2 -> VLAN 10, e0/3 -> VLAN 20
  PortFast + BPDU Guard

Control node (Ubuntu-Ansible)
  192.168.255.81
  route 192.168.250.0/24 via 192.168.255.101 (persisted in netplan)

Routers management subnet - 192.168.255.0/24
  R1 .101   R2 .102   R3 .103
```

## Addressing

| Device | Role | Address |
|---|---|---|
| R1 | router / HSRP active | 192.168.255.101, VLAN100 .11 |
| R2 | router | 192.168.255.102 |
| R3 | router / HSRP standby | 192.168.255.103, VLAN100 .13 |
| S2 | L3 switch | 192.168.250.2 |
| S3 | access (Po3 to S2) | 192.168.250.3 |
| S4, S5 | access | 192.168.250.4 / .5 |
| Ubuntu-Ansible | control node | 192.168.255.81 |

HSRP virtual IP for VLAN 100 is 192.168.250.1.

## Build order

Built by hand first, then automated. Playbooks run in this order:

| Playbook | Does |
|---|---|
| `00-ssh-setup.yml` | SSH, hostname, domain, local user, VTY |
| `01-vlans-trunks.yml` | VLANs 10/20/100 and trunks on S2-S5 |
| `02-s2-routing.yml` | SVIs, ip routing, default route on S2 |
| `03-etherchannel.yml` | Port-channel3 (LACP) between S2 and S3 |
| `04-access-ports.yml` | access ports + PortFast/BPDU Guard on S4, S5 |
| `10-r1-router.yml` | router-on-a-stick + static routes on R1 |
| `11-r1-r3-hsrp.yml` | HSRP, R1 active / R3 standby |

## Inventory

Static inventory (`inventory.yml`), one group `all`. Credentials are not stored in
the inventory - they live in `group_vars/all.yml`, which is gitignored. Copy
`group_vars/all.yml.example` and fill in your own:

```yaml
ansible_user: <your_username>
ansible_password: <your_password>
ansible_become_password: <your_enable_secret>
```

Connection settings (in `inventory.yml`):

```yaml
ansible_network_os: cisco.ios.ios
ansible_connection: ansible.netcommon.network_cli
ansible_become: yes
ansible_become_method: enable
```

## HSRP

Group 1 on VLAN 100. R1 priority 110 (active), R3 priority 90 (standby), both with
preempt, sharing VIP 192.168.250.1. R1's physical sub-interface is `.11` and R3's is
`.13`, kept separate from the VIP so neither router's real address collides with it.

## Notes

- The control node needs the route to 192.168.250.0/24 via R1 in netplan, or Ansible
  reaches the routers but not the switches.
- `enable secret` and the local user password are set from the same `group_vars`
  variables, so no password is hardcoded in any playbook.
- The lab uses the CML default credentials; change them for anything real. See
  `security-notes.md`.
