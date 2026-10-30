# Starting OpenWrt Tailscale while it is already running can execute its cleanup
# path and interrupt the very connection used to install this bundle.
nas_start_if_stopped() {
    "$1" enable
    if [ -n "${2:-}" ] && pidof "$2" >/dev/null 2>&1; then return 0; fi
    if "$1" status >/dev/null 2>&1; then return 0; fi
    "$1" start
}
