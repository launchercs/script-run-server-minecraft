#!/usr/bin/env bash
# termux-setup-run.sh — راهاندازی سرور ماینکرافت روی Termux (اندروید)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common/lib.sh
source "$SCRIPT_DIR/common/lib.sh"

usage() {
  cat <<EOF
${BOLD}Usage:${NC} $0 [OPTIONS]

گزینهها:
  -r, --ram <MB>       مقدار RAM به مگابایت (پیشفرض: 1024 روی موبایل)
  -v, --version <VER>  نسخه ماینکرافت (پیشفرض: latest)
  -d, --dry-run        فقط نمایش مراحل
  -h, --help           راهنما
EOF
}

main() {
  parse_common_args "$@"

  # حداقل RAM روی موبایل
  if [ "$RAM" -lt 1024 ]; then
    warn "RAM روی Termux معمولاً محدود است؛ مقدار افزایش یافت به 1024."
    RAM=1024
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

  backup_world

  local url
  url=$(get_server_jar_url "$MC_VERSION")
  [ -n "$url" ] || die "URL پیدا نشد."
  log "دانلود server.jar..."
  curl -fL --progress-bar "$url" -o server.jar

  write_start_script "$RAM" "server.jar"
  write_server_properties
  accept_eula

  if ! command -v playit >/dev/null; then
    log "نصب Playit.gg برای Termux..."
    curl -fsSL https://playit.gg/install.sh | bash || warn "نصب Playit.gg ناموفق."
  fi

  ok "🎉 آماده است! اجرا: ./start.sh"
}

main "$@"
