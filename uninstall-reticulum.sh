#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Reticulum / LXMF / Nomad Network uninstaller
#
# Removes the installation created by install-reticulum.sh
#
# Uninstalls:
#   - Reticulum (rns / rnsd)
#   - LXMF (lxmd)
#   - Nomad Network
#
# Does NOT remove system packages such as:
#   python3
#   python3-pip
#   python3-venv
#   ca-certificates
#   build-essential
#
# It also does not remove user-specific data such as:
# ~/.reticulum/
# ~/.nomadnetwork/
# UNLESS you use the --purge option.
#
# Designed for Debian/Ubuntu systems.
# To use this script, in a bash terminal you can run one of the following.
#
# for a normal uninstallation, WITHOUT removing user data, run:
# curl -fsSL https://raw.githubusercontent.com/Fatima-yo/Reticulum-Utils/main/uninstall-reticulum.sh | sudo bash
#
# for a full purge REMOVING user data, run:
# curl -fsSL https://raw.githubusercontent.com/Fatima-yo/Reticulum-Utils/main/uninstall-reticulum.sh | sudo bash -s -- --purge
#
# ============================================================

RETICULUM_USER="reticulum"
RETICULUM_HOME="/opt/reticulum"
VENV="${RETICULUM_HOME}/reticulum_env"

RNS_CONFIG="/etc/reticulum"
LXMF_CONFIG="/etc/lxmd"
NOMAD_CONFIG="/etc/nomadnetwork"

echo
echo "=== Reticulum stack uninstaller ==="

# ------------------------------------------------------------
# Parse command-line arguments
# ------------------------------------------------------------

echo
echo "=== Parse command line parameters ==="

PURGE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --purge)
            PURGE=true
            shift
            ;;
        *)
            echo "ERROR: Unknown argument: $1"
            echo
            echo "Usage:"
            echo "  $0"
            echo "  $0 --purge"
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------
# Check root
# ------------------------------------------------------------

echo
echo "=== Checking if you are root ==="

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This uninstaller must be run as root."
    echo
    echo "Use:"
    echo "  sudo bash uninstall-reticulum.sh"
    exit 1
fi

# ------------------------------------------------------------
# Check OS
# ------------------------------------------------------------

echo
echo "=== Checking if your system is Debian or Ubuntu ==="

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
# User confirmation
# ------------------------------------------------------------

echo
echo "IMPORTANT !!"
echo "Please read carefully."
echo
echo "This will remove:"
echo
echo "  Reticulum installation: ${RETICULUM_HOME}"
echo "  Reticulum config:       ${RNS_CONFIG}"
echo "  LXMF config:            ${LXMF_CONFIG}"
echo "  NomadNet config:        ${NOMAD_CONFIG}"
echo "  Systemd services:"
echo "    rnsd.service"
echo "    lxmd.service"
echo "    nomadnet.service"
echo "  CLI symlinks from /usr/local/bin"
echo "  System user:            ${RETICULUM_USER}"
echo
echo "System Python packages will NOT be removed."
echo

if [[ "${PURGE}" == true ]]; then
    echo "============================================================"
    echo "WARNING: PURGE MODE"
    echo "============================================================"
    echo
    echo "The following user data will ALSO be permanently removed:"
    echo
    echo "  /home/*/.reticulum"
    echo "  /home/*/.nomadnetwork"
    echo "  /root/.reticulum"
    echo "  /root/.nomadnetwork"
    echo
    echo "This may include Reticulum identities, keys, and"
    echo "NomadNet user data."
    echo
else
    echo "User-specific Reticulum and NomadNet data will be preserved:"
    echo
    echo "  /home/*/.reticulum"
    echo "  /home/*/.nomadnetwork"
    echo "  /root/.reticulum"
    echo "  /root/.nomadnetwork"
    echo
    echo "Use --purge if you also want to remove this data."
    echo
fi

if [[ ! -t 0 ]] && [[ ! -e /dev/tty ]]; then
    echo "ERROR: This uninstaller requires an interactive terminal."
    exit 1
fi

read -r -p "Continue? [y/N] " answer </dev/tty

if [[ ! "${answer}" =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# ------------------------------------------------------------
# Stop services
# ------------------------------------------------------------

echo
echo "=== Stopping services ==="

systemctl stop nomadnet.service 2>/dev/null || true
systemctl stop lxmd.service 2>/dev/null || true
systemctl stop rnsd.service 2>/dev/null || true

# ------------------------------------------------------------
# Disable services
# ------------------------------------------------------------

echo
echo "=== Disabling services ==="

systemctl disable nomadnet.service 2>/dev/null || true
systemctl disable lxmd.service 2>/dev/null || true
systemctl disable rnsd.service 2>/dev/null || true

# ------------------------------------------------------------
# Remove systemd service files
# ------------------------------------------------------------

echo
echo "=== Removing systemd services ==="

rm -f /etc/systemd/system/nomadnet.service
rm -f /etc/systemd/system/lxmd.service
rm -f /etc/systemd/system/rnsd.service

systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

# ------------------------------------------------------------
# Remove CLI symlinks
# ------------------------------------------------------------

echo
echo "=== Removing CLI commands ==="

for binary in \
    rns \
    rnsd \
    rnstatus \
    rnpath \
    rncp \
    rnprobe \
    rnsh \
    lxmd \
    nomadnet
do
    if [[ -L "/usr/local/bin/${binary}" ]]; then
        target="$(readlink "/usr/local/bin/${binary}")"

        if [[ "${target}" == "${VENV}/bin/${binary}" ]]; then
            rm -f "/usr/local/bin/${binary}"
        fi
    fi
done

# ------------------------------------------------------------
# Remove system configuration
# ------------------------------------------------------------

echo
echo "=== Removing system configuration ==="

rm -rf "${RNS_CONFIG}"
rm -rf "${LXMF_CONFIG}"
rm -rf "${NOMAD_CONFIG}"

# ------------------------------------------------------------
# Purge user data
# ------------------------------------------------------------

echo
echo "=== Removing user configuration ==="

if [[ "${PURGE}" == true ]]; then

    echo
    echo "=== Removing user Reticulum/NomadNet data ==="

    for user_home in /home/*; do

        [[ -d "${user_home}" ]] || continue

        rm -rf "${user_home}/.reticulum"
        rm -rf "${user_home}/.nomadnetwork"

    done

    rm -rf /root/.reticulum
    rm -rf /root/.nomadnetwork

fi

# ------------------------------------------------------------
# Remove Reticulum installation
# ------------------------------------------------------------

echo
echo "=== Removing Reticulum installation ==="

rm -rf "${RETICULUM_HOME}"

# ------------------------------------------------------------
# Remove system user
# ------------------------------------------------------------

echo
echo "=== Removing Reticulum system user ==="

if id "${RETICULUM_USER}" >/dev/null 2>&1; then
    userdel "${RETICULUM_USER}" 2>/dev/null || true
fi

# ------------------------------------------------------------
# Final verification
# ------------------------------------------------------------

echo
echo "=== Verification ==="

if id "${RETICULUM_USER}" >/dev/null 2>&1; then
    echo "WARNING: User ${RETICULUM_USER} still exists."
else
    echo "User ${RETICULUM_USER}: removed"
fi

if [[ -d "${RETICULUM_HOME}" ]]; then
    echo "WARNING: ${RETICULUM_HOME} still exists."
else
    echo "Installation directory: removed"
fi

echo

if [[ "${PURGE}" == true ]]; then

    echo "============================================================"
    echo "Reticulum stack completely uninstalled."
    echo "============================================================"
    echo
    echo "The following user data was also removed:"
    echo
    echo "  /home/*/.reticulum"
    echo "  /home/*/.nomadnetwork"
    echo "  /root/.reticulum"
    echo "  /root/.nomadnetwork"
    echo
    echo "System Python packages were intentionally left installed."

else

    echo "============================================================"
    echo "Reticulum stack uninstalled."
    echo "============================================================"
    echo
    echo "User-specific Reticulum and NomadNet data was preserved."
    echo
    echo "Preserved locations:"
    echo "  /home/*/.reticulum"
    echo "  /home/*/.nomadnetwork"
    echo "  /root/.reticulum"
    echo "  /root/.nomadnetwork"
    echo
    echo "Use --purge if you want to remove this data as well."
    echo
    echo "System Python packages were intentionally left installed."

fi

# ============================================================
# end of script
# ============================================================
