#!/bin/sh
set -eu
USER_NAME="${1:-nas}"
ksmbd.adduser -u "$USER_NAME"
/etc/init.d/ksmbd restart
/etc/init.d/ksmbd status || true
