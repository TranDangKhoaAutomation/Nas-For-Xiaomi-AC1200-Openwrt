#!/bin/sh
# Install the complete NAS integration without importing device secrets.
set -eu
umask 077
DIR="$(CDPATH= cd -P "$(dirname "$0")" && pwd)"
cd "$DIR"
fail() { echo "ERROR: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail 'Run as root on OpenWrt.'
[ -r /etc/openwrt_release ] || fail 'OpenWrt is required.'
. /etc/openwrt_release
[ "${DISTRIB_RELEASE:-}" = 25.12.6 ] || fail 'This build requires OpenWrt 25.12.6. No firmware was changed.'
[ "${DISTRIB_TARGET:-}" = ramips/mt7621 ] || fail 'This build requires ramips/mt7621.'
[ "$(uname -r)" = 6.12.112 ] || fail 'Kernel mismatch: do not force the bundled kernel module.'
sha256sum -c SHA256SUMS >/dev/null || fail 'Bundle checksum mismatch.'
packages='block-mount cryptsetup lvm2 rpcd-mod-ucode ucode-mod-digest shadow-useradd ksmbd-server luci-app-ksmbd kmod-fs-ksmbd kmod-fs-ntfs3 kmod-usb-storage kmod-usb-xhci-hcd kmod-usb-xhci-mtk kmod-usb3 tailscale luci-app-tailscale-community luci-i18n-base-vi luci-i18n-ksmbd-vi'
[ -d /usr/share/luci/menu.d ] || packages="$packages luci"
missing=''
for pkg in $packages; do apk info -e "$pkg" >/dev/null 2>&1 || missing="$missing $pkg"; done
need_group=0
awk -F: '$3==1000 { found=1 } END { exit !found }' /etc/group || need_group=1
if [ "$need_group" = 1 ] && ! command -v groupadd >/dev/null; then missing="$missing shadow-groupadd"; fi
echo "OpenWrt $DISTRIB_RELEASE / $DISTRIB_TARGET / $(uname -r)"
echo "Missing packages:${missing:- none}"
if [ "${1:-}" = --check-only ]; then
    echo 'CHECK_OK: no configuration, account or disk was changed.'
    exit 0
fi
[ "${1:-}" = '' ] || fail 'Usage: sh install.sh [--check-only]'
mkdir /var/lock/khoanas-install.lock 2>/dev/null || fail 'Another installer is running.'
trap 'rmdir /var/lock/khoanas-install.lock 2>/dev/null || true' EXIT HUP INT TERM
if [ -n "$missing" ]; then apk update; apk add $missing; fi
if ! apk info -e kmod-dm-zero >/dev/null 2>&1; then
    module=payload/kmod-dm-zero-6.12.112.6.12.112-r1.apk
    echo '529230dbedb980ba65d7c0184da267fda0b403c5ed0c7f67565e2ea14dda9b10  payload/kmod-dm-zero-6.12.112.6.12.112-r1.apk' | sha256sum -c - >/dev/null || fail 'Pinned module checksum mismatch.'
    apk add --simulate --allow-untrusted "./$module"
    apk add --allow-untrusted "./$module"
fi
modprobe dm-zero
dmsetup targets | grep -q '^zero[[:space:]]' || fail 'The dm-zero target is unavailable.'
if [ "$need_group" = 1 ]; then groupadd -g 1000 khoanas_data; fi
backup="/root/khoanas-setup-$(date +%Y%m%d-%H%M%S)"
mkdir "$backup"
for file in /etc/config/firewall /etc/ksmbd/ksmbd.conf.template; do
    [ ! -f "$file" ] || cp -p "$file" "$backup/$(echo "$file" | tr / _)"
done
# Preserve an existing tailnet firewall policy. A fresh install uses device-based
# rules, never a LAN reload, WAN forwarding, guest sharing or an exit node.
if [ "$(ucode "$DIR/tailnet-policy.uc")" = 0 ]; then
    uci -q get firewall.khoanas_tailnet >/dev/null && fail 'khoanas_tailnet already exists; inspect the firewall first.'
    uci set firewall.khoanas_tailnet=zone
    uci set firewall.khoanas_tailnet.name=khoanas_tailnet
    uci set firewall.khoanas_tailnet.device=tailscale0
    uci set firewall.khoanas_tailnet.input=REJECT
    uci set firewall.khoanas_tailnet.output=ACCEPT
    uci set firewall.khoanas_tailnet.forward=REJECT
    uci set firewall.khoanas_access=rule
    uci set firewall.khoanas_access.name=KhoaNAS-Tailnet-Access
    uci set firewall.khoanas_access.src=khoanas_tailnet
    uci set firewall.khoanas_access.proto=tcp
    uci set firewall.khoanas_access.dest_port='22 80 445'
    uci set firewall.khoanas_access.target=ACCEPT
    uci commit firewall
    /etc/init.d/firewall reload
fi
sharing_changed=0
if ! grep -q tailscale0 /etc/ksmbd/ksmbd.conf.template; then
    grep -q '^[[:space:]]*interfaces[[:space:]]*=' /etc/ksmbd/ksmbd.conf.template || fail 'KSMBD interface template needs inspection.'
    sed -i '/^[[:space:]]*interfaces[[:space:]]*=/s/$/ tailscale0/' /etc/ksmbd/ksmbd.conf.template
    sharing_changed=1
fi
sh "$DIR/payload/luci/install.sh"
. "$DIR/service-helper.sh"
if [ "$sharing_changed" = 1 ]; then /etc/init.d/ksmbd enable; /etc/init.d/ksmbd restart;
else nas_start_if_stopped /etc/init.d/ksmbd; fi
nas_start_if_stopped /etc/init.d/tailscale tailscaled
echo "INSTALL_OK. Setup backup: $backup"
echo 'Open LuCI -> Services -> NAS. Existing disk settings, accounts and keys were preserved.'
echo 'For a fresh device, choose partitions/shares and enter your own passwords in LuCI; sign in to Tailscale.'
