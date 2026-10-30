#!/bin/sh
# Install the generic LuCI Disk Manager. Never import, print or upload keys.
set -eu
umask 077
DIR="$(CDPATH= cd -P "$(dirname "$0")" && pwd)"
[ "$(id -u)" = 0 ] || { echo 'Run this installer as root on OpenWrt.' >&2; exit 1; }
for cmd in ucode uci ubus blkid cryptsetup dmsetup; do
    command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2; exit 1; }
done
[ -f /usr/lib/rpcd/ucode.so ] || { echo 'Install rpcd-mod-ucode first.' >&2; exit 1; }
[ -d /usr/share/luci/menu.d ] || { echo 'LuCI is required.' >&2; exit 1; }
[ ! -d /tmp/nas-disks/action.lock ] || { echo 'Wait for the current disk operation to finish.' >&2; exit 1; }
for file in nas-disks-manager nas-disks-job nas-disks.init 96-nas-disks; do sh -n "$DIR/$file"; done
ucode -c -o /tmp/nas-disks-check.ucb "$DIR/disks.uc"
ucode -c -o /tmp/nas-disks-scan-check.ucb "$DIR/nas-disks-scan"
ucode -c -o /tmp/nas-disks-theme-check.ucb "$DIR/patch-material.uc"

backup="/root/nas-disks-install-$(date +%Y%m%d-%H%M%S)"
mkdir "$backup"
for file in /etc/config/nas_disks /etc/config/fstab /etc/crontabs/root \
    /usr/share/ucode/luci/template/themes/material/header.ut \
    /usr/sbin/nas-disks-manager /usr/sbin/nas-disks-job /usr/sbin/nas-disks-scan \
    /etc/init.d/nas-disks /etc/hotplug.d/block/96-nas-disks \
    /usr/share/rpcd/ucode/disks.uc /usr/share/rpcd/acl.d/luci-app-nas-disks.json \
    /usr/share/luci/menu.d/luci-app-nas-disks.json /www/luci-static/resources/view/nas-disks.js \
    /www/luci-static/resources/view/nas-connect.js \
    /www/luci-static/material/menu-layout-fix.css \
    /usr/lib/lua/luci/i18n/nas-disks.vi.lmo /usr/lib/lua/luci/i18n/nas-disks.en.lmo; do
    if [ -f "$file" ]; then cp -p "$file" "$backup/$(echo "$file" | tr / _)"; fi
done
# Retire the earlier single-volume BitLocker integration, without deleting keys.
if [ -x /etc/init.d/nas-bitlocker ]; then /etc/init.d/nas-bitlocker disable; fi
for file in /etc/hotplug.d/block/95-nas-bitlocker /etc/hotplug.d/block/99-bitlocker \
    /etc/hotplug.d/block/99-bitlockerprintf /usr/share/rpcd/ucode/bitlocker.uc \
    /usr/share/luci/menu.d/luci-app-nas-bitlocker.json /usr/share/rpcd/acl.d/luci-app-nas-bitlocker.json; do
    if [ -f "$file" ]; then mv "$file" "$backup/$(echo "$file" | tr / _)"; fi
done
mkdir -p /etc/nas-disks/keys
chmod 700 /etc/nas-disks /etc/nas-disks/keys
test -e /etc/config/nas_disks || touch /etc/config/nas_disks
for file in nas-disks-manager nas-disks-job nas-disks-scan; do
    cp "$DIR/$file" "/usr/sbin/$file"
    chmod 700 "/usr/sbin/$file"
done
cp "$DIR/nas-disks.init" /etc/init.d/nas-disks
cp "$DIR/96-nas-disks" /etc/hotplug.d/block/96-nas-disks
chmod 755 /etc/init.d/nas-disks
chmod 700 /etc/hotplug.d/block/96-nas-disks
cp "$DIR/disks.uc" /usr/share/rpcd/ucode/disks.uc
cp "$DIR/acl.json" /usr/share/rpcd/acl.d/luci-app-nas-disks.json
cp "$DIR/menu.json" /usr/share/luci/menu.d/luci-app-nas-disks.json
cp "$DIR/nas-disks.js" /www/luci-static/resources/view/nas-disks.js
cp "$DIR/nas-connect.js" /www/luci-static/resources/view/nas-connect.js
cp "$DIR/nas-disks.vi.lmo" /usr/lib/lua/luci/i18n/nas-disks.vi.lmo
cp "$DIR/nas-disks.en.lmo" /usr/lib/lua/luci/i18n/nas-disks.en.lmo
chmod 644 /usr/share/rpcd/ucode/disks.uc /usr/share/rpcd/acl.d/luci-app-nas-disks.json \
    /usr/share/luci/menu.d/luci-app-nas-disks.json /www/luci-static/resources/view/nas-disks.js \
    /www/luci-static/resources/view/nas-connect.js \
    /usr/lib/lua/luci/i18n/nas-disks.vi.lmo /usr/lib/lua/luci/i18n/nas-disks.en.lmo
if [ -d /www/luci-static/material ]; then
    cp "$DIR/material-layout-fix.css" /www/luci-static/material/menu-layout-fix.css
    chmod 644 /www/luci-static/material/menu-layout-fix.css
    ucode "$DIR/patch-material.uc"
fi
touch /etc/crontabs/root
awk '!/\/usr\/sbin\/nas-bitlocker-watchdog/ && !/\/usr\/sbin\/nas-disks-manager reconcile/' \
    /etc/crontabs/root > /etc/crontabs/root.nas-disks-new
printf '%s\n' '* * * * * /usr/sbin/nas-disks-manager reconcile >/dev/null 2>&1' >> /etc/crontabs/root.nas-disks-new
chmod 600 /etc/crontabs/root.nas-disks-new
mv -f /etc/crontabs/root.nas-disks-new /etc/crontabs/root
/etc/init.d/nas-disks enable
/etc/init.d/cron enable
/etc/init.d/cron restart
/etc/init.d/rpcd reload
for cache in /tmp/luci-indexcache.*.json; do [ ! -f "$cache" ] || rm -f "$cache"; done
/usr/sbin/nas-disks-scan >/dev/null 2>&1 &
printf 'Installed. Backup: %s\nLog in to LuCI again, then open System -> Disk Manager.\n' "$backup"
