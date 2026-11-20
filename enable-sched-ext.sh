#!/usr/bin/env bash
set -uo pipefail

# Enable scx_lavd (sched_ext) as the default CPU scheduler via scx_loader.
#
# Why: this kernel has sched_ext compiled in and scx_lavd is already
# installed, but nothing is ever attached to it — /sys/kernel/sched_ext/root/ops
# stays empty, so the stock EEVDF scheduler runs instead. scx_lavd's "Auto"
# mode uses --autopilot, which shifts between power-saving and performance
# based on load — the reason the CachyOS kernel ships these schedulers.
#
# Usage:  sudo ./enable-sched-ext.sh
# Undo:   sudo scxctl stop && sudo systemctl disable --now scx_loader.service

if [ "$(id -u)" -ne 0 ]; then
    echo "Needs root: sudo $0" >&2
    exit 1
fi

if ! command -v scx_loader >/dev/null; then
    echo "scx_loader not found — pacman -S scx-tools scx-scheds" >&2
    exit 1
fi

if [ ! -d /sys/kernel/sched_ext ]; then
    echo "this kernel has no sched_ext support — nothing to do" >&2
    exit 1
fi

# 1. Default scheduler at boot. "Auto" resolves to --autopilot --pinned-slice-us 500
mkdir -p /etc/scx_loader
cat > /etc/scx_loader/config.toml <<'EOF'
# Managed by enable-sched-ext.sh — scx_loader starts this scheduler on boot.
default_sched = "scx_lavd"
default_mode = "Auto"
EOF
chmod 644 /etc/scx_loader/config.toml
echo "wrote /etc/scx_loader/config.toml"

# 2. Start at boot. The unit is D-Bus activated, so only 'enabled' makes it
#    apply the default scheduler at boot instead of on the first scxctl call.
systemctl enable scx_loader.service || exit 1

# 3. Restart so the just-written config is read and scx_lavd attaches now.
#    (The unit may already be active from D-Bus activation, in which case
#    'enable --now' alone would leave the stock scheduler running.)
systemctl restart scx_loader.service || exit 1
sleep 2

echo
echo "--- verification ---"
echo "sched_ext ops : $(cat /sys/kernel/sched_ext/root/ops 2>/dev/null || echo none)"
echo "unit enabled  : $(systemctl is-enabled scx_loader.service 2>/dev/null)"
scxctl get 2>&1 | sed 's/^/  /'
