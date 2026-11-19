
#ANSIBLE-AUTOMATION

Network Automation Tree
│
├── Management VLAN (VLAN 100)
│   ├── Subnet: 192.168.250.0/24
│   ├── S2: 192.168.250.2
│   ├── S3: 192.168.250.3
│   ├── S4: 192.168.250.4
│   └── S5: 192.168.250.5
│
├── Data VLANs
│   ├── VLAN 10 - Users
│   │   └── SVI IP: 192.168.10.1 (on S2)
│   └── VLAN 20 - Voice
│       └── SVI IP: 192.168.20.1 (on S2)
│
├── Layer 3 Configuration
│   ├── S2: ip routing enabled
│   ├── Default route on all switches → 192.168.250.1 (R1)
│   └── R1: Static routes for 192.168.10.0/24 and 192.168.20.0/24 → 192.168.250.2
│
├── Inter-Switch Links
│   ├── EtherChannel (Po3) between S2 and S3
│   │   └── LACP: S2 (passive), S3 (active)
│   ├── S4 and S5 → S2 via trunk (e0/0)
│   └── Trunks allow VLANs 10, 20, 100
│
├── Router-on-a-Stick (R1)
│   └── Sub-interface: e0/1.100 → 192.168.250.1
│
├── Access Ports
│   ├── S4: e0/2 → VLAN 10, e0/3 → VLAN 20
│   └── S5: e0/2 → VLAN 10, e0/3 → VLAN 20
│   └── PortFast + BPDU Guard enabled
│
├── Ubuntu-Ansible
│   └── IP: 192.168.255.81
│   └── Routes:
│       ├── 192.168.250.0/24 via 192.168.255.101
│       └── default via 192.168.255.101
│
└── Security & Best Practices
    ├── SSHv2 enabled
    ├── Passwords set to cisco
    ├── No DTP on access ports (implied)
    └── Trunk pruning applied   



✅ Step 1: Set Up Ansible Control Node (Ubuntu)
✅ Step 2: Create Project Structure
✅ Step 3: Define Inventory (inventory.yml)
✅ Step 4: Test Connectivity
✅ Step 5: Create Playbook – Enable SSH & Security (playbooks/00-ssh-setup.yml)
✅ Step 6: Create Playbook – VLANs and Trunks (playbooks/01-vlans-trunks.yml)
✅ Step 7: Configure S2 as Layer 3 Switch (playbooks/02-s2-routing.yml)
✅ Step 8: Configure EtherChannel (S2 & S3) (playbooks/03-etherchannel.yml)
✅ Step 9: Configure Access Ports (playbooks/04-access-ports.yml)
✅ Step 10: Configure R1 (playbooks/10-r1-router.yml)
✅ Step 11: Configure HSRP on R1, R2, R3 for VLAN 100
✅ Step 12: Update Ansible Playbook for R2/R3 (playbooks/11-r2-r3-hsrp.yml)
✅ Final Step: Run All Playbooks


Here is the folder and file structure tree for Ansible automation project:
ansible-cml-lab/
│
├── inventory.yml
├── ansible.cfg (optional)
│
├── playbooks/
│   ├── 00-ssh-setup.yml
│   ├── 01-vlans-trunks.yml
│   ├── 02-s2-routing.yml
│   ├── 03-etherchannel.yml
│   ├── 04-access-ports.yml
│   ├── 10-r1-router.yml
│   └── 11-r2-r3-hsrp.yml
│
├── group_vars/
│   └── all.yml (optional: place common vars like credentials)
│
└── host_vars/
    ├── R1.yml
    ├── R2.yml
    ├── R3.yml
    ├── S2.yml
    ├── S3.yml
    ├── S4.yml
    └── S5.yml


Step 1: Set Up Ansible Control Node (Ubuntu)
Ensure Ansible and required collections are installed:
sudo apt update
sudo apt install ansible ssh -y

# Install Cisco IOS collection
ansible-galaxy collection install cisco.ios
________________________________________
✅ Step 2: Create Project Structure
mkdir ansible-cml-lab
cd ansible-cml-lab
touch inventory.yml
mkdir playbooks
________________________________________
✅ Step 3: Define Inventory (inventory.yml)
all:
  hosts:
    R1:
      ansible_host: 192.168.255.101
    R2:
      ansible_host: 192.168.255.102
    R3:
      ansible_host: 192.168.255.103
    S2:
      ansible_host: 192.168.250.2
    S3:
      ansible_host: 192.168.250.3
    S4:
      ansible_host: 192.168.250.4
    S5:
      ansible_host: 192.168.250.5

  vars:
    ansible_network_os: cisco.ios.ios
    ansible_user: cisco
    ansible_password: cisco
    ansible_become: yes
    ansible_become_method: enable
    ansible_connection: ansible.netcommon.network_cli
________________________________________
✅ Step 4: Test Connectivity
ansible all -i inventory.yml -m ping
You should get SUCCESS for all devices.
________________________________________
✅ Step 5: Create Playbook – Enable SSH & Security (playbooks/00-ssh-setup.yml)
Even if SSH is already on, this ensures it’s consistent:
- name: Configure SSH and Security
  hosts: all
  tasks:
    - name: Set hostname
      cisco.ios.ios_config:
        lines:
          - hostname {{ inventory_hostname }}

    - name: Configure domain and crypto key
      cisco.ios.ios_config:
        lines:
          - ip domain-name lab.local
          - crypto key generate rsa modulus 1024
        match: none

    - name: Set enable secret and user
      cisco.ios.ios_config:
        lines:
          - enable secret cisco
          - username cisco privilege 15 secret cisco

    - name: Enable SSH version 2
      cisco.ios.ios_config:
        lines:
          - ip ssh version 2

    - name: Configure VTY lines
      cisco.ios.ios_config:
        lines:
          - line vty 0 4
          - login local
          - transport input ssh
Run:
ansible-playbook -i inventory.yml playbooks/00-ssh-setup.yml
________________________________________
✅ Step 6: Create Playbook – VLANs and Trunks (playbooks/01-vlans-trunks.yml)
- name: Configure VLANs and Trunk Ports
  hosts: S2,S3,S4,S5
  tasks:
    - name: Create VLANs 10, 20, 100
      cisco.ios.ios_vlans:
        config:
          - vlan_id: 10
            name: USERS
          - vlan_id: 20
            name: VOICE
          - vlan_id: 100
            name: MANAGEMENT
        state: merged

    - name: Configure trunk ports
      cisco.ios.ios_l2_interfaces:
        config:
          - name: Ethernet0/0
            mode: trunk
            trunk:
              allowed_vlans: 10,20,100
          - name: Ethernet0/1
            mode: trunk
            trunk:
              allowed_vlans: 10,20,100
        state: merged
________________________________________
✅ Step 7: Configure S2 as Layer 3 Switch (playbooks/02-s2-routing.yml)
- name: Configure S2 as Layer 3 Switch
  hosts: S2
  tasks:
    - name: Configure SVI for VLAN 10
      cisco.ios.ios_l3_interfaces:
        config:
          - name: Vlan10
            ipv4:
              - address: 192.168.10.1
                mask: 255.255.255.0
          - name: Vlan20
            ipv4:
              - address: 192.168.20.1
                mask: 255.255.255.0
          - name: Vlan100
            ipv4:
              - address: 192.168.250.2
                mask: 255.255.255.0
        state: merged

    - name: Enable IP routing
      cisco.ios.ios_system:
        ip_routing: yes

    - name: Set default route to R1
      cisco.ios.ios_static_routes:
        config:
          - address_families:
              - afi: ipv4
                routes:
                  - dest: 0.0.0.0/0
                    next_hops:
                      - forward_router: 192.168.250.1
________________________________________
✅ Step 8: Configure EtherChannel (S2 & S3) (playbooks/03-etherchannel.yml)
- name: Configure EtherChannel between S2 and S3
  hosts: S2,S3
  tasks:
    - name: Configure member ports for Po3
      cisco.ios.ios_l2_interfaces:
        config:
          - name: Ethernet1/0
            mode: trunk
          - name: Ethernet1/1
            mode: trunk
          - name: Ethernet1/2
            mode: trunk
          - name: Ethernet0/3
            mode: trunk
        state: merged

    - name: Add ports to channel-group 3
      cisco.ios.ios_l2_interfaces:
        config:
          - name: "{{ item }}"
            mode: trunk
            trunk:
              group: 3
              mode: "{{ 'passive' if inventory_hostname == 'S2' else 'active' }}"
        loop:
          - Ethernet1/0
          - Ethernet1/1
          - Ethernet1/2
          - Ethernet0/3

    - name: Configure Port-Channel 3 as trunk
      cisco.ios.ios_l2_interfaces:
        config:
          - name: Port-channel3
            mode: trunk
            trunk:
              allowed_vlans: 10,20,100
________________________________________
✅ Step 9: Configure Access Ports (playbooks/04-access-ports.yml)
- name: Configure Access Ports on S4 and S5
  hosts: S4,S5
  tasks:
    - name: Configure e0/2 as access port (VLAN 10)
      cisco.ios.ios_l2_interfaces:
        config:
          - name: Ethernet0/2
            mode: access
            access:
              vlan: 10
        state: merged

    - name: Configure e0/3 as access port (VLAN 20)
      cisco.ios.ios_l2_interfaces:
        config:
          - name: Ethernet0/3
            mode: access
            access:
              vlan: 20
        state: merged

    - name: Enable PortFast and BPDU Guard
      cisco.ios.ios_config:
        lines:
          - spanning-tree portfast
          - spanning-tree bpduguard enable
        parents: interface {{ item }}
      loop:
        - Ethernet0/2
        - Ethernet0/3
________________________________________
✅ Step 10: Configure R1 (playbooks/10-r1-router.yml)
- name: Configure R1 as Router-on-a-Stick
  hosts: R1
  tasks:
    - name: Ensure physical interface is up
      cisco.ios.ios_interfaces:
        config:
          - name: Ethernet0/1
            enabled: true
        state: merged

    - name: Configure sub-interface e0/1.100 for VLAN 100
      cisco.ios.ios_l3_interfaces:
        config:
          - name: Ethernet0/1.100
            dot1q:
              vlan_id: 100
            ipv4:
              - address: 192.168.250.1
                mask: 255.255.255.0
            encapsulation: dot1q
        state: merged

    - name: Add static routes for PC VLANs
      cisco.ios.ios_static_routes:
        config:
          - address_families:
              - afi: ipv4
                routes:
                  - dest: 192.168.10.0/24
                    next_hops:
                      - forward_router: 192.168.250.2
                  - dest: 192.168.20.0/24
                    next_hops:
                      - forward_router: 192.168.250.2
________________________________________
✅ Final Step: Run All Playbooks
ansible-playbook -i inventory.yml playbooks/00-ssh-setup.yml
ansible-playbook -i inventory.yml playbooks/01-vlans-trunks.yml
ansible-playbook -i inventory.yml playbooks/02-s2-routing.yml
ansible-playbook -i inventory.yml playbooks/03-etherchannel.yml
ansible-playbook -i inventory.yml playbooks/04-access-ports.yml
ansible-playbook -i inventory.yml playbooks/10-r1-router.yml
________________________________________
Now you have a fully automated Ansible-cml-Lab.

✅ Step 11: Configure HSRP on R1, R2, R3 for VLAN 100
On R1:

interface Ethernet0/1.100
 standby 1 ip 192.168.250.1
 standby 1 priority 110
 standby 1 preempt

On R2:

interface Ethernet0/1.100
 standby 1 ip 192.168.250.1
 standby 1 priority 100
 standby 1 preempt

On R3:

interface Ethernet0/1.100
 standby 1 ip 192.168.250.1
 standby 1 priority 90
 standby 1 preempt

This makes R1 the active gateway, R2 standby, and R3 backup.

✅ Step 12: Update Ansible Playbook for R2/R3 (playbooks/11-r2-r3-hsrp.yml)
- name: Configure R2 and R3 with HSRP
  hosts: R2,R3
  tasks:
    - name: Ensure physical interface is up
      cisco.ios.ios_interfaces:
        config:
          - name: Ethernet0/1
            enabled: true
        state: merged

    - name: Configure sub-interface for VLAN 100
      cisco.ios.ios_l3_interfaces:
        config:
          - name: Ethernet0/1.100
            dot1q:
              vlan_id: 100
            ipv4:
              - address: "{{ '192.168.250.12' if inventory_hostname == 'R2' else '192.168.250.13' }}"
                mask: 255.255.255.0
            encapsulation: dot1q
        state: merged

    - name: Configure HSRP for redundancy
      cisco.ios.ios_config:
        lines:
          - standby 1 ip 192.168.250.1
          - standby 1 priority "{{ 100 if inventory_hostname == 'R2' else 90 }}"
          - standby 1 preempt
        parents: interface Ethernet0/1.100

This aligns perfectly with existing design and adds seamless redundancy.
For example:

host_vars/R1.yml

device_ip: 192.168.255.101
device_role: router
management_ip: 192.168.250.1

host_vars/S2.yml

device_ip: 192.168.250.2
device_role: l3_switch
vlan10_ip: 192.168.10.1
vlan20_ip: 192.168.20.1

# host_vars/R3.yml
device_ip: 192.168.255.103
device_role: router
management_ip: 192.168.250.13   

host_vars/S3.yml

device_ip: 192.168.250.3
device_role: l3_switch

