---
aliases:
  - Scalable Homelab Rebuild
tags:
  - project/scalable-homelab-rebuild
created: 2026-07-11T17:30
up: "[[personal|Personal projects]]"
---
# Problem

My current homelab setup uses a monolithic OS (Ubuntu Server) with containerized applications installed. Recent security vulnerabilities prompted a need for a SOC homelab, as well as other profitable project ideas that needs deployment on scalable compute resources.

# Definitions

## Objectives

- Rebuild my current homelab setup from monolithic OS to a hypervisor-based setup.
- Support future projects and services that can be hosted on-prem.
- Produce a setup that is easily reproducible and declarative in nature.
- Demonstrate skills for career portfolio.

## Scope & Schedule

- Focus on creating a minimal setup fit for a home local network.
- Must be finished in less than a week or so (11 July 2026 - 15 July 2026).

## Task Management

The framework/tool that will be used to manage tasks: **Kanban boards**, **Kanban Plugin in Obsidian**.

left:: "[[scalable-homelab-rebuild.kanban]]"

## Knowledge Management

No knowledge management tools will be used for this project. All documentations are expected to be written in this document.

The following rules on documentation writing applies:
- All **imperative actions** that only needs to be executed once and cannot be scripted (i.e. has an interactive component) remains in this documentation **only**.
- All **imperative actions** that can be automated by scripting can be documented here or in a version control repository.
- All **declarative state** can be documented here or in a version control repository.

# Resources

Available compute asset(s):
- shlm1 - Homelab server
- vmi2635135 - VPS with public IP

# Implementation

## Solutions and infrastructure design

First, the appropriate tools, software, technologies and infrastructure design must be decided upon based on the following criteria:
- Must be open-source software, or at least has license for free use and accessibility (e.g. MIT, GPL, freeware, etc.)
- Supports the Project Objectives in terms of declarative, reproducible, and flexible configuration.
- Strikes a balance between enterprise and personal home setting in terms of setup complexity and resources needed.

As such, the table below lists the tool decided upon for each layer:

| Layer             | Decision                                                                                             |
| ----------------- | ---------------------------------------------------------------------------------------------------- |
| Config management | [Ansible](https://docs.ansible.com/)                                                                 |
| OS                | [AlmaLinux](https://almalinux.org/) (VMs), [Debian](https://www.debian.org/) (Proxmox-VE hypervisor) |
| IaC               | [Terraform](https://developer.hashicorp.com/terraform) (via bpg/proxmox or telmate/proxmox)          |
| Hypervisor        | [Proxmox-VE](https://pve.proxmox.com/wiki/Main_Page)                                                 |

## Hardware setup

**Proxmox VE 9.2-1 (PVE)** is installed on the server machine with the following configuration:
```
Hostname: shlm1
Cores: 4
RAM: 11.56G
Storage:
- 59.6G SSD (16G root, 4G swap)
- 465.8G HDD (planned for additional storage - images, backups, low-priority VMs, etc.)
```

The **Proxmox VE Post Install** script (managed by the community) is used for configuring PVE for non-subscription use.
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
```

Install misc packages.
```
apt install sudo parted vim
```

Storage partitions are configured as follows:
```
1x block LVM (root, already existing after installation)
2x block ZFS pool (1x on SSD for high priority VMs, 1x on HDD for others)
1x directory storage (for images, templates, snippets, backups, etc.)
```

Sculpting the storage partitions the way it is needed was hard, and multiple re-installs were made. The limited SSD storage prompts for the need to further reduce the LV group, fitting a 16GB root partition and 4GB swap, plus other EFI/boot partitions, just to give way for a remaining 37GB of fast VM storage meant to be formatted as a ZFS block.

The Proxmox installer does not offer a way to directly do this, so the only option is to expand the LV after installation. The final re-install had the following storage configuration:
```
hdsize = 21GB
swapsize = 4GB
maxroot = 16GB
maxvz = 0
minfree = 0
```

The resulting root partition is only 8.25G, with the remaining 8.25G unallocated. This was due to the PVE's installer computation of storage. The LV was extended by:
```bash
lvextend -l +100%FREE /dev/pve/root
resize2fs /dev/pve/root
parted /dev/sda unit MiB print  # confirm where the installer's partitions end
parted /dev/sda unit MiB mkpart primary <end_of_last_partition> 100%
partprobe
lsblk  # confirm if changes are correct
```

The content types for each storage resource was configured as follows:
- local (Directory from pve LVM)
	- Container template `vztmpl`
- dir1 (Directory)
	- `iso`, `backup`, `vztmpl`, `snippets`
- zfs1s (ZFS pool, SSD)
	- `image`, `containers`
- zfs2h (ZFS pool, HDD)
	- `image`, `containers`

![scalable-homelab-rebuild-1783987280982.webp](blob/scalable-homelab-rebuild-1783987280982.webp)

Other post-installation tasks were also performed:
- Non-root PVE realm user created for personal access to PVE Web GUI, enforcing principle of least privilege when it comes to permissions.
- 2FA for PVE Web GUI logins is also added to root and non-root user(s).
- Harden Proxmox VE host machine.
	- 2FA for TTY and SSH sessions are enabled via `libpam-google-authenticator` (refer to [[#Setting up Two-factor Authentication for all PAM session logins]])

## Hardening PVE host machine

### Non-root user accounts

A non-root PAM admin account is created for personal access to SSH and PVE Web GUI. If needed, future user accounts can be created within PVE realm only, enforcing principle of least privilege when it comes to permissions.

### Setting up Two-factor Authentication for all PAM sessions and PVE realm logins

Two-Factor Authentication (2FA) for SSH and TTY on Linux is also enabled by installing `libpam-google-authenticator`:
```bash
apt install libpam-google-authenticator
```

Both `/etc/pam.d/sshd` and `/etc/pam.d/login` are modified to add the following at the top:
```
auth required pam_google_authenticator.so nullok
```

Modified `/etc/ssh/sshd_config` and set the following values:
```
# For older versions, it might be ChallengeResponseAuthentication
KbdInteractiveAuthentication yes
UsePAM yes
```

Restarted SSH service.
```bash
systemctl restart ssh
```

Each user must now enroll their own 2FA authenticator by running `google-authenticator`, prompting the user with options. The following are the preferred selection:
- Time-based tokens: Yes
- Disallow multiple uses: Yes
- Rate-limiting: Yes

Optionally, the same secret key given by `google-authenticator` can be used in setting up 2FA for PVE realm user accounts in the web GUI to unify TOTP codes for both SSH/TTY and PVE Web GUI logins.

### Probing listening ports and services

Verified which services are active and which ones are exposed:
```bash
systemctl list-units --type=service --state=running
ss -tulpn
```

There are a few that needs action (or future action):
- `rpcbind` and `nfs-blkmap` on UDP/TCP 111
	- Unsure if it will be used in the future, will be hardened on the network/VPN side.
- `spiceproxy` on TCP 3128
	- Unused, disabled with `systemctl disable --now spiceproxy.service`
- `pveproxy` on TCP 8006
	- Will be hardened on the network/VPN side

### Sysctl network hardening

The following is written to `/etc/sysctl.d/99-hardening.conf`:
```
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
```

- `rp_filter = 2` enables reverse path filtering, it prevents IP source address spoofing. A value of `2` (loose mode) is more compatible with VPN (planning to install Tailscale).
- `icmp_echo_ignore_broadcasts = 1` ignores ICMP echo requests sent to broadcast addresses. This protects from smurf attacks.
- `accept_redirects = 0` ignores ICMP redirect messages. This prevents from MITM and traffic hijacking attacks. `send_redirects = 0` also disables the PVE host itself from sending ICMP redirects.
- `tcp_syncookies = 1` enables SYN cookies, which protects from TCP SYN flood attacks.
- `net.ipv4.ip_forward = 1` and `net.ipv6.conf.all.forwarding = 1` is enabled for routing through VPN (plan to install Tailscale).
- Each IPv4 config has `all` and `default` lines, so **all current** and **future** interfaces are affected. For the sole IPv6 forwarding setting, it does not need that since it is a global flag (refer to [[#^e49dca]], [[#^9453a5]]).

Once all settings are confirmed, `sudo sysctl --system` is executed to apply these settings.

### Defense-in-depth against brute-forcing

Even with 2FA enabled, `fail2ban`

# References

- https://community-scripts.org/scripts/post-pve-install?id=post-pve-install
- https://ubuntu.com/tutorials/configure-ssh-2fa
- https://pve.proxmox.com/wiki/Installation#advanced_lvm_options
- https://docs.kernel.org/networking/ip-sysctl.html ^e49dca
- https://lkml.org/lkml/2025/7/1/1170 ^9453a5

