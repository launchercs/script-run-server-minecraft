<p align="center">
  <a href="README.md">🇬🇧 English</a> |
  <a href="README_IR.md">IRفارسی</a>
</p>

<details open>
<summary><strong>🇬🇧 English</strong></summary>

# 🎮 Minecraft Server Auto Setup

Cross-platform scripts that automate the setup of a **Minecraft Java Edition** server —
including Java installation, server configuration, and **Playit.gg** tunnel setup — all in one run.

| Platform | Script |
|---|---|
| 🐧 Linux (multi-distro) | `Linux-setup-run.sh` |
| 📱 Termux (Android)     | `termux-setup-run.sh` |
| 🪟 Windows 10/11        | `windows-setup-run.bat` |

---

## ✨ Features

- 🚀 **Automated Setup** — Installs and configures the Minecraft server automatically.
- 🧩 **Multi-Distro Linux** — Works on Debian/Ubuntu, Fedora/RHEL, Arch, openSUSE, and Alpine.
- ☕ **Adoptium (Temurin) JDK** — Installs the correct JDK (8 / 11 / 17 / 21 / 25) independent of distro repos.
- 🎯 **Java Version Detection** — Selects the right Java version based on the Minecraft release.
- 📦 **Automatic Dependencies** — Installs only what each distro actually needs.
- 🎮 **Latest Minecraft Version** — Retrieved from Mojang's official version manifest.
- 🧠 **RAM Configuration** — Via CLI argument, environment variable, or interactive prompt.
- 🛠️ **Aikar Flags** — Two tuning presets (< 12 GB and ≥ 12 GB RAM).
- ⚙️ **Automatic Configuration** — Generates `start.sh` and a basic `server.properties` file.
- 🔒 **Safe Re-run** — Existing world, `eula.txt`, and `server.properties` are preserved.
- 💽 **Automatic World Backup** — `.tar.gz` snapshot before any `server.jar` replacement.
- 🌐 **Playit.gg Integration** — Sets up a tunnel to make your server accessible remotely.
- 🖥️ **Screen Support** — Runs the server in a persistent terminal session.
- ♻️ **Optional systemd Service** — Auto-start on boot.

---

## 📋 Requirements

**🐧 Linux**
- One of: `apt-get`, `dnf`, `pacman`, `zypper`, `apk`
- Internet connection
- `sudo` privileges (or run as `root`)
- Sufficient RAM and storage
- A [Playit.gg](https://playit.gg) account (free) for tunnel connectivity

**📱 Termux** — Install from [F-Droid](https://f-droid.org/packages/com.termux/) (not Play Store).

**🪟 Windows** — Windows 10/11 with `winget` (App Installer).

---

## 🚀 Getting Started

1. **Clone this repository:**
   ```bash
   git clone https://github.com/launchercs/script-run-server-minecraft.git
   cd script-run-server-minecraft
