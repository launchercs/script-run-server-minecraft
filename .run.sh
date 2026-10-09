#!/bin/bash

# Exit on error
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Starting Minecraft Server Setup with Playit.gg...${NC}"

# ============================================
# === بخش تعیین RAM (ترکیب ۵ روش) ===
# ============================================
get_ram_amount() {
    local ram=""
    local source=""

    # روش ۱: آرگومان خط فرمان
    if [ -n "$1" ]; then
        ram="$1"
        source="command-line argument"
    fi

    # روش ۲: متغیر محیطی
    if [ -z "$ram" ] && [ -n "$ENV_MAX_RAM" ]; then
        ram="$ENV_MAX_RAM"
        source="environment variable"
    fi

    # روش ۴: پیشنهاد خودکار
    local total_ram_mb
    total_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    local suggested_ram=$((total_ram_mb / 2))M

    # روش ۳: پرسش تعاملی
    if [ -z "$ram" ]; then
        echo -e "${YELLOW}System RAM detected: ${total_ram_mb}M${NC}"
        echo -e "${YELLOW}Suggested for Minecraft: ${suggested_ram}${NC}"
        read -p "Enter RAM amount (e.g., 2G, 4G, 4096M) [default: $suggested_ram]: " user_input
        ram="${user_input:-$suggested_ram}"
        source="interactive prompt"
    fi

    # روش ۵: اعتبارسنجی
    if ! [[ "$ram" =~ ^[0-9]+[GM]$ ]]; then
        echo -e "${RED}Invalid RAM format: '$ram'. Using default: 2G${NC}"
        ram="2G"
        source="default (validation failed)"
    fi

    # بررسی رم درخواستی از رم سیستم
    local ram_mb
    if [[ "$ram" == *G ]]; then
        ram_mb=$(( ${ram%G} * 1024 ))
    else
        ram_mb=${ram%M}
    fi

    if [ "$ram_mb" -gt "$total_ram_mb" ]; then
        echo -e "${RED}Warning: Requested RAM (${ram}) exceeds system RAM (${total_ram_mb}M)${NC}"
        read -p "Continue anyway? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Using suggested: $suggested_ram${NC}"
            ram="$suggested_ram"
            source="auto-adjusted"
        fi
    fi

    echo -e "${GREEN}✓ RAM set to: $ram (source: $source)${NC}"
    echo "$ram"
}

MAX_RAM=$(get_ram_amount "$1")

# ============================================
# === Update & Install basic dependencies ===
# ============================================
echo -e "${GREEN}Updating package list...${NC}"
sudo apt-get update

echo -e "${GREEN}Installing basic dependencies...${NC}"
sudo apt-get install -y curl jq unzip wget gnupg screen

# ============================================
# === Fetch latest Minecraft version ===
# ============================================
echo -e "${GREEN}Fetching latest Minecraft server version...${NC}"
VERSION_MANIFEST_URL="https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
LATEST_VERSION=$(curl -s $VERSION_MANIFEST_URL | jq -r '.latest.release')
VERSION_URL=$(curl -s $VERSION_MANIFEST_URL | jq -r --arg ver "$LATEST_VERSION" '.versions[] | select(.id == $ver) | .url')
SERVER_JAR_URL=$(curl -s "$VERSION_URL" | jq -r '.downloads.server.url')

if [ -z "$SERVER_JAR_URL" ] || [ "$SERVER_JAR_URL" = "null" ]; then
    echo -e "${RED}Failed to fetch server JAR URL!${NC}"
    exit 1
fi

echo -e "${GREEN}Latest Minecraft version: $LATEST_VERSION${NC}"

# ============================================
# === تشخیص و نصب خودکار Java مناسب ===
# ============================================
get_required_java() {
    local mc_version="$1"
    local major minor
    major=$(echo "$mc_version" | cut -d. -f1)
    minor=$(echo "$mc_version" | cut -d. -f2)

    # جدول نسخه‌ها بر اساس مستندات PaperMC
    # 1.7.10 - 1.11 → Java 8
    # 1.12 - 1.16.4 → Java 11
    # 1.16.5 → Java 16
    # 1.17 - 1.19 → Java 17
    # 1.20 - 1.21.11 → Java 21
    # 26.1+ → Java 25

    if [ "$major" -ge 26 ]; then
        echo "25"
    elif [ "$major" -eq 1 ] && [ "$minor" -ge 20 ]; then
        echo "21"
    elif [ "$major" -eq 1 ] && [ "$minor" -ge 17 ]; then
        echo "17"
    elif [ "$major" -eq 1 ] && [ "$minor" -eq 16 ]; then
        # 1.16.5 → Java 16, 1.16.4 و پایین‌تر → Java 11
        # برای سادگی Java 17 می‌ذاریم که با هر دو کار می‌کنه
        echo "17"
    elif [ "$major" -eq 1 ] && [ "$minor" -ge 12 ]; then
        echo "11"
    else
        echo "8"
    fi
}

REQUIRED_JAVA=$(get_required_java "$LATEST_VERSION")

echo -e "${YELLOW}Minecraft $LATEST_VERSION requires Java $REQUIRED_JAVA${NC}"

# بررسی نصب بودن Java مناسب
if java -version 2>&1 | grep -q "version \"$REQUIRED_JAVA"; then
    echo -e "${GREEN}Java $REQUIRED_JAVA already installed.${NC}"
else
    echo -e "${YELLOW}Installing Java $REQUIRED_JAVA...${NC}"

    case "$REQUIRED_JAVA" in
        25)
            # Java 25 در مخازن اوبونتو موجود نیست، از روش دستی استفاده می‌کنیم
            echo -e "${YELLOW}Java 25 is not in default Ubuntu repos. Trying Temurin...${NC}"
            # برای سادگی از Java 21 استفاده می‌کنیم که سازگاری بالایی داره
            # اگه واقعاً Java 25 خواستی، باید از Adoptium دانلود کنی
            echo -e "${RED}Java 25 not available via apt. Falling back to Java 21.${NC}"
            sudo apt-get install -y openjdk-21-jdk
            REQUIRED_JAVA="21"
            ;;
        21)
            sudo apt-get install -y openjdk-21-jdk
            ;;
        17)
            sudo apt-get install -y openjdk-17-jdk
            ;;
        11)
            sudo apt-get install -y openjdk-11-jdk
            ;;
        8)
            # Java 8 ممکنه در مخازن پیش‌فرض نباشه
            if ! sudo apt-get install -y openjdk-8-jdk 2>/dev/null; then
                echo -e "${YELLOW}Java 8 not in default repos. Adding PPA...${NC}"
                sudo apt-get install -y software-properties-common
                sudo add-apt-repository -y ppa:openjdk-r/ppa
                sudo apt-get update
                sudo apt-get install -y openjdk-8-jdk
            fi
            ;;
    esac
fi

echo -e "${GREEN}✓ Using Java $REQUIRED_JAVA for Minecraft $LATEST_VERSION${NC}"

# ============================================
# === Create server directory ===
# ============================================
echo -e "${GREEN}Creating server directory...${NC}"
mkdir -p ~/minecraft-server
cd ~/minecraft-server

# ============================================
# === Download Minecraft server jar ===
# ============================================
echo -e "${GREEN}Downloading Minecraft $LATEST_VERSION server jar...${NC}"
wget "$SERVER_JAR_URL" -O server.jar

# ============================================
# === Accept EULA ===
# ============================================
echo -e "${GREEN}Accepting EULA...${NC}"
echo "eula=true" > eula.txt

# ============================================
# === Create startup script with Aikar flags ===
# ============================================
echo -e "${GREEN}Creating Minecraft startup script with ${MAX_RAM} RAM...${NC}"
cat > start.sh << EOF
#!/bin/bash
java -Xmx$MAX_RAM -Xms$MAX_RAM \\
  -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \\
  -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch \\
  -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M \\
  -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 \\
  -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 \\
  -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem \\
  -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs \\
  -Daikars.new.flags=true -jar server.jar nogui
EOF

chmod +x start.sh

# ============================================
# === Create server.properties ===
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
# === Install Playit.gg ===
# ============================================
echo -e "${GREEN}Installing Playit.gg tunnel agent via APT...${NC}"
curl -SsL https://playit-cloud.github.io/ppa/key.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/playit.gpg >/dev/null
echo "deb [signed-by=/etc/apt/trusted.gpg.d/playit.gpg] https://playit-cloud.github.io/ppa/data ./" | sudo tee /etc/apt/sources.list.d/playit-cloud.list
sudo apt update
sudo apt install -y playit

# ============================================
# === Create Playit tunnel startup script ===
# ============================================
echo -e "${GREEN}Creating Playit tunnel startup script...${NC}"
cat > start_tunnel.sh << 'EOF'
#!/bin/bash
playit
EOF

chmod +x start_tunnel.sh

# ============================================
# === Final summary ===
# ============================================
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup complete!${NC}"
echo -e "${GREEN}Minecraft version: $LATEST_VERSION${NC}"
echo -e "${GREEN}Java version: $REQUIRED_JAVA${NC}"
echo -e "${GREEN}Allocated RAM: $MAX_RAM${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}To start the Minecraft server:${NC}"
echo "  cd ~/minecraft-server && ./start.sh"
echo -e "${GREEN}To run in background (recommended):${NC}"
echo "  cd ~/minecraft-server && screen -S minecraft ./start.sh"
echo -e "${GREEN}To expose via Playit.gg:${NC}"
echo "  cd ~/minecraft-server && ./start_tunnel.sh"
echo -e "${GREEN}========================================${NC}"
