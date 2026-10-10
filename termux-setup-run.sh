
#!/data/data/com.termux/files/usr/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Starting Minecraft Server Setup with Playit.gg (Termux)...${NC}"

# ============================================
# === RAM determination (5 combined methods) ===
# ============================================
get_ram_amount() {
    local ram=""
    local source=""

    # Method 1: CLI arg
    if [ -n "$1" ]; then
        ram="$1"
        source="command-line argument"
    fi

    # Method 2: env var
    if [ -z "$ram" ] && [ -n "$ENV_MAX_RAM" ]; then
        ram="$ENV_MAX_RAM"
        source="environment variable"
    fi

    # Detect total system RAM (Android/Termux compatible)
    local total_ram_mb
    total_ram_mb=$(cat /proc/meminfo | grep MemTotal | awk '{print int($2/1024)}')
    if ! [[ "$total_ram_mb" =~ ^[0-9]+$ ]] || [ "$total_ram_mb" -le 0 ]; then
        total_ram_mb=2048
    fi

    local suggested_ram=$((total_ram_mb / 2))M

    # Method 3: interactive prompt
    if [ -z "$ram" ]; then
        echo -e "${YELLOW}System RAM detected: ${total_ram_mb}M${NC}" >&2
        echo -e "${YELLOW}Suggested for Minecraft: ${suggested_ram}${NC}" >&2
        local user_input=""
        read -p "Enter RAM amount (e.g., 2G, 4G, 4096M) [default: $suggested_ram]: " user_input || true
        ram="${user_input:-$suggested_ram}"
        source="interactive prompt"
    fi

    # Method 5: normalize + validation
    ram=$(printf '%s' "$ram" | tr '[:lower:]' '[:upper:]')

    if ! [[ "$ram" =~ ^[0-9]+[GM]$ ]]; then
        echo -e "${RED}Invalid RAM format: '$ram'. Using default: 2G${NC}" >&2
        ram="2G"
        source="default (validation failed)"
    fi

    # Cross-check against system RAM
    local ram_mb
    if [[ "$ram" == *G ]]; then
        ram_mb=$(( ${ram%G} * 1024 ))
    else
        ram_mb=${ram%M}
    fi

    if [ "$ram_mb" -gt "$total_ram_mb" ]; then
        echo -e "${RED}Warning: Requested RAM (${ram}) exceeds system RAM (${total_ram_mb}M)${NC}" >&2
        local confirm=""
        read -p "Continue anyway? (y/N): " confirm || true
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Using suggested: $suggested_ram${NC}" >&2
            ram="$suggested_ram"
            source="auto-adjusted"
        fi
    fi

    echo -e "${GREEN}✓ RAM set to: $ram (source: $source)${NC}" >&2
    printf '%s\n' "$ram"
}

MAX_RAM=$(get_ram_amount "$1")

# ============================================
# === Update & install dependencies (Termux) ===
# ============================================
echo -e "${GREEN}Updating Termux packages...${NC}"
pkg update -y && pkg upgrade -y

echo -e "${GREEN}Installing basic dependencies...${NC}"
pkg install -y curl jq unzip wget proot-distro

# ============================================
# === Install proot-distro (Debian) for Java ===
# ============================================
echo -e "${GREEN}Installing Debian via proot-distro...${NC}"
if ! proot-distro list | grep -q "debian"; then
    proot-distro install debian
else
    echo -e "${GREEN}Debian already installed.${NC}"
fi

# ============================================
# === Fetch latest Minecraft version ===
# ============================================
echo -e "${GREEN}Fetching latest Minecraft server version...${NC}"
VERSION_MANIFEST_URL="https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
LATEST_VERSION=$(curl -fsSL "$VERSION_MANIFEST_URL" | jq -r '.latest.release')

if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" = "null" ]; then
    echo -e "${RED}Failed to fetch latest Minecraft version!${NC}"
    exit 1
fi

VERSION_URL=$(curl -fsSL "$VERSION_MANIFEST_URL" \
    | jq -r --arg ver "$LATEST_VERSION" '.versions[] | select(.id == $ver) | .url')

if [ -z "$VERSION_URL" ] || [ "$VERSION_URL" = "null" ]; then
    echo -e "${RED}Failed to resolve version URL for $LATEST_VERSION!${NC}"
    exit 1
fi

SERVER_JAR_URL=$(curl -fsSL "$VERSION_URL" | jq -r '.downloads.server.url')

if [ -z "$SERVER_JAR_URL" ] || [ "$SERVER_JAR_URL" = "null" ]; then
    echo -e "${RED}Failed to fetch server JAR URL!${NC}"
    exit 1
fi

echo -e "${GREEN}Latest Minecraft version: $LATEST_VERSION${NC}"

# ============================================
# === Detect required Java version ===
# ============================================
get_required_java() {
    local mc_version="$1"
    local major minor
    major=$(echo "$mc_version" | cut -d. -f1)
    minor=$(echo "$mc_version" | cut -d. -f2)

    if ! [[ "$major" =~ ^[0-9]+$ ]] || ! [[ "$minor" =~ ^[0-9]+$ ]]; then
        echo "21"; return
    fi

    if [ "$major" -ge 26 ]; then
        echo "25"
    elif [ "$major" -eq 1 ] && [ "$minor" -ge 20 ]; then
        echo "21"
    elif [ "$major" -eq 1 ] && [ "$minor" -ge 17 ]; then
        echo "17"
    elif [ "$major" -eq 1 ] && [ "$minor" -eq 16 ]; then
        echo "17"
    elif [ "$major" -eq 1 ] && [ "$minor" -ge 12 ]; then
        echo "11"
    else
        echo "8"
    fi
}

REQUIRED_JAVA=$(get_required_java "$LATEST_VERSION")
echo -e "${YELLOW}Minecraft $LATEST_VERSION requires Java $REQUIRED_JAVA${NC}"

# ============================================
# === Install Java inside proot-distro ===
# ============================================
echo -e "${GREEN}Installing Java $REQUIRED_JAVA inside Debian proot...${NC}"

# Map required Java to Debian package name
case "$REQUIRED_JAVA" in
    25) DEB_JAVA_PKG="openjdk-25-jdk" ;;
    21) DEB_JAVA_PKG="openjdk-21-jdk" ;;
    17) DEB_JAVA_PKG="openjdk-17-jdk" ;;
    11) DEB_JAVA_PKG="openjdk-11-jdk" ;;
    8)  DEB_JAVA_PKG="openjdk-8-jdk" ;;
    *)  DEB_JAVA_PKG="openjdk-21-jdk" ;;
esac

proot-distro login debian -- bash -c "
    apt update && apt install -y $DEB_JAVA_PKG
    java -version
"

# ============================================
# === Server directory ===
# ============================================
SERVER_DIR="$HOME/minecraft-server"
echo -e "${GREEN}Creating server directory: $SERVER_DIR${NC}"
mkdir -p "$SERVER_DIR"
cd "$SERVER_DIR"

# ============================================
# === Download server jar ===
# ============================================
echo -e "${GREEN}Downloading Minecraft $LATEST_VERSION server jar...${NC}"
wget -q --show-progress "$SERVER_JAR_URL" -O server.jar

# ============================================
# === EULA ===
# ============================================
echo -e "${GREEN}Accepting EULA...${NC}"
echo "eula=true" > eula.txt

# ============================================
# === Startup script with Aikar flags ===
# ============================================
echo -e "${GREEN}Creating Minecraft startup script with ${MAX_RAM} RAM...${NC}"
cat > start.sh << EOF
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login debian -- bash -c "cd $SERVER_DIR && java -Xmx$MAX_RAM -Xms$MAX_RAM \\
  -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \\
  -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch \\
  -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M \\
  -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 \\
  -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 \\
  -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem \\
  -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs \\
  -Daikars.new.flags=true -jar server.jar nogui"
EOF
chmod +x start.sh

# ============================================
# === server.properties ===
# ============================================
echo -e "${GREEN}Creating server.properties...${NC}"
cat > server.properties << 'EOF'
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

# ============================================
# === Playit.gg (Build from source in Termux) ===
# ============================================
echo -e "${GREEN}Installing Playit.gg tunnel agent (compiling from source)...${NC}"

# Install Rust and Git if not present
pkg install -y rust git

# Clone and build playit-agent
if [ ! -d "$HOME/playit-agent" ]; then
    git clone https://github.com/playit-cloud/playit-agent.git "$HOME/playit-agent"
fi

cd "$HOME/playit-agent"
cargo build --release

# Symlink the binary for easy access
ln -sf "$HOME/playit-agent/target/release/playit" "$PREFIX/bin/playit" 2>/dev/null || \
    cp "$HOME/playit-agent/target/release/playit" "$PREFIX/bin/playit"
chmod +x "$PREFIX/bin/playit"

cd "$SERVER_DIR"

# ============================================
# === Tunnel script ===
# ============================================
echo -e "${GREEN}Creating Playit tunnel startup script...${NC}"
cat > start_tunnel.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
exec playit
EOF
chmod +x start_tunnel.sh

# ============================================
# === Summary ===
# ============================================
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup complete!${NC}"
echo -e "${GREEN}Minecraft version: $LATEST_VERSION${NC}"
echo -e "${GREEN}Java version: $REQUIRED_JAVA${NC}"
echo -e "${GREEN}Allocated RAM: $MAX_RAM${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}To start the Minecraft server:${NC}"
echo "  cd $SERVER_DIR && ./start.sh"
echo -e "${GREEN}To run in background (recommended):${NC}"
echo "  cd $SERVER_DIR && screen -dmS minecraft ./start.sh"
echo -e "${GREEN}To attach to it later:${NC}"
echo "  screen -r minecraft"
echo -e "${GREEN}To expose via Playit.gg:${NC}"
echo "  cd $SERVER_DIR && ./start_tunnel.sh"
echo -e "${GREEN}========================================${NC}"
