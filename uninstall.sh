#!/bin/sh
# Remove Argon installed by argon-theme-installer.
set -eu

log() { printf '%s\n' "[argon] $*"; }
warn() { printf '%s\n' "[argon][warn] $*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

PKG_MANAGER="unknown"
if have apk; then
    PKG_MANAGER="apk"
elif have opkg; then
    PKG_MANAGER="opkg"
fi

log "Package manager: $PKG_MANAGER"

case "$PKG_MANAGER" in
    apk)
        apk del luci-app-argon-config luci-theme-argon || true
        ;;
    opkg)
        opkg remove luci-app-argon-config luci-theme-argon || true
        ;;
    *)
        warn "Neither apk nor opkg found; skipping package removal."
        ;;
esac

if have uci; then
    if [ -s /etc/argon-installer/previous-mediaurlbase ]; then
        old="$(cat /etc/argon-installer/previous-mediaurlbase)"
        [ -n "$old" ] && uci set luci.main.mediaurlbase="$old" || true
    else
        uci set luci.main.mediaurlbase='/luci-static/bootstrap' || true
    fi
    uci commit luci || true
fi

rm -f /tmp/luci-indexcache /tmp/luci-indexcache.* 2>/dev/null || true
rm -rf /tmp/luci-modulecache /tmp/luci-modulecache/ 2>/dev/null || true
/etc/init.d/rpcd restart 2>/dev/null || killall -HUP rpcd 2>/dev/null || true
/etc/init.d/uhttpd restart 2>/dev/null || true

log "Done. Argon packages removed and LuCI theme setting restored/fallbacked."
