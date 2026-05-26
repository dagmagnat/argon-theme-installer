# OpenWrt Argon Installer

**Русский** | [English](#english)

Универсальный установщик темы **LuCI Argon** для OpenWrt и похожих прошивок: **OpenWrt**, **ImmortalWrt**, **X-Wrt** и других сборок на базе OpenWrt.

Скрипт сам определяет пакетный менеджер на роутере:

- если найден `apk` — устанавливает `.apk` пакеты для новых OpenWrt/APK-систем;
- если найден `opkg` — устанавливает `.ipk` пакеты для классических OpenWrt/OPKG-систем.

> Важно: здесь `APK` — это пакетный формат OpenWrt/Alpine, **не Android APK**.

## Что делает установщик

- устанавливает тему `luci-theme-argon`;
- устанавливает приложение настроек `luci-app-argon-config`;
- включает Argon как активную тему LuCI;
- очищает кэш LuCI;
- перезапускает `rpcd` и `uhttpd`, чтобы интерфейс обновился.

## Что установщик НЕ делает

- не заменяет системные репозитории OpenWrt;
- не редактирует feeds;
- не запускает `apk upgrade`;
- не обновляет прошивку;
- не устанавливает AmneziaWG/WireGuard или другие VPN-пакеты.

Это сделано специально, чтобы установка темы не ломала обновление пакетов в родной системе.

## Какие пакеты входят в проект

Для OPKG-систем, например OpenWrt 23/24:

```text
luci-theme-argon_2.3.2-r20250207_all1.ipk
luci-app-argon-config_0.9_all.ipk
```

Для APK-систем, например новые OpenWrt 25+ сборки:

```text
luci-theme-argon-2.4.3-r20250722.apk
luci-app-argon-config-1.0-r20230608.apk
```

Пакеты темы LuCI не выбираются по CPU-архитектуре роутера. Для Argon обычно достаточно выбрать правильный тип пакетного менеджера: `opkg` или `apk`.

## Установка одной командой

Подключитесь к роутеру по SSH и выполните:

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main/install.sh)"
```

Если на роутере есть `curl`, но нет `wget`:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main/install.sh)"
```

После установки обновите страницу LuCI или зайдите в веб-интерфейс заново.

## Безопасная проверка без установки

Можно проверить, что именно определит скрипт, не меняя систему:

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main/install.sh)" -- --dry-run
```

## Установка только темы, без приложения настроек Argon

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main/install.sh)" -- --theme-only
```

## Если не хватает зависимостей

По умолчанию скрипт старается ставить локальные пакеты максимально осторожно. Если установка не прошла из-за отсутствующих зависимостей, можно разрешить штатному пакетному менеджеру использовать уже настроенные репозитории прошивки:

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main/install.sh)" -- --force-online
```

Этот режим **не заменяет** репозитории. Он использует только те источники пакетов, которые уже настроены в вашей прошивке.

## Удаление

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main/uninstall.sh)"
```

Скрипт удаления удалит `luci-theme-argon` и `luci-app-argon-config`, затем вернёт предыдущую тему LuCI, если она была сохранена. Если предыдущая тема не найдена, будет выбран стандартный Bootstrap.

## Локальная установка без GitHub

Можно скопировать весь проект на роутер, например в `/tmp/openwrt-argon-installer`, и запустить установку локально:

```sh
cd /tmp/openwrt-argon-installer
sh install.sh
```

В этом режиме скрипт возьмёт пакеты из папки `packages/` и не будет скачивать их заново.

## Опции install.sh

```text
--theme-only       установить только luci-theme-argon, без luci-app-argon-config
--force-online     разрешить пакетному менеджеру скачать недостающие зависимости
--dry-run          показать определённую систему и выбранные пакеты без установки
--base-url URL     использовать другой raw URL для загрузки пакетов
-h, --help         показать справку
```

## Решение частых проблем

### LuCI не изменился после установки

Обновите страницу без кэша или зайдите в LuCI заново. Также можно перезапустить веб-интерфейс:

```sh
/etc/init.d/uhttpd restart
/etc/init.d/rpcd restart
```

### Установка APK пишет про неподписанный пакет

Это нормально для локального пакета из GitHub. Скрипт использует:

```sh
apk add --allow-untrusted файл.apk
```

### После установки не открывается LuCI

Подключитесь по SSH и удалите тему:

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main/uninstall.sh)"
```

### У меня ImmortalWrt или X-Wrt

Скрипт не привязан жёстко к названию прошивки. Он проверяет наличие `apk` или `opkg`, поэтому должен работать и на форках OpenWrt, если они используют совместимый пакетный менеджер и LuCI.

## Для разработчиков

Переменные окружения:

```sh
REPO_OWNER="dagmagnat"
REPO_NAME="openwrt-argon-installer"
REPO_BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main"
```

Пример запуска из другого форка:

```sh
REPO_OWNER="YOUR_GITHUB_USERNAME" REPO_NAME="openwrt-argon-installer" sh -c "$(wget -O- https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/openwrt-argon-installer/main/install.sh)"
```

## Важное замечание про AmneziaWG

AmneziaWG не включён в этот установщик. Для AmneziaWG нужен отдельный установщик, потому что VPN/kernel-пакеты зависят от target, subtarget, архитектуры и версии ядра. Для LuCI-темы Argon такая проверка обычно не нужна.

---

# English

Universal installer for the **LuCI Argon** theme on OpenWrt-like firmware: **OpenWrt**, **ImmortalWrt**, **X-Wrt**, and similar OpenWrt-based builds.

The script automatically detects the package manager on the router:

- if `apk` is available, it installs `.apk` packages for newer OpenWrt/APK-based systems;
- if `opkg` is available, it installs `.ipk` packages for classic OpenWrt/OPKG-based systems.

> Important: `APK` here means the OpenWrt/Alpine package format, **not Android APK**.

## What the installer does

- installs `luci-theme-argon`;
- installs `luci-app-argon-config`;
- enables Argon as the active LuCI theme;
- clears LuCI cache;
- restarts `rpcd` and `uhttpd` so the web interface reloads correctly.

## What the installer does NOT do

- it does not replace OpenWrt repositories;
- it does not edit package feeds;
- it does not run `apk upgrade`;
- it does not upgrade firmware;
- it does not install AmneziaWG/WireGuard or any other VPN packages.

This is intentional: the installer only installs the theme and avoids breaking native package updates.

## Included packages

For OPKG-based systems, for example OpenWrt 23/24:

```text
luci-theme-argon_2.3.2-r20250207_all1.ipk
luci-app-argon-config_0.9_all.ipk
```

For APK-based systems, for example newer OpenWrt 25+ builds:

```text
luci-theme-argon-2.4.3-r20250722.apk
luci-app-argon-config-1.0-r20230608.apk
```

LuCI theme packages are usually not selected by router CPU architecture. For Argon, the important part is the package manager type: `opkg` or `apk`.

## One-command installation

Connect to the router over SSH and run:

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main/install.sh)"
```

If your router has `curl` instead of `wget`:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main/install.sh)"
```

After installation, refresh LuCI or log in to the web interface again.

## Safe dry run

You can check what the script detects without changing the system:

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main/install.sh)" -- --dry-run
```

## Install only the theme, without Argon config app

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main/install.sh)" -- --theme-only
```

## If dependencies are missing

By default, the script tries to install bundled local packages conservatively. If installation fails because dependencies are missing, you can allow the native package manager to use the repositories already configured on the router:

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main/install.sh)" -- --force-online
```

This mode does **not** replace repositories. It only uses the package sources already configured in your firmware.

## Uninstall

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main/uninstall.sh)"
```

The uninstall script removes `luci-theme-argon` and `luci-app-argon-config`, then restores the previous LuCI theme if it was saved. If no previous theme is found, it falls back to Bootstrap.

## Local installation without GitHub

You can copy the whole project to the router, for example to `/tmp/openwrt-argon-installer`, and run:

```sh
cd /tmp/openwrt-argon-installer
sh install.sh
```

In this mode, the script uses local packages from `packages/` and does not download them again.

## install.sh options

```text
--theme-only       install only luci-theme-argon, skip luci-app-argon-config
--force-online     allow the package manager to fetch missing dependencies
--dry-run          show detected system and selected packages without installing
--base-url URL     use another raw URL for package downloads
-h, --help         show help
```

## Troubleshooting

### LuCI did not change after installation

Refresh the page without cache or log in again. You can also restart the web interface:

```sh
/etc/init.d/uhttpd restart
/etc/init.d/rpcd restart
```

### APK installation reports an untrusted package

This is expected for a local package from GitHub. The script uses:

```sh
apk add --allow-untrusted file.apk
```

### LuCI does not open after installation

Connect through SSH and remove the theme:

```sh
sh -c "$(wget -O- https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main/uninstall.sh)"
```

### I use ImmortalWrt or X-Wrt

The script is not hardcoded to one firmware name. It checks for `apk` or `opkg`, so it should work on OpenWrt forks if they use a compatible package manager and LuCI.

## For developers

Environment variables:

```sh
REPO_OWNER="dagmagnat"
REPO_NAME="openwrt-argon-installer"
REPO_BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/dagmagnat/openwrt-argon-installer/main"
```

Run from another fork:

```sh
REPO_OWNER="YOUR_GITHUB_USERNAME" REPO_NAME="openwrt-argon-installer" sh -c "$(wget -O- https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/openwrt-argon-installer/main/install.sh)"
```

## Important note about AmneziaWG

AmneziaWG is not included in this installer. It needs a separate installer because VPN/kernel packages depend on target, subtarget, architecture, and kernel version. A LuCI theme like Argon usually does not need that kind of check.
