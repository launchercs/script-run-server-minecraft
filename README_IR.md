<p align="center">
  <a href="README.md">🇬🇧 English</a> |
  <a href="README_IR.md">IR فارسی</a>
</p>

# 🎮 راه‌اندازی خودکار سرور ماینکرفت

اسکریپت‌های چندسکویی برای راه‌اندازی خودکار سرور **Minecraft Java Edition** — نصب Java، پیکربندی، بکاپ world، Aikar Flags و تونل Playit.gg در یک اجرا.

## 📑 فهرست

- [امکانات](#-امکانات)
- [پیش‌نیازها](#-پیش‌نیازها)
- [نصب](#-نصب)
- [استفاده](#-استفاده)
- [متغیرهای محیطی](#-متغیرهای-محیطی)
- [عیب‌یابی](#-عیب‌یابی)
- [سوالات متداول](#-سوالات-متداول)
- [مشارکت](#-مشارکت)
- [مجوز](#-مجوز)

## ✨ امکانات

- 🚀 **راه‌اندازی خودکار** — همه‌چیز نصب و پیکربندی می‌شود
- 🧩 **چند توزیعی** — Debian/Ubuntu، Fedora/RHEL، Arch، openSUSE، Alpine
- ☕ **Adoptium JDK** — نصب نسخه مناسب (8/11/17/21) مستقل از مخازن توزیع
- 🎯 **تشخیص نسخه Java** — بر اساس نسخه ماینکرفت
- 📦 **نصب پیش‌نیازها** — فقط چیزهایی که لازم است
- 🎮 **آخرین نسخه** — از manifest رسمی موجانگ
- 🧠 **تنظیم RAM** — آرگومان، env یا پرسش تعاملی
- 🛠️ **Aikar Flags** — دو پروفایل (< 12GB و ≥ 12GB)
- 💽 **بکاپ خودکار** — فایل `.tar.gz` قبل از جایگزینی jar
- 🌐 **Playit.gg** — تونل بدون نیاز به port-forward
- 🖥️ **screen** — اجرای پایدار سرور
- ♻️ **سرویس systemd** — استارت خودکار در بوت
- 🧪 **حالت dry-run** — پیش‌نمایش بدون تغییر

## 📋 پیش‌نیازها

| پلتفرم | نیازمندی‌ها |
|---|---|
| 🐧 Linux | `apt-get` / `dnf` / `pacman` / `zypper` / `apk`، اینترنت، `sudo`، حداقل ۳GB دیسک |
| 📱 Termux | از [F-Droid](https://f-droid.org/en/packages/com.termux/) نصب کن (نه Play Store) |
| 🪟 Windows | ویندوز ۱۰/۱۱ با `winget` (App Installer) |

## 🚀 نصب

```bash
git clone https://github.com/launchercs/script-run-server-minecraft.git
cd script-run-server-minecraft
chmod +x Linux-setup-run.sh termux-setup-run.sh
```

## 🎮 استفاده

### Linux

```bash
./Linux-setup-run.sh                       # تعاملی
./Linux-setup-run.sh --ram 4096 -v 1.21.4  # صریح
./Linux-setup-run.sh --dry-run             # پیش‌نمایش
```

### Termux

```bash
./termux-setup-run.sh --ram 1024
```

### Windows

```bat
windows-setup-run.bat 4096 1.21.4
```

### اجرای سرور

```bash
./start.sh
screen -S mc ./start.sh      # خروج: Ctrl+A سپس D
screen -r mc                 # بازگشت
```

## 🔧 متغیرهای محیطی

| متغیر | توضیح | پیش‌فرض |
|---|---|---|
| `MC_RAM` | RAM به مگابایت | `2048` |
| `MC_VERSION` | نسخه ماینکرفت | `latest` |
| `PLAYIT_SECRET` | توکن Playit.gg | — |
| `LOG_FILE` | مسیر لاگ | `setup.log` |

## 🐛 عیب‌یابی

| مشکل | راه‌حل |
|---|---|
| Java نصب نیست | `java -version` را چک کن |
| پورت ۲۵۵۶۵ اشغال است | `ss -tulpn \| grep 25565` و kill |
| Playit وصل نمی‌شود | `playit` را دوباره اجرا و توکن را بازنشانی کن |
| world از دست رفت | از `world-backup-*.tar.gz` بازیابی کن |
| خطای دسترسی | با `sudo` (لینوکس) یا Administrator (ویندوز) |

لاگ verbose:

```bash
bash -x ./Linux-setup-run.sh --ram 2048
```

## ❓ سوالات متداول

**روی رزبری‌پای کار می‌کند؟** بله — Alpine یا Debian ARM، حداقل ۱GB RAM.

**از Forge/Fabric پشتیبانی می‌کند؟** خیر، فقط Vanilla. بعد از راه‌اندازی `server.jar` را دستی عوض کن.

**چند سرور همزمان؟** بله — پوشه را کپی و `server-port` را تغییر بده.

## 🤝 مشارکت

1. Fork کن
2. `git checkout -b feature/amazing`
3. `git commit -m 'Add amazing feature'`
4. `git push origin feature/amazing`
5. Pull Request باز کن

قبل از ارسال:

```bash
shellcheck Linux-setup-run.sh termux-setup-run.sh common/lib.sh
```

## 📜 مجوز

MIT — فایل [LICENSE](LICENSE) را ببین.
