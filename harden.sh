#!/bin/bash

# Only run if root / with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo."
  exit
fi

# Install Google Authenticator PAM module
apt update -y
apt install libpam-google-authenticator -y

# Add to /etc/pam.d/sshd and /etc/pam.d/login
echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd
echo "auth required pam_google_authenticator.so" >> /etc/pam.d/login

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

# Verify SSH config syntax before restarting
if sshd -t; then
  systemctl restart sshd
  echo "2FA setup complete. Please run 'google-authenticator' for each user to generate their secret key and QR code."
else
  echo "Error in SSH configuration. Please manually check /etc/ssh/sshd_config."
