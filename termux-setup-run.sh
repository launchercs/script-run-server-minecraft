#!/usr/bin/env bash
# termux-setup-run.sh — راهاندازی سرور ماینکرافت روی Termux (اندروید)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# بارگذاری توابع مشترک
# shellcheck source=common/lib.sh
source "$SCRIPT_DIR/common/lib.sh"

usage() {
  cat <<EOF
${BOLD}استفاده:${NC} $0 [گزینه‌ها]

گزینه‌ها:
  -r, --ram <MB>       مقدار RAM به مگابایت (پیشفرض: 1024 روی موبایل)
  -v, --version <VER>  نسخه ماینکرافت (پیشفرض: latest)
  -d, --dry-run        فقط نمایش مراحل
  -h, --help           راهنما

نکات:
  - Termux فقط از OpenJDK 21 پشتیبانی می‌کند
  - حداقل RAM توصیه‌شده: 1024MB
  - نیاز به اتصال پایدار اینترنت دارد

مثال:
  $0 --ram 2048
EOF
}

main() {
  log "🎮 راهاندازی سرور ماینکرافت (Termux - اندروید)"
  
  parse_common_args "$@"

  # حداقل RAM روی موبایل
  if [ "$RAM" -lt 1024 ]; then
    warn "RAM روی Termux معمولاً محدود است؛ مقدار افزایش یافت به 1024."
    RAM=1024
  fi

  if [ "$RAM" -gt 4096 ]; then
    warn "RAM بیشتر از 4GB روی Termux معمولاً کافی نیست."
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[DRY-RUN] مراحل زیر اجرا می‌شوند:"
    log "  1. بهروزرسانی مخازن Termux"
    log "  2. نصب OpenJDK 21، curl، tar"
    log "  3. دانلود server.jar"
    log "  4. ساخت start.sh و server.properties"
    log "  5. نصب Playit.gg (اختیاری)"
    return 0
  fi

  log "بهروزرسانی مخازن Termux..."
  pkg update -y && pkg upgrade -y

  log "نصب پیشنیازها..."
  pkg install -y curl tar openjdk-21 wget

  local distro_java
  distro_java=$(java_version_for_mc "$MC_VERSION")
  if [ "$distro_java" != "21" ]; then
    warn "Termux فقط از OpenJDK 21 پشتیبانی میکند؛ نسخه $distro_java ممکن است کار نکند."
  fi

  require_cmd java
  ok "Java نصب شد: $(java -version 2>&1 | head -1)"

  backup_world

  local url
  url=$(get_server_jar_url "$MC_VERSION")
  [ -n "$url" ] || die "URL دانلود پیدا نشد."

  log "دانلود server.jar (نسخه $MC_VERSION)..."
  curl -fL --progress-bar "$url" -o server.jar || die "دانلود ناموفق"
  ok "server.jar دانلود شد."

  write_start_script "$RAM" "server.jar"
  write_server_properties
  accept_eula

  # نصب Playit.gg (اختیاری برای تونل پابلیک)
  if ! command -v playit >/dev/null 2>&1; then
    log "آیا می‌خواهید Playit.gg (برای تونل پابلیک) نصب کنید؟ (y/n)"
    read -rp "انتخاب: " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
      log "نصب Playit.gg برای Termux..."
      curl -fsSL https://playit.gg/install.sh | bash || warn "نصب Playit.gg ناموفق (اختیاری)"
    fi
  fi

  ok "🎉 سرور آماده است!"
  log "برای اجرای سرور:"
  log "  chmod +x start.sh"
  log "  ./start.sh"
  log ""
  log "راهنمای کامل:"
  log "  https://github.com/launchercs/script-run-server-minecraft"
}

main "$@"
