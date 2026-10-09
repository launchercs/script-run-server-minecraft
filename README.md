<p align="center">
  <a href="README.md">🇬🇧 English</a> |
  <a href="README_FA.md">IRفارسی</a>
</p>

<details>
<summary><strong>🇬🇧 English</strong></summary>

# 🎮 Minecraft Server Auto Setup

A Bash script that automates the setup of a Minecraft Java Edition server, including Java installation, server configuration, and Playit.gg tunnel setup.

---

## ✨ Features

- 🚀 **Automated Setup** — Installs and configures the Minecraft server automatically.
- ☕ **Java Version Detection** — Selects a Java version based on the Minecraft version.
- 📦 **Automatic Dependencies** — Installs the required packages and tools.
- 🎮 **Latest Minecraft Version** — Retrieves the latest release information from Mojang's official version manifest.
- 🧠 **RAM Configuration** — Allows you to specify the amount of RAM allocated to the server.
- ⚙️ **Automatic Configuration** — Generates startup scripts and a basic `server.properties` file.
- 🌐 **Playit.gg Integration** — Sets up a tunnel to make your server accessible remotely.
- 🖥️ **Screen Support** — Helps run the server in a persistent terminal session.

---

## 📋 Requirements

- A compatible Linux system with `apt-get`
- Internet connection
- `sudo` privileges
- Sufficient RAM and storage
- A [Playit.gg](https://playit.gg) account for tunnel connectivity

---

## 🚀 Getting Started

1. **Clone this repository:**
   ```bash
   git clone https://github.com/launchercs/script-run-server-minecraft.git
   ```

2. **Enter the project directory:**
   ```bash
   cd script-run-server-minecraft
   ```

3. **Run the setup script:**
   ```bash
   chmod +x .run.sh
   ./.run.sh
   ```

4. **Follow the on-screen instructions** to configure your server.

---

## 🧩 Configuration

The script can accept a RAM allocation argument, for example:

```bash
./.run.sh 4G
```

You can also configure the RAM allocation using the `ENV_MAX_RAM` environment variable.

---

## ⚠️ Important Notes

- This script is designed primarily for Linux distributions that use `apt-get`; it is **not guaranteed** to work directly in Termux or on Windows.
- Review Minecraft's **End User License Agreement (EULA)** before running the server.
- Keep your system and server software updated.
- Java compatibility depends on the Minecraft version and the Java packages available on your system.

---

## 👨‍💻 Author

Created from scratch by [launchercs](https://github.com/launchercs).

---

## 📜 License

Check the repository for license information before redistributing or modifying this project.
