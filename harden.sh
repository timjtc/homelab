#!/bin/bash

# Only run if root / with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo."
  exit
fi

apt update -y
apt install libpam-google-authenticator fail2ban -y

# Add to /etc/pam.d/sshd and /etc/pam.d/login
echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
echo "auth required pam_google_authenticator.so" >> /etc/pam.d/login

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
# In /etc/ssh/sshd_config, set the following
if grep -q '^#ChallengeResponseAuthentication' /etc/ssh/sshd_config; then
  sed -i 's/^#ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
else
  echo "ChallengeResponseAuthentication yes" >> /etc/ssh/sshd_config
fi

if grep -q '^#KbdInteractiveAuthentication' /etc/ssh/sshd_config; then
  sed -i 's/^#KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config
else
  echo "KbdInteractiveAuthentication yes" >> /etc/ssh/sshd_config
fi
if grep -q '^#UsePAM' /etc/ssh/sshd_config; then
  sed -i 's/^#UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
else
  echo "UsePAM yes" >> /etc/ssh/sshd_config
fi

# Sysctl hardening settings
cat <<EOF > /etc/sysctl.d/99-hardening.conf
# Anti-spoofing (VPN-friendly)
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2

# Ignore broadcast pings
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Don't accept or send ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# SYN flood protection
net.ipv4.tcp_syncookies = 1

# Required if acting as a Tailscale subnet router
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

cat <<EOF > /etc/fail2ban/jail.d/1-proxmox.conf
[proxmox]
enabled = true
port = https,http,8006
filter = proxmox
backend = systemd
maxretry = 3
findtime = 5m
bantime = 1h
EOF

cat <<EOF > /etc/fail2ban/filter.d/proxmox.conf
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
journalmatch = _SYSTEMD_UNIT=pvedaemon.service
EOF

# Verify fail2ban configuration
if fail2ban-client -d; then
  systemctl restart fail2ban
  echo "Fail2Ban configuration applied successfully."
else
  echo "Error in Fail2Ban configuration. Please check /etc/fail2ban/jail.d/1-proxmox.conf and /etc/fail2ban/filter.d/proxmox.conf."
fi

# Verify sysctl settings
if sysctl --system; then
  echo "Sysctl settings applied successfully."
else
  echo "Error applying sysctl settings. Please check /etc/sysctl.d/99-hardening.conf."
fi

# Verify SSH config syntax before restarting
if sshd -t; then
  systemctl restart sshd
  echo "2FA setup complete. Please run 'google-authenticator' for each user to generate their secret key and QR code."
else
  cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
  echo "SSH configuration test failed, backup restored."
  echo "Please manually modify /etc/ssh/sshd_config to enable 2FA."
