#!/bin/sh
set -eu

OUT="\${1:-/tmp/openwrt-private-backup.tar.gz}"
umask 077

echo "WARNING: this backup may contain passwords, hashes, SSH host keys and network secrets."
echo "Do not upload it to a public GitHub repository."

sysupgrade -b "$OUT"
chmod 600 "$OUT"
sha256sum "$OUT"
echo "Private backup: $OUT"
