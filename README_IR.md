<p align="center">
  <a href="README.md">🇬🇧 English</a> |
  <a href="README_IR.md">IR فارسی</a>
</p>

# 🎮 Minecraft Server Auto Setup

![License](https://img.shields.io/github/license/launchercs/script-run-server-minecraft)
![Last Commit](https://img.shields.io/github/last-commit/launchercs/script-run-server-minecraft)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Termux%20%7C%20Windows-blue)
![Shell](https://img.shields.io/badge/shell-bash%20%7C%20batch-green)

Cross-platform scripts that automate setting up a **Minecraft Java Edition** server — Java installation, configuration, world backup, Aikar flags, and Playit.gg tunnel — all in one run.

## 📑 Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Usage](#-usage)
- [Environment Variables](#-environment-variables)
- [Troubleshooting](#-troubleshooting)
- [FAQ](#-faq)
- [Contributing](#-contributing)
- [License](#-license)

## ✨ Features

- 🚀 **Automated Setup** — installs and configures everything.
- 🧩 **Multi-Distro Linux** — Debian/Ubuntu, Fedora/RHEL, Arch, openSUSE, Alpine.
- ☕ **Adoptium (Temurin) JDK** — installs the correct JDK (8 / 11 / 17 / 21).
- 🎯 **Java Version Detection** — matches Minecraft release.
- 📦 **Automatic Dependencies** — only what each distro needs.
- 🎮 **Latest Minecraft Version** — from Mojang's official manifest.
- 🧠 **RAM Configuration** — CLI arg, env var, or interactive prompt.
- 🛠️ **Aikar Flags** — two presets (< 12 GB and ≥ 12 GB).
- ⚙️ **Auto Configuration** — generates `start.sh` + `server.properties`.
- 🔒 **Safe Re-run** — preserves `world`, `eula.txt`, `server.properties`.
- 💽 **Automatic World Backup** — `.tar.gz` before jar replacement.
- 🌐 **Playit.gg Integration** — public tunnel, no port-forwarding.
- 🖥️ **Screen Support** — persistent terminal session.
- ♻️ **Optional systemd Service** — auto-start on boot.
- 🧪 **Dry-run Mode** — preview without changes.

## 📋 Requirements

| Platform | Requirements |
|---|---|
| 🐧 Linux | `apt-get` / `dnf` / `pacman` / `zypper` / `apk`, internet, `sudo`, ≥ 3 GB free disk |
| 📱 Termux | Install from [F-Droid](https://f-droid.org/en/packages/com.termux/) (not Play Store) |
| 🪟 Windows | Windows 10/11 with `winget` (App Installer) |

## 🚀 Installation

```bash
git clone https://github.com/launchercs/script-run-server-minecraft.git
cd script-run-server-minecraft
chmod +x Linux-setup-run.sh termux-setup-run.sh
```

## 🎮 Usage

### Linux

```bash
./Linux-setup-run.sh                       # interactive
./Linux-setup-run.sh --ram 4096 -v 1.21.4  # explicit
./Linux-setup-run.sh --dry-run             # preview
```

### Termux

```bash
./termux-setup-run.sh --ram 1024
```

### Windows

```bat
windows-setup-run.bat 4096 1.21.4
```

### Running the server

```bash
./start.sh
screen -S mc ./start.sh      # Ctrl+A then D to detach
screen -r mc                 # reattach
```

## 🔧 Environment Variables

| Variable | Description | Default |
|---|---|---|
| `MC_RAM` | RAM in MB | `2048` |
| `MC_VERSION` | Minecraft version | `latest` |
| `PLAYIT_SECRET` | Playit.gg token | — |
| `LOG_FILE` | Log path | `setup.log` |

## 🐛 Troubleshooting

| Problem | Fix |
|---|---|
| Java not installed | Check Adoptium repo: `java -version` |
| Port 25565 busy | `ss -tulpn \| grep 25565` then kill |
| Playit.gg not connecting | Re-run `playit`, reset token |
| World lost | Restore from `world-backup-*.tar.gz` |
| Permission errors | Run with `sudo` (Linux) or as admin (Windows) |

Verbose logs:

```bash
bash -x ./Linux-setup-run.sh --ram 2048
```

## ❓ FAQ

**Does it work on Raspberry Pi?** Yes — use Alpine or Debian ARM, ≥ 1 GB RAM recommended.

**Forge/Fabric support?** No, Vanilla only. Replace `server.jar` manually after setup.

**Multiple servers?** Yes — copy folder, change `server-port`.

## 🤝 Contributing

1. Fork the repo
2. `git checkout -b feature/amazing`
3. `git commit -m 'Add amazing feature'`
4. `git push origin feature/amazing`
5. Open a Pull Request

Run before submitting:

```bash
shellcheck Linux-setup-run.sh termux-setup-run.sh common/lib.sh
```

## 📜 License

MIT — see [LICENSE](LICENSE).
