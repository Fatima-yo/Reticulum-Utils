#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Reticulum / LXMF / Nomad Network installer
#
# Based on original instructions written by Gaba :-D at:
# https://fab.uy/index.php/Redes_Aut%C3%B3nomas_por_fuera_de_Internet
#
# Installs:
#   - Reticulum (rns / rnsd)
#   - LXMF (lxmd)
#   - Nomad Network
#
# Designed for Debian/Ubuntu VPS systems.
#
# to use this script, in a bash terminal run:
# sudo apt update
# sudo apt install curl
# curl -fsSL https://raw.githubusercontent.com/Fatima-yo/Reticulum-Utils/main/install-reticulum.sh | sudo bash
# 
# ============================================================

RETICULUM_USER="reticulum"
RETICULUM_HOME="/opt/reticulum"
VENV="${RETICULUM_HOME}/reticulum_env"

RNS_CONFIG="/etc/reticulum"
LXMF_CONFIG="/etc/lxmd"
NOMAD_CONFIG="/etc/nomadnetwork"

echo "=== Reticulum stack installer ==="

# ------------------------------------------------------------
# Check root
# ------------------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This installer must be run as root."
    echo "Use:"
    echo "  curl -fsSL https://YOUR_SERVER_DNS_NAME/install-reticulum.sh | sudo bash"
    exit 1
fi

# ------------------------------------------------------------
# Check OS
# ------------------------------------------------------------

if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: Cannot determine operating system."
    exit 1
fi

. /etc/os-release

case "${ID}" in
    debian|ubuntu)
        ;;
    *)
        echo "ERROR: This installer currently supports Debian and Ubuntu."
        echo "Detected: ${ID}"
        exit 1
        ;;
esac

# ------------------------------------------------------------
# Install system dependencies
# ------------------------------------------------------------

echo
echo "=== Installing system packages ==="

export DEBIAN_FRONTEND=noninteractive

apt update

apt install -y \
    python3 \
    python3-full \
    python3-pip \
    python3-venv \
    python3-virtualenv \
    build-essential \
    ca-certificates

# ------------------------------------------------------------
# Create dedicated user
# ------------------------------------------------------------

echo
echo "=== Creating reticulum system user ==="

if ! id "${RETICULUM_USER}" >/dev/null 2>&1; then
    useradd \
        --system \
        --create-home \
        --home-dir "${RETICULUM_HOME}" \
        --shell /usr/sbin/nologin \
        "${RETICULUM_USER}"
fi

mkdir -p "${RETICULUM_HOME}"

chown -R "${RETICULUM_USER}:${RETICULUM_USER}" "${RETICULUM_HOME}"

# ------------------------------------------------------------
# Create Python virtual environment
# ------------------------------------------------------------

echo
echo "=== Creating Python virtual environment ==="

if [[ ! -d "${VENV}" ]]; then
    python3 -m venv "${VENV}"
fi

"${VENV}/bin/python" -m pip install --upgrade pip setuptools wheel

# ------------------------------------------------------------
# Install Reticulum stack
# ------------------------------------------------------------

echo
echo "=== Installing Reticulum, LXMF and Nomad Network ==="

"${VENV}/bin/python" -m pip install --upgrade \
    rns \
    lxmf \
    nomadnet

# ------------------------------------------------------------
# Reticulum configuration
# ------------------------------------------------------------

echo
echo "=== Creating Reticulum configuration ==="

mkdir -p "${RNS_CONFIG}"

cat > "${RNS_CONFIG}/config" <<'EOF'
[reticulum]

# This VPS acts as a Reticulum transport node.
enable_transport = yes


[logging]

# 0 = critical
# 1 = errors
# 2 = warnings
# 3 = notices
# 4 = info
# 5 = verbose
# 6 = debug
# 7 = extreme
loglevel = 7


[interfaces]

[[Home]]
    type = TCPServerInterface
    listen_port = 4242


[[Direct to server]]
    type = TCPClientInterface
    enabled = true
    target_host = 62.169.20.91
    target_port = 4242


[[Chicagoland RNS]]
    type = TCPClientInterface
    enabled = true
    target_host = rns.noderage.org
    target_port = 4242


[[Sydney RNS]]
    type = TCPClientInterface
    enabled = true
    target_host = sydney.reticulum.au
    target_port = 4242


[[dismails TCP Interface]]
    type = TCPClientInterface
    interface_enabled = true
    target_host = rns.dismail.de
    target_port = 7822


[[interloper node]]
    type = TCPClientInterface
    interface_enabled = true
    target_host = intr.cx
    target_port = 4242


[[noDNS1]]
    type = TCPClientInterface
    interface_enabled = true
    target_host = 202.61.243.41
    target_port = 4965


[[Beleth RNS Hub]]
    type = TCPClientInterface
    interface_enabled = true
    target_host = rns.beleth.net
    target_port = 4242


[[RNS reticulum.pt]]
    type = TCPClientInterface
    interface_enabled = true
    name = RNS reticulum.pt
    target_host = network.reticulum.pt
    target_port = 4242


[[BSDHell]]
    type = TCPClientInterface
    enabled = yes
    target_host = reticulum.bsdhell.com
    target_port = 4242


[[RNS - Derpy Cloud]]
    type = TCPClientInterface
    enabled = yes
    target_host = rns.derps.me
    target_port = 34242
EOF

chown -R "${RETICULUM_USER}:${RETICULUM_USER}" "${RNS_CONFIG}"
chmod 755 "${RNS_CONFIG}"
chmod 644 "${RNS_CONFIG}/config"

# ------------------------------------------------------------
# LXMF configuration
# ------------------------------------------------------------

echo
echo "=== Creating LXMF configuration ==="

mkdir -p "${LXMF_CONFIG}"

cat > "${LXMF_CONFIG}/config" <<'EOF'
[logging]

loglevel = 7


[propagation]

enable_node = yes

announce_interval = 360

announce_at_start = yes

autopeer = yes

autopeer_maxdepth = 6

message_storage_limit = 500

propagation_message_max_accepted_size = 256

propagation_sync_max_accepted_size = 10240

propagation_stamp_cost_target = 16

propagation_stamp_cost_flexibility = 3

peering_cost = 18

remote_peering_cost_max = 26

max_peers = 20

auth_required = no


[lxmf]

display_name = Anonymous Peer

announce_at_start = yes

announce_interval = 1

delivery_transfer_max_accepted_size = 1000
EOF

chown -R "${RETICULUM_USER}:${RETICULUM_USER}" "${LXMF_CONFIG}"
chmod 755 "${LXMF_CONFIG}"
chmod 644 "${LXMF_CONFIG}/config"

# ------------------------------------------------------------
# Nomad Network configuration
# ------------------------------------------------------------

echo
echo "=== Creating Nomad Network configuration ==="

mkdir -p "${NOMAD_CONFIG}"

cat > "${NOMAD_CONFIG}/config" <<'EOF'
[logging]

loglevel = 7
destination = file


[client]

enable_client = yes
user_interface = text
downloads_path = ~/Downloads
notify_on_new_message = yes

announce_at_start = yes

try_propagation_on_send_fail = yes

periodic_lxmf_sync = yes

lxmf_sync_interval = 360

lxmf_sync_limit = 8

required_stamp_cost = None

accept_invalid_stamps = False

max_accepted_size = 500

compact_announce_stream = yes


[textui]

intro_time = 1

theme = dark

colormode = 256

glyphs = unicode

mouse_enabled = True

editor = nano

hide_guide = no


[node]

enable_node = yes

node_name = Reticulum VPS

announce_interval = 360

announce_at_start = yes

disable_propagation = Yes

propagation_cost = 16

max_transfer_size = 256

max_sync_size = 10240


[printing]

print_messages = No

print_command = lp
EOF

chown -R "${RETICULUM_USER}:${RETICULUM_USER}" "${NOMAD_CONFIG}"
chmod 755 "${NOMAD_CONFIG}"
chmod 644 "${NOMAD_CONFIG}/config"

# ------------------------------------------------------------
# systemd: rnsd
# ------------------------------------------------------------

echo
echo "=== Creating rnsd systemd service ==="

cat > /etc/systemd/system/rnsd.service <<EOF
[Unit]
Description=Reticulum Network Stack
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${RETICULUM_USER}
Group=${RETICULUM_USER}
WorkingDirectory=${RETICULUM_HOME}
ExecStart=${VENV}/bin/rnsd
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------
# systemd: lxmd
# ------------------------------------------------------------

echo
echo "=== Creating lxmd systemd service ==="

cat > /etc/systemd/system/lxmd.service <<EOF
[Unit]
Description=LXMF Message Router
After=rnsd.service
Requires=rnsd.service

[Service]
Type=simple
User=${RETICULUM_USER}
Group=${RETICULUM_USER}
WorkingDirectory=${RETICULUM_HOME}
ExecStart=${VENV}/bin/lxmd
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------
# systemd: Nomad Network
# ------------------------------------------------------------

echo
echo "=== Creating Nomad Network systemd service ==="

cat > /etc/systemd/system/nomadnet.service <<EOF
[Unit]
Description=Nomad Network
After=rnsd.service lxmd.service
Requires=rnsd.service

[Service]
Type=simple
User=${RETICULUM_USER}
Group=${RETICULUM_USER}
WorkingDirectory=${RETICULUM_HOME}
ExecStart=${VENV}/bin/nomadnet --daemon
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------
# Enable and start services
# ------------------------------------------------------------

echo
echo "=== Starting services ==="

systemctl daemon-reload

systemctl enable rnsd.service
systemctl enable lxmd.service
systemctl enable nomadnet.service

systemctl restart rnsd.service
systemctl restart lxmd.service
systemctl restart nomadnet.service

# ------------------------------------------------------------
# Verify
# ------------------------------------------------------------

echo
echo "=== Service status ==="

systemctl --no-pager --full status rnsd.service || true

echo
systemctl --no-pager --full status lxmd.service || true

echo
systemctl --no-pager --full status nomadnet.service || true

echo
echo "============================================================"
echo "Reticulum stack installation complete."
echo
echo "Python environment:"
echo "  ${VENV}"
echo
echo "Reticulum configuration:"
echo "  ${RNS_CONFIG}/config"
echo
echo "LXMF configuration:"
echo "  ${LXMF_CONFIG}/config"
echo
echo "Nomad Network configuration:"
echo "  ${NOMAD_CONFIG}/config"
echo
echo "Services:"
echo "  systemctl status rnsd"
echo "  systemctl status lxmd"
echo "  systemctl status nomadnet"
echo
echo "Reticulum status:"
echo "  ${VENV}/bin/rnstatus"
echo
echo "Reticulum port:"
echo "  TCP 4242"
echo "============================================================"
