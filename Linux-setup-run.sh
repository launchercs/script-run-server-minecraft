#!/usr/bin/env bash
# ============================================================
#  Minecraft Server Setup with Playit.gg  (Linux, multi-distro)
#  Usage:  ./setup.sh [RAM] [-y] [-u]
#    RAM   : 2G | 4G | 4096M ... (default: half of system RAM)
#    -y    : non-interactive (auto-accept)
#    -u    : update mode (only refresh server.jar, keep world)
# ============================================================
set -euo pipefail

# ---------- colors ----------
if [ -t 1 ]; then
    GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'
    BLUE=$'\033[0;34m';  NC=$'\033[0m'
else
    GREEN=''; YELLOW=''; RED=''; BLUE=''; NC=''
fi
log()  { echo -e "${GREEN}[+]${NC} $*"; }
info() { echo -e "${BLUE}[i]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*" >&2; }
err()  { echo -e "${RED}[x]${NC} $*" >&2; }
die()  { err "$*"; exit 1; }

# ---------- config ----------
MC_DIR="${MC_DIR:-$HOME/minecraft-server}"
BACKUP_DIR="${BACKUP_DIR:-$MC_DIR/backups}"
JAVA_BASE_DIR="${JAVA_BASE_DIR:-$HOME/.local/java}"
ASSUME_YES=0
UPDATE_ONLY=0
RAM_ARG=""

# ---------- args ----------
while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes)    ASSUME_YES=1 ;;
        -u|--update) UPDATE_ONLY=1 ;;
        -h|--help)
            sed -n '2,9p' "$0"; exit 0 ;;
        -*) die "Unknown option: $1" ;;
        *)  RAM_ARG="$1" ;;
    esac
    shift
done

# ---------- sudo detection ----------
SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
fi

# ============================================================
#  Package manager abstraction
# ============================================================
detect_pm() {
    for pm in apt-get dnf pacman zypper apk; do
        command -v "$pm" >/dev/null 2>&1 && { echo "$pm"; return; }
    done
    die "No supported package manager found"
}
PM="$(detect_pm)"
info "Package manager: $PM"

pkg_update() {
    case "$PM" in
        apt-get) $SUDO apt-get update -y ;;
        dnf)     $SUDO dnf check-update -y || true ;;
        pacman)  $SUDO pacman -Sy --noconfirm ;;
        zypper)  $SUDO zypper refresh ;;
        apk)     $SUDO apk update ;;
    esac
}

pkg_install() {
    case "$PM" in
        apt-get) $SUDO apt-get install -y "$@" ;;
        dnf)     $SUDO dnf install -y "$@" ;;
        pacman)  $SUDO pacman -S --noconfirm --needed "$@" ;;
        zypper)  $SUDO zypper install -y "$@" ;;
        apk)     $SUDO apk add "$@" ;;
    esac
}

# ============================================================
#  RAM determination
# ============================================================
get_ram_amount() {
    local ram="" source=""

    [ -n "$RAM_ARG" ]           && { ram="$RAM_ARG"; source="command-line argument"; }
    [ -z "$ram" ] && [ -n "${ENV_MAX_RAM:-}" ] && { ram="$ENV_MAX_RAM"; source="environment variable"; }

    local total_ram_mb
    total_ram_mb=$(awk '/^MemTotal:/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    [[ "$total_ram_mb" =~ ^[0-9]+$ ]] && [ "$total_ram_mb" -gt 0 ] || total_ram_mb=2048

    local suggested=$(( total_ram_mb / 2 ))M

    if [ -z "$ram" ]; then
        echo -e "${YELLOW}System RAM: ${total_ram_mb}M — suggested: ${suggested}${NC}" >&2
        if [ "$ASSUME_YES" -eq 1 ]; then
            ram="$suggested"; source="auto (--yes)"
        else
            local user_input=""
            read -rp "RAM amount (e.g. 2G / 4G / 4096M) [default: $suggested]: " user_input || true
            ram="${user_input:-$suggested}"
            source="interactive prompt"
        fi
    fi

    ram=$(printf '%s' "$ram" | tr '[:lower:]' '[:upper:]')
    if ! [[ "$ram" =~ ^[0-9]+[GM]$ ]]; then
        warn "Invalid RAM format '$ram' → using 2G"
        ram="2G"; source="default (validation failed)"
    fi

    local ram_mb
    if [[ "$ram" == *G ]]; then ram_mb=$(( ${ram%G} * 1024 )); else ram_mb=${ram%M}; fi

    if [ "$ram_mb" -gt "$total_ram_mb" ]; then
        warn "Requested ${ram} > system RAM (${total_ram_mb}M)"
        if [ "$ASSUME_YES" -eq 0 ]; then
            local c=""; read -rp "Continue anyway? (y/N): " c || true
            if [[ ! "$c" =~ ^[Yy]$ ]]; then
                ram="$suggested"; source="auto-adjusted"
            fi
        fi
    fi

    log "RAM → $ram ($source)" >&2
    printf '%s\n' "$ram"
}

# ============================================================
#  Adoptium (Temurin) JDK installer — cross-distro, includes Java 25
# ============================================================
install_adoptium_jdk() {
    local feature="$1"
    local arch
    case "$(uname -m)" in
        x86_64|amd64)  arch="x64"     ;;
        aarch64|arm64) arch="aarch64" ;;
        armv7l|armhf)  arch="arm"     ;;
        *) die "Unsupported architecture: $(uname -m)" ;;
    esac

    local dest="$JAVA_BASE_DIR/jdk-$feature"
    if [ -x "$dest/bin/java" ]; then
        info "Java $feature already present at $dest" >&2
        echo "$dest/bin/java"; return
    fi

    mkdir -p "$JAVA_BASE_DIR"
    local url="https://api.adoptium.net/v3/binary/latest/${feature}/ga/linux/${arch}/jdk/hotspot/normal/eclipse"
    local tmp="$JAVA_BASE_DIR/jdk-${feature}.tar.gz"

    log "Downloading Temurin JDK $feature ($arch)..." >&2
    curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 -o "$tmp" "$url" \
        || die "Failed to download JDK $feature"

    mkdir -p "$dest"
    tar -xzf "$tmp" -C "$dest" --strip-components=1
    rm -f "$tmp"

    [ -x "$dest/bin/java" ] || die "JDK extraction failed"
    echo "$dest/bin/java"
}

# ============================================================
#  Aikar flags — two presets
# ============================================================
aikar_flags() {
    local ram="$1"
    local ram_mb
    if [[ "$ram" == *G ]]; then ram_mb=$(( ${ram%G} * 1024 )); else ram_mb=${ram%M}; fi

    local base=(
        "-XX:+UseG1GC" "-XX:+ParallelRefProcEnabled" "-XX:MaxGCPauseMillis=200"
        "-XX:+UnlockExperimentalVMOptions" "-XX:+DisableExplicitGC" "-XX:+AlwaysPreTouch"
        "-XX:G1HeapWastePercent=5" "-XX:G1MixedGCCountTarget=4"
        "-XX:G1MixedGCLiveThresholdPercent=90" "-XX:G1RSetUpdatingPauseTimePercent=5"
        "-XX:SurvivorRatio=32" "-XX:+PerfDisableSharedMem" "-XX:MaxTenuringThreshold=1"
        "-Dusing.aikars.flags=https://mcflags.emc.gs" "-Daikars.new.flags=true"
    )

    if [ "$ram_mb" -ge 12288 ]; then
        base+=( "-XX:G1NewSizePercent=40" "-XX:G1MaxNewSizePercent=50"
                "-XX:G1HeapRegionSize=16M" "-XX:G1ReservePercent=15"
                "-XX:InitiatingHeapOccupancyPercent=20" )
    else
        base+=( "-XX:G1NewSizePercent=30" "-XX:G1MaxNewSizePercent=40"
                "-XX:G1HeapRegionSize=8M" "-XX:G1ReservePercent=20"
                "-XX:InitiatingHeapOccupancyPercent=15" )
    fi
    printf '%s\n' "${base[*]}"
}

# ============================================================
#  Minecraft version helpers
# ============================================================
fetch_latest_mc() {
    local manifest="https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
    local ver url
    ver=$(curl -fsSL --retry 3 --connect-timeout 15 "$manifest" | jq -r '.latest.release')
    [ -n "$ver" ] && [ "$ver" != "null" ] || die "Cannot fetch latest MC version"

    url=$(curl -fsSL --retry 3 "$manifest" \
        | jq -r --arg v "$ver" '.versions[] | select(.id==$v) | .url')
    [ -n "$url" ] && [ "$url" != "null" ] || die "Cannot resolve manifest for $ver"

    local jar
    jar=$(curl -fsSL --retry 3 "$url" | jq -r '.downloads.server.url')
    [ -n "$jar" ] && [ "$jar" != "null" ] || die "Cannot resolve server jar URL"

    printf '%s\n%s\n' "$ver" "$jar"
}

required_java() {
    local v="$1" major minor
    major=${v%%.*}; minor=$(echo "$v" | cut -d. -f2)
    [[ "$major" =~ ^[0-9]+$ ]] && [[ "$minor" =~ ^[0-9]+$ ]] || { echo 21; return; }

    if   [ "$major" -ge 26 ]; then echo 25
    elif [ "$major" -eq 1 ] && [ "$minor" -ge 20 ]; then echo 21
    elif [ "$major" -eq 1 ] && [ "$minor" -ge 17 ]; then echo 17
    elif [ "$major" -eq 1 ] && [ "$minor" -eq 16 ]; then echo 17
    elif [ "$major" -eq 1 ] && [ "$minor" -ge 12 ]; then echo 11
    else echo 8; fi
}

# ============================================================
#  World backup
# ============================================================
backup_world() {
    [ -d "$MC_DIR/world" ] || return 0
    mkdir -p "$BACKUP_DIR"
    local ts file
    ts=$(date +%Y%m%d-%H%M%S)
    file="$BACKUP_DIR/world-$ts.tar.gz"
    log "Backing up world → $file"
    tar -czf "$file" -C "$MC_DIR" world
}

# ============================================================
#  systemd service
# ============================================================
create_systemd_service() {
    command -v systemctl >/dev/null 2>&1 || { warn "systemd not available"; return 1; }
    [ -n "$SUDO" ] || [ "$(id -u)" -eq 0 ] || { warn "sudo required for systemd"; return 1; }
    [ "$ASSUME_YES" -eq 0 ] || true

    if [ "$ASSUME_YES" -eq 0 ]; then
        local ans=""
        read -rp "Install as systemd service (auto-start on boot)? (y/N): " ans || true
        [[ "$ans" =~ ^[Yy]$ ]] || return 1
    fi

    local unit="/etc/systemd/system/minecraft.service"
    $SUDO tee "$unit" >/dev/null <<EOF
[Unit]
Description=Minecraft Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$MC_DIR
ExecStart=$MC_DIR/start.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable minecraft.service
    log "systemd service installed: minecraft.service"
}

# ============================================================
#  MAIN
# ============================================================
log "Minecraft Server Setup — $(date)"

# --- 1. RAM ---
MAX_RAM=$(get_ram_amount)

# --- 2. Install system deps ---
log "Installing base dependencies..."
pkg_update
DEPS=(curl wget jq tar)
case "$PM" in
    apt-get) DEPS+=(unzip gnupg screen) ;;
    dnf)     DEPS+=(unzip gnupg2 screen) ;;
    pacman)  DEPS+=(unzip gnupg screen) ;;
    zypper)  DEPS+=(unzip gpg2 screen) ;;
    apk)     DEPS+=(unzip gnupg screen) ;;
esac
pkg_install "${DEPS[@]}"

# --- 3. Latest MC version ---
log "Fetching latest Minecraft version..."
mapfile -t MC_INFO < <(fetch_latest_mc)
LATEST_VERSION="${MC_INFO[0]}"
SERVER_JAR_URL="${MC_INFO[1]}"
log "Latest version: $LATEST_VERSION"

# --- 4. Java ---
REQUIRED_JAVA=$(required_java "$LATEST_VERSION")
log "Minecraft $LATEST_VERSION requires Java $REQUIRED_JAVA"

JAVA_BIN=$(install_adoptium_jdk "$REQUIRED_JAVA")
log "Java binary: $JAVA_BIN"
"$JAVA_BIN" -version 2>&1 | head -n1 | sed 's/^/    /'

# --- 5. Server directory ---
mkdir -p "$MC_DIR"
cd "$MC_DIR"

EXISTING=0
[ -f "$MC_DIR/server.jar" ] && EXISTING=1

# --- 6. Backup if existing ---
if [ "$EXISTING" -eq 1 ]; then
    info "Existing server detected at $MC_DIR"
    backup_world
fi

# --- 7. Download / update server jar ---
DO_DOWNLOAD=1
if [ "$EXISTING" -eq 1 ] && [ "$UPDATE_ONLY" -eq 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
    ans=""
    read -rp "Download server.jar for $LATEST_VERSION (overwrite)? (Y/n): " ans || true
    [[ "$ans" =~ ^[Nn]$ ]] && DO_DOWNLOAD=0
fi

if [ "$DO_DOWNLOAD" -eq 1 ]; then
    log "Downloading server.jar ($LATEST_VERSION)..."
    wget -q --show-progress --tries=3 --timeout=30 "$SERVER_JAR_URL" -O server.jar.tmp
    mv server.jar.tmp server.jar
else
    info "Keeping existing server.jar"
fi

# --- 8. EULA (only create if missing) ---
[ -f eula.txt ] || { echo "eula=true" > eula.txt; log "eula.txt created"; }
grep -q '^eula=true' eula.txt || { echo "eula=true" > eula.txt; log "eula.txt set to true"; }

# --- 9. start.sh ---
log "Writing start.sh (RAM=$MAX_RAM)..."
AIKAR=$(aikar_flags "$MAX_RAM")
cat > start.sh <<EOF
#!/usr/bin/env bash
cd "\$(dirname "\$0")"
exec "$JAVA_BIN" -Xms$MAX_RAM -Xmx$MAX_RAM \\
  $AIKAR \\
  -jar server.jar nogui
EOF
chmod +x start.sh

# --- 10. server.properties (only if missing) ---
if [ ! -f server.properties ]; then
    log "Creating server.properties"
    cat > server.properties <<'EOF'
server-port=25565
max-players=20
view-distance=10
simulation-distance=10
gamemode=survival
difficulty=normal
pvp=true
spawn-protection=16
online-mode=true
white-list=false
enable-command-block=false
motd=Welcome to Minecraft Server!
EOF
else
    info "Keeping existing server.properties"
fi

# --- 11. Playit.gg (idempotent) ---
if command -v playit >/dev/null 2>&1; then
    info "playit already installed"
else
    log "Installing Playit.gg..."
    case "$PM" in
        apt-get)
            curl -fsSL --retry 3 https://playit-cloud.github.io/ppa/key.gpg \
                | gpg --dearmor \
                | $SUDO tee /etc/apt/trusted.gpg.d/playit.gpg >/dev/null
            echo "deb [signed-by=/etc/apt/trusted.gpg.d/playit.gpg] https://playit-cloud.github.io/ppa/data ./" \
                | $SUDO tee /etc/apt/sources.list.d/playit-cloud.list >/dev/null
            $SUDO apt-get update -y
            $SUDO apt-get install -y playit
            ;;
        *)
            warn "Playit.gg APT repo only available on apt-based systems."
            warn "Download manually: https://playit.gg/download"
            ;;
    esac
fi

cat > start_tunnel.sh <<'EOF'
#!/usr/bin/env bash
exec playit
EOF
chmod +x start_tunnel.sh

# --- 12. systemd ---
create_systemd_service || true

# ============================================================
#  Summary
# ============================================================
echo
log "==================================================="
log "Setup complete!"
log "  Minecraft : $LATEST_VERSION"
log "  Java      : $REQUIRED_JAVA ($JAVA_BIN)"
log "  RAM       : $MAX_RAM"
log "  Directory : $MC_DIR"
log "  Backups   : $BACKUP_DIR"
log "==================================================="
echo
info "Start (foreground):    cd $MC_DIR && ./start.sh"
info "Start (background):    cd $MC_DIR && screen -dmS mc ./start.sh"
info "Attach:                screen -r mc"
info "Tunnel (Playit.gg):    cd $MC_DIR && ./start_tunnel.sh"
if command -v systemctl >/dev/null 2>&1; then
    info "Or via systemd:        sudo systemctl start minecraft"
fi
