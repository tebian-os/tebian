#!/bin/bash
# Tebian Core Module - Applied to both Server and Desktop

echo "󰒓 Initializing Tebian Core..."

# 1. Performance: ZRAM
echo "🚀 Configuring ZRAM (2x Compression)..."
sudo apt install -y zram-tools
echo -e "ALGO=zstd
PERCENT=60" | sudo tee /etc/default/zramswap
sudo service zramswap reload

# 2. Kernel Tuning & Hardening
echo "🚀 Tuning Kernel (swappiness + hardening)..."
cat <<'EOF' | sudo tee /etc/sysctl.d/99-tebian.conf
vm.swappiness=10
kernel.kptr_restrict=2
kernel.yama.ptrace_scope=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
EOF
sudo sysctl -p /etc/sysctl.d/99-tebian.conf

# 3. SSH Hardening Drop-in
echo "󰒃 Hardening SSH defaults..."
sudo mkdir -p /etc/ssh/sshd_config.d
cat <<'EOF' | sudo tee /etc/ssh/sshd_config.d/99-tebian.conf
PermitRootLogin no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

# 4. Login Banner
echo "󰒃 Setting login banner..."
echo "Tebian OS V1.0 (Based on Debian Trixie)" | sudo tee /etc/issue.net

# 5. Security: Firewall
echo "󰒃 Hardening Network (UFW)..."
sudo apt install -y ufw fail2ban
sudo ufw default deny incoming
sudo ufw allow ssh
sudo ufw --force enable
sudo systemctl enable fail2ban --now

echo "✅ Tebian Core initialized."
