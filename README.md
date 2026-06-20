# Slopsmith Desktop

Standalone cross-platform desktop app that wraps [Slopsmith](https://github.com/got-feedback/feedBack) with integrated VST hosting, amp modeling, audio I/O, and full plugin support.

## Install

Prebuilt installers for the latest tagged release are published on the
[GitHub Releases page](https://github.com/got-feedback/feedBack-desktop/releases/latest).

| Platform | Download | Notes |
|----------|----------|-------|
| Windows 10/11 (x64) | `Slopsmith.Setup.<version>.exe` | NSIS installer. On first run Windows SmartScreen may warn — click *More info → Run anyway*. |
| macOS 12+ (Apple Silicon) | `Slopsmith-<version>-arm64.dmg` | Signed & notarized. Intel Macs are not currently published — build from source. |
| Linux (x86_64) | `Slopsmith-<version>.AppImage` | `chmod +x` then run. Portable, no install step. |
| Debian / Ubuntu (x86_64) | `slopsmith-desktop_<version>_amd64.deb` | `sudo apt install ./slopsmith-desktop_<version>_amd64.deb` |

> **First launch may take a minute or two** while ML model caches populate
> in the app cache directory. Subsequent launches are fast.

There is currently no Homebrew, winget, Chocolatey, Scoop, Flatpak, or
Snap distribution — download directly from Releases. The app does not
yet ship an auto-updater; check Releases periodically for new versions.
