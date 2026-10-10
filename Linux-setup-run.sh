#!/usr/bin/env bash
# Linux-setup-run.sh — راهاندازی خودکار سرور ماینکرافت روی لینوکس
# پشتیبان‌شده: Debian/Ubuntu, Fedora/RHEL, Arch, openSUSE, Alpine

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# بارگذاری توابع مشترک
# shellcheck source=common/lib.sh
source "$SCRIPT_DIR/common/lib.sh"

# تشخیص توزیع لینوکس
detect_distro() {
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    echo "$ID"
  else
    die "نمی‌توان توزیع را شناسایی کنند."
  fi
}

# نصب پیشنیازها بر اساس توزیع
install_dependencies() {
  local distro="$1"
  log "نصب پیشنیازها برای $distro..."

  case "$distro" in
    ubuntu|debian)
      sudo apt-get update -qq
      sudo apt-get install -y curl wget tar gzip
      ;;
    fedora|rhel|centos)
      sudo dnf install -y curl wget tar gzip
      ;;
    arch)
      sudo pacman -Syu --noconfirm curl wget tar gzip
      ;;
    opensuse*)
      sudo zypper install -y curl wget tar gzip
      ;;
    alpine)
      sudo apk add --no-cache curl wget tar gzip
      ;;
    *)
      warn "توزیع شناخته‌شده نیست: $distro"
      ;;
  esac
  ok "پیشنیازها نصب شدند."
}

# نصب Java
install_java() {
  local distro="$1"
  local java_version="$2"
  
  log "نصب Java $java_version..."

  case "$distro" in
    ubuntu|debian)
      sudo apt-get install -y openjdk-${java_version}-jdk
      ;;
    fedora|rhel|centos)
      sudo dnf install -y java-${java_version}-openjdk java-${java_version}-openjdk-devel
      ;;
    arch)
      sudo pacman -S --noconfirm jdk${java_version}-openjdk
      ;;
    opensuse*)
      sudo zypper install -y java-${java_version}-openjdk java-${java_version}-openjdk-devel
      ;;
    alpine)
      sudo apk add --no-cache openjdk${java_version}
      ;;
    *)
      warn "نصب خودکار Java برای $distro پشتیبانی نمی‌شود"
      ;;
  esac

  require_cmd java
  ok "Java $java_version نصب شد: $(java -version 2>&1 | head -1)"
}

usage() {
  cat <<EOF
${BOLD}استفاده:${NC} $0 [گزینه‌ها]

گزینه‌ها:
  -r, --ram <MB>       مقدار RAM به مگابایت (پیشفرض: 2048)
  -v, --version <VER>  نسخه ماینکرافت (پیشفرض: latest)
  -d, --dry-run        فقط نمایش مراحل
  -h, --help           راهنما

مثال:
  $0 --ram 4096 --version 1.21.4
  $0 -r 2048 -v latest
EOF
}

main() {
  log "🎮 راهاندازی سرور ماینکرافت (لینوکس)"
  
  parse_common_args "$@"

  local distro
  distro=$(detect_distro)
  log "توزیع تشخیص‌داده‌شده: $distro"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "[DRY-RUN] مراحل زیر اجرا می‌شوند (بدون تغییر واقعی):"
    log "  1. نصب پیشنیازها"
    log "  2. نصب Java"
    log "  3. دانلود server.jar"
    log "  4. ساخت start.sh و server.properties"
    return 0
  fi

  check_disk_space 3072

  install_dependencies "$distro"

  local java_version
  java_version=$(java_version_for_mc "$MC_VERSION")
  install_java "$distro" "$java_version"

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

  ok "🎉 راهاندازی کامل شد!"
  log "برای اجرای سرور:"
  log "  ./start.sh"
  log ""
  log "یا برای اجرای پایدار (Screen):"
  log "  screen -S mc ./start.sh"
  log "  (Ctrl+A سپس D برای خروج)"
  log "  screen -r mc (بازگشت)"
}

main "$@"
