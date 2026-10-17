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
UPDATE_LISTS=1

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
  --force-online     allow extra online dependency recovery if local install fails
  --skip-update      skip package indexes and automatic OpenWrt 25 CA installation
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
        --skip-update) UPDATE_LISTS=0 ;;
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

is_openwrt25_apk() {
    [ "$PKG_MANAGER" = "apk" ] || return 1
    case "$DISTRIB_RELEASE" in
        25.*) return 0 ;;
        *) return 1 ;;
    esac
}

https_help() {
    warn "HTTPS failed. Check 'date', internet access and trusted CA certificates."
    warn "If the clock is wrong: /etc/init.d/sysntpd restart; then verify 'date' again."
    warn "On OpenWrt 25/APK: apk update && apk add ca-bundle ca-certificates"
    warn "If APK also fails TLS verification, transfer trusted CA packages and dependencies from a PC."
    warn "If install.sh itself cannot be downloaded, copy the extracted project to /tmp using SCP/SFTP."
}

check_openwrt25_clock() {
    is_openwrt25_apk || return 0
    log "Router time: $(date) (compare with the actual date/time)"
    # A lower bound only: an apparently plausible date does not prove NTP sync.
    clock_year="$(date +%Y)"
    case "$clock_year" in
        ''|*[!0-9]*) warn "Cannot validate the router clock; check it manually." ;;
        *)
            if [ "$clock_year" -lt 2025 ]; then
                warn "The clock predates OpenWrt 25; TLS certificate verification may fail."
                if [ "$DRY_RUN" = "0" ] && [ "$UPDATE_LISTS" = "1" ]; then
                    https_help
                    fail "Correct the router clock before online installation."
                fi
            fi
            ;;
    esac
}

ensure_openwrt25_ca() {
    is_openwrt25_apk || return 0
    if [ "$UPDATE_LISTS" = "0" ]; then
        log "Automatic CA installation skipped by --skip-update"
        return 0
    fi
    if [ "$DRY_RUN" = "1" ]; then
        log "DRY-RUN: ensure ca-bundle and ca-certificates with apk add"
        return 0
    fi
    if apk info -e ca-bundle >/dev/null 2>&1 &&
       apk info -e ca-certificates >/dev/null 2>&1 &&
       [ -s /etc/ssl/certs/ca-certificates.crt ]; then
        log "Trusted CA certificates are already installed"
        return 0
    fi
    log "Installing HTTPS prerequisites: ca-bundle ca-certificates"
    if ! apk add ca-bundle ca-certificates; then
        https_help
        fail "CA installation failed; Argon has not been installed."
    fi
    if [ ! -s /etc/ssl/certs/ca-certificates.crt ]; then
        fail "CA bundle is missing or empty after installation. Check package files; try: apk fix ca-bundle"
    fi
}

refresh_package_lists() {
    [ "$UPDATE_LISTS" = "1" ] || {
        log "Package list update skipped by --skip-update"
        return 0
    }

    if [ "$DRY_RUN" = "1" ]; then
        case "$PKG_MANAGER" in
            opkg) log "DRY-RUN: opkg update" ;;
            apk) log "DRY-RUN: apk update" ;;
        esac
        return 0
    fi

    case "$PKG_MANAGER" in
        opkg)
            log "Updating OPKG package lists: opkg update"
            opkg update || fail "opkg update failed. Check internet access and configured OpenWrt feeds."
            ;;
        apk)
            log "Updating APK package indexes: apk update"
            if ! apk update; then
                is_openwrt25_apk && https_help
                fail "apk update failed. Check internet access and configured OpenWrt repositories."
            fi
            ;;
    esac
}

fetch_file() {
    url="$1"
    out="$2"

    log "Downloading: $url"
    if have uclient-fetch; then
        uclient-fetch -O "$out" "$url" && return 0
    elif have wget; then
        wget -O "$out" "$url" && return 0
    elif have curl; then
        curl -L --fail -o "$out" "$url" && return 0
    else
        fail "wget/curl/uclient-fetch not found"
    fi
    https_help
    fail "Download failed: $url"
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

apk_add_local() {
    # Use configured APK repositories for dependencies, but do not change repository files.
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

check_openwrt25_clock

case "$PKG_MANAGER" in
    apk|opkg)
        refresh_package_lists
        ;;
    *)
        fail "Neither apk nor opkg was found. This does not look like a supported OpenWrt-like system."
        ;;
esac

ensure_openwrt25_ca

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
