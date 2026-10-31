#!/bin/sh
# Run through LAN or a local console, never through the tunnel being repaired.
set -eu

nas_ts_guard_session() {
    for address in ${SSH_CONNECTION:-}; do
        case "$address" in
            fd7a:115c:a1e0:*|FD7A:115C:A1E0:*)
                echo 'Từ chối: phiên SSH đang dùng Tailscale. Hãy dùng LAN hoặc console.' >&2
                return 1 ;;
            100.*|::ffff:100.*|::FFFF:100.*)
                address=${address##*:}
                second=${address#100.}; second=${second%%.*}
                case "$second" in ''|*[!0-9]*) continue ;; esac
                if [ "$second" -ge 64 ] && [ "$second" -le 127 ]; then
                    echo 'Từ chối: phiên SSH đang dùng dải Tailscale/CGNAT. Hãy dùng LAN hoặc console.' >&2
                    return 1
                fi ;;
        esac
    done
}

nas_ts_service() { /etc/init.d/tailscale "$1"; }

nas_ts_restart() {
    nas_ts_guard_session || return 1
    echo 'Đang dừng Tailscale qua dịch vụ OpenWrt…'
    nas_ts_service stop || return 1
    remaining=10
    while pidof tailscaled >/dev/null 2>&1; do
        if [ "$remaining" -eq 0 ]; then
            echo 'Tailscale chưa dừng. Không chạy start/cleanup khi tiến trình cũ còn hoạt động.' >&2
            return 1
        fi
        remaining=$((remaining - 1))
        sleep 1
    done
    echo 'Tiến trình cũ đã dừng; đang khởi chạy lại với cấu hình và đăng nhập hiện có…'
    nas_ts_service start
}

nas_ts_check() {
    echo 'Địa chỉ trên giao diện hệ điều hành:'
    ip addr show dev tailscale0 || return 1
    echo 'Địa chỉ do Tailscale công bố:'
    tailscale ip || return 1
    echo 'Cần kiểm tra SSH, web và SMB từ một thiết bị Tailscale khác để xác nhận truy cập.'
}

nas_ts_main() {
    case "${1:---check}" in --check|--restart) ;; *) echo 'Dùng: sh repair-tailscale.sh [--check|--restart]' >&2; return 2 ;; esac
    [ "$#" -le 1 ] || { echo 'Quá nhiều tham số.' >&2; return 2; }
    [ -r /etc/openwrt_release ] || { echo 'Chỉ dùng trên OpenWrt.' >&2; return 1; }
    command -v tailscale >/dev/null || { echo 'Chưa cài Tailscale.' >&2; return 1; }
    if [ "${1:---check}" = --restart ]; then
        [ "$(id -u)" = 0 ] || { echo 'Cần quyền root để khởi động lại dịch vụ.' >&2; return 1; }
        [ -x /etc/init.d/tailscale ] || { echo 'Không tìm thấy dịch vụ Tailscale OpenWrt.' >&2; return 1; }
        nas_ts_restart || return 1
        # Wait for the daemon to apply its existing address to the kernel.
        remaining=20
        while [ "$remaining" -gt 0 ]; do
            expected=$(tailscale ip -4 2>/dev/null) || expected=''
            if [ -n "$expected" ] && ip -4 addr show dev tailscale0 2>/dev/null | grep -Fq "inet $expected/"; then
                nas_ts_check
                return
            fi
            remaining=$((remaining - 1))
            sleep 1
        done
        echo 'Chưa xác nhận được địa chỉ trên tailscale0. Giữ phiên LAN để kiểm tra; không reset hay đăng nhập lại.' >&2
        nas_ts_check || true
        return 1
    fi
    nas_ts_check
}

nas_ts_main "$@"
