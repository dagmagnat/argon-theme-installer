# Packages

This folder contains local LuCI Argon packages used by `install.sh`.

- `packages/opkg/*.ipk` — for OpenWrt/ImmortalWrt/X-Wrt builds that use `opkg`.
- `packages/apk/*.apk` — for OpenWrt/ImmortalWrt/X-Wrt builds that use `apk`.

The installer selects the package manager by checking commands on the router, not by guessing CPU architecture.
