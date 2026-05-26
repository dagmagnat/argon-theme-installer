# OpenWrt Argon Installer

Universal installer for the LuCI Argon theme on OpenWrt-like firmware: OpenWrt, ImmortalWrt, X-Wrt and similar builds.

The script does **not** replace OpenWrt repositories, does **not** edit package feeds, and does **not** run `apk upgrade`. It only downloads local Argon packages from this repository and installs them through the package manager already present on the router.

## What it installs

For OPKG-based builds:

- `luci-theme-argon_2.3.2-r20250207_all1.ipk`
- `luci-app-argon-config_0.9_all.ipk`

For APK-based builds:

- `luci-theme-argon-2.4.3-r20250722.apk`
- `luci-app-argon-config-1.0-r20230608.apk`

## Install with one command

Before publishing, edit `install.sh` and set your real GitHub username here:

```sh
REPO_OWNER="amored997"
```

Then upload this repository to GitHub as:

```text
https://github.com/amored997/openwrt-argon-installer
```

Install from router SSH:

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/amored997/openwrt-argon-installer/main/install.sh)"
```

If your router has `curl` instead of `wget`:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/amored997/openwrt-argon-installer/main/install.sh)"
```

If your GitHub username is different, either edit `install.sh` or run:

```sh
REPO_OWNER="YOUR_GITHUB_USERNAME" sh -c "$(wget -O- https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/openwrt-argon-installer/main/install.sh)"
```

## Safe install mode

Default mode is conservative:

- `apk`: first tries local/offline package install with `--allow-untrusted` and `--no-network` when supported.
- `opkg`: installs the bundled local IPK packages.
- repositories are not edited.
- `apk upgrade` is never used.

If installation fails because dependencies are missing, run:

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/amored997/openwrt-argon-installer/main/install.sh)" -- --force-online
```

This still uses the router's existing official repositories; it does not replace them.

## Options

```text
--theme-only       install only luci-theme-argon, skip luci-app-argon-config
--force-online     allow native package manager to fetch missing dependencies
--dry-run          show detected firmware/package manager and selected package
--base-url URL     override raw package URL
-h, --help         show help
```

Examples:

```sh
# Test without changing the router
sh -c "$(wget -O- https://raw.githubusercontent.com/amored997/openwrt-argon-installer/main/install.sh)" -- --dry-run

# Install only theme, without Argon config app
sh -c "$(wget -O- https://raw.githubusercontent.com/amored997/openwrt-argon-installer/main/install.sh)" -- --theme-only
```

## Uninstall

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/amored997/openwrt-argon-installer/main/uninstall.sh)"
```

## Manual local install

You can copy the whole repository folder to `/tmp/openwrt-argon-installer` on the router and run:

```sh
cd /tmp/openwrt-argon-installer
sh install.sh
```

In this mode the script uses local files from `packages/` and does not download them again.

## Notes

- APK here means the OpenWrt/Alpine-style package format, not Android APK.
- The theme packages are LuCI packages and are not selected by CPU architecture.
- Kernel modules and VPN packages such as AmneziaWG are a separate problem and should be handled by a different installer module, because they depend on target, subtarget, architecture and kernel ABI.
