#!/usr/bin/env bash
# common/lib.sh — توابع مشترک برای همه اسکریپتها
# استفاده: source "$(dirname "$0")/common/lib.sh"

set -euo pipefail

# ---------- رنگها ----------
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

# ---------- لاگ ----------
LOG_FILE="${LOG_FILE:-setup.log}"
log()   { printf "${BLUE}[INFO]${NC} %s\n"  "$*" | tee -a "$LOG_FILE"; }
ok()    { printf "${GREEN}[ OK ]${NC} %s\n" "$*" | tee -a "$LOG_FILE"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$*" | tee -a "$LOG_FILE"; }
err()   { printf "${RED}[FAIL]${NC} %s\n"  "$*" | tee -a "$LOG_FILE" >&2; }
die()   { err "$*"; exit 1; }

# ---------- Trap ----------
on_error() {
  local code=$?
  err "خطا در خط $1 (کد خروج: $code)"
  exit "$code"
}
trap 'on_error $LINENO' ERR

# ---------- بررسی پیشنیازها ----------
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "دستور '$1' یافت نشد. لطفاً نصبش کن."
}

check_disk_space() {
  local need_mb="${1:-2048}"
  local avail
  avail=$(df -m . | awk 'NR==2 {print $4}')
  if [ "$avail" -lt "$need_mb" ]; then
    die "فضای دیسک کافی نیست (نیاز: ${need_mb}MB، موجود: ${avail}MB)"
  fi
  ok "فضای دیسک کافی است (${avail}MB)"
}

# ---------- اعتبارسنجی RAM ----------
validate_ram() {
  local ram="$1"
  [[ "$ram" =~ ^[0-9]+$ ]] || die "RAM باید عدد صحیح باشد: '$ram'"
  [ "$ram" -ge 1024 ] || die "حداقل RAM 1024MB است."
  [ "$ram" -le 65536 ] || die "حداکثر RAM 65536MB است."
  echo "$ram"
}

# ---------- گرفتن آخرین نسخه ماینکرافت ----------
get_latest_mc_version() {
  require_cmd curl
  local manifest="https://launchermeta.mojang.com/mc/game/version_manifest.json"
  curl -fsSL "$manifest" \
    | grep -o '"latest":{"release":"[^"]*"' \
    | sed 's/.*"release":"//;s/"//'
}

# ---------- گرفتن URL دانلود server.jar ----------
get_server_jar_url() {
  local version="$1"
  require_cmd curl
  local manifest="https://launchermeta.mojang.com/mc/game/version_manifest.json"
  local version_url
  version_url=$(curl -fsSL "$manifest" \
    | grep -o "\"id\":\"$version\",\"type\":\"[^\"]*\",\"url\":\"[^\"]*\"" \
    | grep -o 'https://[^"]*' | head -n1)

  [ -n "$version_url" ] || die "نسخه '$version' پیدا نشد."

  curl -fsSL "$version_url" \
    | grep -o '"server":{"sha1":"[^"]*","size":[0-9]*,"url":"[^"]*"' \
    | grep -o 'https://[^"]*'
}

# ---------- تشخیص نسخه Java موردنیاز ----------
java_version_for_mc() {
  local mc_version="$1"
  local major minor
  major=$(echo "$mc_version" | cut -d. -f1)
  minor=$(echo "$mc_version" | cut -d. -f2 2>/dev/null || echo 0)

  if [[ "$mc_version" == 1.* ]]; then
    if   [ "$minor" -ge 20 ]; then echo 21
    elif [ "$minor" -ge 18 ]; then echo 17
    elif [ "$minor" -ge 17 ]; then echo 16
    else echo 8
    fi
  else
    echo 21
  fi
}

# ---------- بکاپ world ----------
backup_world() {
  if [ -d "world" ]; then
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    local out="world-backup-${ts}.tar.gz"
    log "در حال بکاپ world → $out"
    tar -czf "$out" world
    ok "بکاپ گرفته شد: $out"
  fi
}

# ---------- ساخت start.sh ----------
write_start_script() {
  local ram="$1"
  local jar="${2:-server.jar}"

  if [ "$ram" -ge 12288 ]; then
    # Aikar flags برای سرورهای بزرگ
    cat > start.sh <<EOF
#!/usr/bin/env bash
java -Xms${ram}M -Xmx${ram}M \\
  -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \\
  -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC \\
  -XX:+AlwaysPreTouch -XX:G1NewSizePercent=40 -XX:G1MaxNewSizePercent=50 \\
  -XX:G1HeapRegionSize=16M -XX:G1ReservePercent=20 \\
  -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 \\
  -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 \\
  -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 \\
  -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 \\
  -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true \\
  -jar ${jar} nogui
EOF
  else
    cat > start.sh <<EOF
#!/usr/bin/env bash
java -Xms${ram}M -Xmx${ram}M \\
  -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \\
  -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC \\
  -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 \\
  -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 \\
  -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 \\
  -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 \\
  -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 \\
  -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 \\
  -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true \\
  -jar ${jar} nogui
EOF
  fi
  chmod +x start.sh
  ok "start.sh ساخته شد."
}

# ---------- ساخت server.properties ----------
write_server_properties() {
  [ -f server.properties ] && { warn "server.properties موجود است؛ دست نزدم."; return; }
  cat > server.properties <<'EOF'
motd=§aMinecraft Server §7| §ePowered by script-run-server-minecraft
server-port=25565
max-players=20
online-mode=true
difficulty=normal
gamemode=survival
pvp=true
enable-command-block=false
view-distance=10
simulation-distance=8
spawn-protection=0
allow-flight=false
white-list=false
enforce-whitelist=false
EOF
  ok "server.properties ساخته شد."
}

# ---------- EULA ----------
accept_eula() {
  if [ ! -f eula.txt ]; then
    echo "eula=true" > eula.txt
    ok "eula.txt ساخته شد."
  fi
}

# ---------- دریافت نسخه از کاربر ----------
parse_common_args() {
  RAM="${MC_RAM:-}"
  MC_VERSION="${MC_VERSION:-latest}"
  DRY_RUN=0

  while [ $# -gt 0 ]; do
    case "$1" in
      -r|--ram)     RAM="$2"; shift 2 ;;
      -v|--version) MC_VERSION="$2"; shift 2 ;;
      -d|--dry-run) DRY_RUN=1; shift ;;
      -h|--help)    usage; exit 0 ;;
      *) die "پارامتر ناشناخته: $1 (برای راهنما: -h)" ;;
    esac
  done

  if [ -z "$RAM" ]; then
    read -rp "چند مگابایت RAM اختصاص دهیم؟ [پیشفرض 2048]: " RAM
    RAM="${RAM:-2048}"
  fi
  RAM=$(validate_ram "$RAM")

  if [ "$MC_VERSION" = "latest" ]; then
    MC_VERSION=$(get_latest_mc_version)
  fi

  log "RAM: ${RAM}MB | نسخه: $MC_VERSION | dry-run: $DRY_RUN"
}

# ---------- ساخت systemd service ----------
install_systemd_service() {
  local user="$1" workdir="$2"
  local svc=/etc/systemd/system/minecraft.service
  log "ساخت سرویس systemd..."
  sudo tee "$svc" >/dev/null <<EOF
[Unit]
Description=Minecraft Server
After=network.target

[Service]
Type=simple
User=${user}
WorkingDirectory=${workdir}
ExecStart=${workdir}/start.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable minecraft.service
  ok "سرویس systemd نصب شد (اجرا: sudo systemctl start minecraft)"
}
