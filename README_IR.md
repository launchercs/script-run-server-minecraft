<p align="center">
  <a href="README.md">🇬🇧 English</a> |
  <a href="README_IR.md">IRفارسی</a>
</p>

<details open>
<summary><strong>IRفارسی</strong></summary>

# 🎮 راه‌اندازی خودکار سرور ماینکرفت

اسکریپت‌های چندسکویی که راه‌اندازی سرور **Minecraft Java Edition** را خودکار می‌کنند —
شامل نصب جاوا، پیکربندی سرور، و راه‌اندازی تونل **Playit.gg** — همه در یک اجرا.

| پلتفرم | اسکریپت |
|---|---|
| 🐧 لینوکس (چند توزیع) | `Linux-setup-run.sh` |
| 📱 Termux (اندروید)   | `termux-setup-run.sh` |
| 🪟 ویندوز ۱۰/۱۱        | `windows-setup-run.bat` |

---

## ✨ امکانات

- 🚀 **راه‌اندازی خودکار** — سرور ماینکرفت را بدون دخالت دستی نصب و پیکربندی می‌کند.
- 🧩 **پشتیبانی چند توزیع لینوکس** — Debian/Ubuntu، Fedora/RHEL، Arch، openSUSE و Alpine.
- ☕ **نصب Adoptium (Temurin) JDK** — بدون وابستگی به مخازن توزیع، شامل Java 25.
- 🎯 **تشخیص نسخه جاوا** — انتخاب نسخه مناسب جاوا بر اساس نسخه ماینکرفت.
- 📦 **نصب خودکار پیش‌نیازها** — فقط بسته‌های مورد نیاز هر توزیع.
- 🎮 **آخرین نسخه ماینکرفت** — دریافت از مانیفست رسمی موجانگ.
- 🧠 **پیکربندی رم** — از طریق آرگومان، متغیر محیطی یا پرسش تعاملی.
- 🛠️ **Aikar Flags** — دو پروفایل تنظیم جدا (زیر ۱۲GB و بالای ۱۲GB).
- ⚙️ **پیکربندی خودکار** — ساخت `start.sh` و فایل پایه `server.properties`.
- 🔒 **اجرای ایمن مجدد** — world، `eula.txt` و `server.properties` حفظ می‌شوند.
- 💽 **بکاپ خودکار world** — اسنپ‌شات `.tar.gz` پیش از هر جایگزینی `server.jar`.
- 🌐 **یکپارچگی با Playit.gg** — راه‌اندازی تونل برای دسترسی از راه دور.
- 🖥️ **پشتیبانی از Screen** — اجرای سرور در یک نشست ترمینال پایدار.
- ♻️ **سرویس systemd (اختیاری)** — اجرای خودکار هنگام بوت.

---

## 📋 پیش‌نیازها

**🐧 لینوکس**
- یکی از: `apt-get`، `dnf`، `pacman`، `zypper`، `apk`
- اتصال به اینترنت
- دسترسی `sudo` (یا اجرا به‌عنوان `root`)
- رم و فضای ذخیره‌سازی کافی
- یک حساب [Playit.gg](https://playit.gg) (رایگان) برای اتصال تونل

**📱 Termux** — از [F-Droid](https://f-droid.org/packages/com.termux/) نصب شود (نه Play Store).

**🪟 ویندوز** — ویندوز ۱۰/۱۱ به‌همراه `winget` (App Installer).

---

## 🚀 شروع کار

۱. **کلون کردن مخزن:**
   ```bash
   git clone https://github.com/launchercs/script-run-server-minecraft.git
   cd script-run-server-minecraft
