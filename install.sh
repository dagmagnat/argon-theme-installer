#!/bin/sh
# OpenWrt Argon universal installer
# Supports OPKG based OpenWrt/ImmortalWrt/X-Wrt and APK based OpenWrt snapshots/25.x+.

set -eu

REPO_OWNER="${REPO_OWNER:-dagmagnat}"
REPO_NAME="${REPO_NAME:-argon-theme-installer}"
REPO_BRANCH="${REPO_BRANCH:-main}"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}}"

TMP_DIR="${TMPDIR:-/tmp}/argon-installer.$$"
INSTALL_CONFIG=1
DRY_RUN=0
FORCE_ONLINE=0

OPKG_THEME="luci-theme-argon_2.3.2-r20250207_all1.ipk"
OPKG_CONFIG="luci-app-argon-config_0.9_all.ipk"
APK_THEME="luci-theme-argon-2.4.3-r20250722.apk"
APK_CONFIG="luci-app-argon-config-1.0-r20230608.apk"

SHA_OPKG_THEME="8836e6bb0f94d610c87a9077fbfbd1681f4f0d17b29d6d3af13a58ca4f504a33"
SHA_OPKG_CONFIG="bd8c055b33cd01d70aea9946c0ed3b69e2ea780181783332afa086b2864affd5"
SHA_APK_THEME="def42025429048aef138145717f449d15076843e49d24aa942c840ea29f1f533"
SHA_APK_CONFIG="f868ba28ea32338bae13ef80ffd022114eeac56b67a01d6068cd8dfba3cff8ac"

log() { printf '%s\n' "[argon] $*"; }
warn() { printf '%s\n' "[argon][warn] $*" >&2; }
fail() { printf '%s\n' "[argon][error] $*" >&2; exit 1; }

usage() {
    cat <<EOF
OpenWrt Argon universal installer

Usage:
  sh install.sh [options]

Options:
  --theme-only       install only luci-theme-argon, skip luci-app-argon-config
  --force-online     allow package manager to use configured official repositories if needed
  --dry-run          print detected system and selected packages without installing
  --base-url URL     override package download base URL
  -h, --help         show this help

Environment:
  REPO_OWNER         GitHub owner, default: ${REPO_OWNER}
  REPO_NAME          GitHub repo, default: ${REPO_NAME}
  REPO_BRANCH        GitHub branch, default: ${REPO_BRANCH}
  BASE_URL           full raw base URL, overrides owner/name/branch
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --theme-only) INSTALL_CONFIG=0 ;;
        --force-online) FORCE_ONLINE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --base-url) shift; [ "$#" -gt 0 ] || fail "--base-url requires a value"; BASE_URL="$1" ;;
        --base-url=*) BASE_URL="${1#*=}" ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
    shift
done

cleanup() { rm -rf "$TMP_DIR" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

read_openwrt_info() {
    DISTRIB_ID="unknown"
    DISTRIB_RELEASE="unknown"
    DISTRIB_TARGET="unknown"
    DISTRIB_ARCH="unknown"
    [ -r /etc/openwrt_release ] && . /etc/openwrt_release || true
    if [ "$DISTRIB_ID" = "unknown" ] && [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release || true
        DISTRIB_ID="${NAME:-unknown}"
        DISTRIB_RELEASE="${VERSION_ID:-unknown}"
    fi
}

detect_pkg_manager() {
    if command -v apk >/dev/null 2>&1; then
        echo "apk"
    elif command -v opkg >/dev/null 2>&1; then
        echo "opkg"
    else
        echo "unknown"
    fi
}

have() { command -v "$1" >/dev/null 2>&1; }

fetch_file() {
    url="$1"
    out="$2"

    log "Downloading: $url"
    if have uclient-fetch; then
        uclient-fetch -O "$out" "$url" 2>/dev/null || \
        uclient-fetch --no-check-certificate -O "$out" "$url"
    elif have wget; then
        wget -O "$out" "$url" 2>/dev/null || \
        wget --no-check-certificate -O "$out" "$url"
    elif have curl; then
        curl -L --fail -o "$out" "$url" || \
        curl -k -L --fail -o "$out" "$url"
    else
        fail "wget/curl/uclient-fetch not found"
    fi
}

check_sha256() {
    file="$1"
    expected="$2"
    [ -n "$expected" ] || return 0
    if ! have sha256sum; then
        warn "sha256sum not found; checksum verification skipped"
        return 0
    fi
    actual="$(sha256sum "$file" | awk '{print $1}')"
    [ "$actual" = "$expected" ] || fail "checksum mismatch for $(basename "$file")"
}

local_or_download() {
    rel="$1"
    out="$2"
    sha="$3"

    # If packages are present next to this script, use them. Useful when the repo was copied to /tmp manually.
    script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || echo .)"
    if [ -f "$script_dir/$rel" ]; then
        cp "$script_dir/$rel" "$out"
    else
        fetch_file "$BASE_URL/$rel" "$out"
    fi
    check_sha256 "$out" "$sha"
}

backup_luci_theme_setting() {
    mkdir -p /etc/argon-installer 2>/dev/null || true
    if have uci && [ ! -f /etc/argon-installer/previous-mediaurlbase ]; then
        uci get luci.main.mediaurlbase >/etc/argon-installer/previous-mediaurlbase 2>/dev/null || true
    fi
}

activate_argon() {
    if have uci; then
        backup_luci_theme_setting
        uci set luci.main.mediaurlbase='/luci-static/argon' || true
        uci commit luci || true
    fi
    rm -f /tmp/luci-indexcache /tmp/luci-indexcache.* 2>/dev/null || true
    rm -rf /tmp/luci-modulecache /tmp/luci-modulecache/ 2>/dev/null || true
    /etc/init.d/rpcd restart 2>/dev/null || killall -HUP rpcd 2>/dev/null || true
    /etc/init.d/uhttpd restart 2>/dev/null || true
}

install_with_opkg() {
    theme="$TMP_DIR/$OPKG_THEME"
    config="$TMP_DIR/$OPKG_CONFIG"
    local pkgs

    mkdir -p "$TMP_DIR"
    local_or_download "packages/opkg/$OPKG_THEME" "$theme" "$SHA_OPKG_THEME"
    if [ "$INSTALL_CONFIG" = "1" ]; then
        local_or_download "packages/opkg/$OPKG_CONFIG" "$config" "$SHA_OPKG_CONFIG"
        pkgs="$theme $config"
    else
        pkgs="$theme"
    fi

    if [ "$DRY_RUN" = "1" ]; then
        log "DRY-RUN: opkg install $pkgs"
        return 0
    fi

    log "Installing Argon with opkg"
    if opkg install $pkgs; then
        return 0
    fi

    if [ "$FORCE_ONLINE" = "1" ]; then
        warn "Local opkg install failed. Trying official repositories for missing dependencies."
        opkg update || true
        opkg install curl jsonfilter luci-lua-runtime luci-compat || true
        opkg install $pkgs
    else
        fail "opkg install failed. Run again with --force-online if dependencies are missing."
    fi
}

apk_supports_no_network() {
    apk --help 2>&1 | grep -q -- '--no-network' && return 0
    apk add --help 2>&1 | grep -q -- '--no-network' && return 0
    return 1
}

apk_add_local() {
    if [ "$FORCE_ONLINE" = "0" ] && apk_supports_no_network; then
        apk --no-network add --allow-untrusted "$@" && return 0
        warn "Offline APK install failed; retrying with configured repositories."
    fi
    apk add --allow-untrusted "$@"
}

install_with_apk() {
    theme="$TMP_DIR/$APK_THEME"
    config="$TMP_DIR/$APK_CONFIG"

    mkdir -p "$TMP_DIR"
    local_or_download "packages/apk/$APK_THEME" "$theme" "$SHA_APK_THEME"
    if [ "$INSTALL_CONFIG" = "1" ]; then
        local_or_download "packages/apk/$APK_CONFIG" "$config" "$SHA_APK_CONFIG"
        set -- "$theme" "$config"
    else
        set -- "$theme"
    fi

    if [ "$DRY_RUN" = "1" ]; then
        log "DRY-RUN: apk add --allow-untrusted $*"
        return 0
    fi

    log "Installing Argon with apk"
    apk_add_local "$@"
}

read_openwrt_info
PKG_MANAGER="$(detect_pkg_manager)"

log "Firmware: ${DISTRIB_ID} ${DISTRIB_RELEASE}"
log "Target: ${DISTRIB_TARGET}; arch: ${DISTRIB_ARCH}"
log "Package manager: ${PKG_MANAGER}"
log "Base URL: ${BASE_URL}"

case "$PKG_MANAGER" in
    apk)
        install_with_apk
        ;;
    opkg)
        install_with_opkg
        ;;
    *)
        fail "Neither apk nor opkg was found. This does not look like a supported OpenWrt-like system."
        ;;
esac

if [ "$DRY_RUN" = "0" ]; then
    activate_argon
    log "Done. Argon is installed and selected as LuCI theme. Reopen LuCI or refresh the page."
else
    log "Dry run finished. No changes were made."
fi
