# Ansible CML Lab

Automating a small Cisco CML lab with Ansible. The lab has VLANs, a Layer 3 switch,
an EtherChannel, router-on-a-stick, and HSRP for gateway redundancy. I built it by
hand first, then wrote playbooks to configure it and scripts to check it.

All 16 checks in `verify-network.sh` pass against the running lab.

## Devices

7 managed devices plus an Ubuntu node running Ansible.

- R1, R2, R3 — routers (192.168.255.101–103)
- S2 — Layer 3 switch
- S3, S4, S5 — access switches
- Ubuntu-Ansible — control node (192.168.255.81)

## VLANs

| VLAN | Name | Subnet | Gateway |
|---|---|---|---|
| 10 | USERS | 192.168.10.0/24 | 192.168.10.1 (SVI on S2) |
| 20 | VOICE | 192.168.20.0/24 | 192.168.20.1 (SVI on S2) |
| 100 | MANAGEMENT | 192.168.250.0/24 | 192.168.250.1 (HSRP VIP) |

On VLAN 100, R1's sub-interface is `.11` and R3's is `.13`. The `.1` address is the
HSRP virtual IP that floats between them.

## Topology

```
   192.168.255.0/24 (management)
   Ubuntu .81 --- R1 .101 --- R2 .102 --- R3 .103
                   |                        |
                   |   router-on-a-stick    |  HSRP over VLAN 100
                   +------ VLAN 100 (192.168.250.0/24) ------+
                               | VIP .1
              S2 .2 ==Po3 LACP== S3 .3      S4 .4    S5 .5
           (L3 switch)                     (access) (access)
```

## Playbooks

Run them in order:

| # | File | What it does |
|---|---|---|
| 00 | `00-ssh-setup.yml` | hostname, domain, SSHv2, local user, VTY lines |
| 01 | `01-vlans-trunks.yml` | VLANs 10/20/100 and trunks on S2–S5 |
| 02 | `02-s2-routing.yml` | SVIs, `ip routing`, default route on S2 |
| 03 | `03-etherchannel.yml` | Port-channel3 (LACP) between S2 and S3 |
| 04 | `04-access-ports.yml` | access ports + PortFast/BPDU Guard on S4, S5 |
| 10 | `10-r1-router.yml` | router-on-a-stick + static routes on R1 |
| 11 | `11-r1-r3-hsrp.yml` | HSRP — R1 active, R3 standby |

## How to run

```bash
git clone https://github.com/Tavedo/ansible-cml-lab.git
cd ansible-cml-lab

# set your credentials (this file is gitignored)
cp group_vars/all.yml.example group_vars/all.yml
# then edit group_vars/all.yml

ansible-galaxy collection install cisco.ios

ansible all -i inventory.yml -m ping     # check reachability
bash run-all-playbooks.sh                # build everything
bash verify-network.sh                   # check it worked
```

The Ubuntu node needs a route to the switch subnet (`192.168.250.0/24` via R1) set in
netplan so it survives a reboot. If that route is missing, Ansible can reach the
routers but not the switches.

## Credentials

No real credentials are committed. `group_vars/all.yml` is gitignored — copy
`group_vars/all.yml.example` and fill in your own. The lab uses `cisco/cisco`, which
is the CML default. Change it for anything real.

## Files

- `playbooks/` — the playbooks, 00 to 11
- `group_vars/all.yml.example` — credential template
- `verify-network.sh` — 16 checks against the live lab
- `verify-hsrp.sh` — HSRP state and failover
- `test-hsrp-failover.md`, `test-pc-connectivity.md` — manual test steps
- `docs/` — design notes
