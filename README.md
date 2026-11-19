# Ansible Network Automation — Cisco CML Lab

Full automation of a multi-layer enterprise lab in **Cisco Modeling Labs (CML)** with **Ansible**:
VLANs and trunks, a Layer-3 switch doing inter-VLAN routing, an **LACP EtherChannel**,
**router-on-a-stick**, and an **HSRP redundant gateway** — every layer pushed by playbook and
**validated 16/16 on the live devices**.

The lab was first built by hand, then automated playbook-by-playbook so each step could be
verified on real IOS before moving on. The `verify-*.sh` scripts prove the running state, not just
that Ansible reported success.

---

## What it demonstrates

| Area | Built with |
|---|---|
| **Access layer** | VLANs 10 / 20 / 100, 802.1Q trunks, PortFast + BPDU Guard on edge ports |
| **L3 switching** | S2 as a multilayer switch — SVIs per VLAN, `ip routing`, default route to the gateway |
| **Link aggregation** | `Port-channel3` between S2 and S3 over **LACP** (4 bundled members) |
| **Inter-VLAN routing** | R1 **router-on-a-stick** (`e0/1.100`, dot1q), static routes to the user subnets |
| **Gateway redundancy** | **HSRPv2** — R1 active (pri 110) / R3 standby (pri 90), floating VIP, preempt |
| **Management** | SSHv2 + local auth pushed to all devices; in-band control node |
| **Validation** | `verify-network.sh` (16 checks) + `verify-hsrp.sh`, run against the live lab |

---

## Topology

```
                 192.168.255.0/24 (management)
   Ubuntu-Ansible .81 ── R1 .101 ── R2 .102 ── R3 .103
   (control node)         │                      │
                          │  router-on-a-stick    │  HSRP peers over VLAN 100
                          │  e0/1.100 = .11       │  e0/1.100 = .13
                          └──────── VLAN 100 (192.168.250.0/24) ───────┘
                                        │   VIP .1  (HSRP)
                       ┌────────────────┼────────────────┐
                    S2 .2 ══Po3 LACP══ S3 .3           S4 .4   S5 .5
                 (L3 switch)                         (access)  (access)
                 SVIs: V10 .10.1 / V20 .20.1 / V100 .250.2
```

## Addressing

| VLAN | Name | Subnet | Gateway |
|---|---|---|---|
| 10 | USERS | 192.168.10.0/24 | 192.168.10.1 (SVI on S2) |
| 20 | VOICE | 192.168.20.0/24 | 192.168.20.1 (SVI on S2) |
| 100 | MANAGEMENT | 192.168.250.0/24 | **192.168.250.1 (HSRP VIP)** |

Routers sit on the `192.168.255.0/24` management subnet (R1 `.101`, R2 `.102`, R3 `.103`); the
Ansible control node is `192.168.255.81`. On VLAN 100, R1's sub-interface is `.11` and R3's is `.13`,
with `.1` reserved as the HSRP virtual IP.

---

## Playbooks (run in order)

| # | Playbook | Targets | Does |
|---|---|---|---|
| 00 | `00-ssh-setup.yml` | all | hostname, domain, RSA key, SSHv2, local user, VTY |
| 01 | `01-vlans-trunks.yml` | S2–S5 | create VLANs 10/20/100, configure 802.1Q trunks |
| 02 | `02-s2-routing.yml` | S2 | SVIs, `ip routing`, default route to R1 |
| 03 | `03-etherchannel.yml` | S2, S3 | `Port-channel3` over LACP |
| 04 | `04-access-ports.yml` | S4, S5 | access ports + PortFast / BPDU Guard |
| 10 | `10-r1-router.yml` | R1 | router-on-a-stick sub-interface + static routes |
| 11 | `11-r1-r3-hsrp.yml` | R1, R3 | HSRP group 1, VIP `.1`, priorities + preempt |

Run everything with `run-all-playbooks.sh`, or one at a time:
```bash
ansible-playbook -i inventory.yml playbooks/01-vlans-trunks.yml
```

---

## Running it

```bash
# 1. clone
git clone https://github.com/Tavedo/ansible-cml-lab.git
cd ansible-cml-lab

# 2. set your credentials (kept out of git)
cp group_vars/all.yml.example group_vars/all.yml
#   then edit group_vars/all.yml with your device username / password / enable secret

# 3. install the Cisco collection
ansible-galaxy collection install cisco.ios

# 4. verify reachability, then build
ansible all -i inventory.yml -m ping
bash run-all-playbooks.sh

# 5. prove the running state
bash verify-network.sh      # 16 checks across all devices
bash verify-hsrp.sh         # HSRP active/standby + failover
```

### Control node prerequisite
The Ansible host (`192.168.255.81`) needs an in-band path to the switch subnet. On Ubuntu this is a
persistent netplan drop-in (the lab IP on the data interface **plus a route** to
`192.168.250.0/24` via R1) — set it once in `/etc/netplan/` so it survives a reboot, rather than
with temporary `ip addr`/`ip route` commands.

---

## Verification

`verify-network.sh` against the live lab:

```
Verification Summary
Tests Passed: 16
Tests Failed: 0
✓ All tests passed! Network is fully operational!
```

HSRP state:
```
R1:  Et0/1.100  Grp 1  Pri 110  Active   Virtual IP 192.168.250.1
R3:  Et0/1.100  Grp 1  Pri 90   Standby  Virtual IP 192.168.250.1
```

---

## Credentials

No real credentials are committed. `group_vars/all.yml` (the live values) is gitignored; the repo
ships `group_vars/all.yml.example` as a template. The lab itself uses the CML default `cisco/cisco`
— fine for a sandbox, but set your own for anything real.

---

## Repo layout

```
ansible-cml-lab/
├── ansible.cfg
├── inventory.yml
├── group_vars/
│   └── all.yml.example        # copy to all.yml and fill in (all.yml is gitignored)
├── playbooks/                 # 00 → 11, run in order
├── docs/                      # design notes and reference
├── run-all-playbooks.sh
├── verify-network.sh          # 16-check live validation
├── verify-hsrp.sh
├── test-hsrp-failover.md      # manual failover test procedure
├── test-pc-connectivity.md
└── validation-commands.txt
```

---

*Built in Cisco Modeling Labs with IOL-XE / IOLL2-XE images and automated with `cisco.ios`.*
