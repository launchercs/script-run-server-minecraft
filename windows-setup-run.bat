# ============================================
# Minecraft Server Setup with Playit.gg - Windows (PowerShell)
# ============================================
$ErrorActionPreference = "Stop"

Write-Host "Starting Minecraft Server Setup with Playit.gg..." -ForegroundColor Green

# ============================================
# === RAM determination (5 combined methods) ===
# ============================================
function Get-RamAmount {
    param([string]$ArgRam)

    $ram = ""
    $source = ""

    # Method 1: CLI arg
    if ($ArgRam) {
        $ram = $ArgRam
        $source = "command-line argument"
    }

    # Method 2: env var
    if (-not $ram -and $env:ENV_MAX_RAM) {
        $ram = $env:ENV_MAX_RAM
        $source = "environment variable"
    }

    # Detect total system RAM
    $totalRamBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $totalRamMB = [math]::Round($totalRamBytes / 1MB)
    if ($totalRamMB -le 0) { $totalRamMB = 2048 }

    $suggestedRam = "$([math]::Round($totalRamMB / 2))M"

    # Method 3: interactive prompt
    if (-not $ram) {
        Write-Host "System RAM detected: ${totalRamMB}M" -ForegroundColor Yellow
        Write-Host "Suggested for Minecraft: ${suggestedRam}" -ForegroundColor Yellow
        $userInput = Read-Host "Enter RAM amount (e.g., 2G, 4G, 4096M) [default: $suggestedRam]"
        $ram = if ($userInput) { $userInput } else { $suggestedRam }
        $source = "interactive prompt"
    }

    # Method 5: normalize + validation
    $ram = $ram.ToUpper()

    if ($ram -notmatch '^[0-9]+[GM]$') {
        Write-Host "Invalid RAM format: '$ram'. Using default: 2G" -ForegroundColor Red
        $ram = "2G"
        $source = "default (validation failed)"
    }

    # Cross-check against system RAM
    if ($ram -match '^([0-9]+)G$') {
        $ramMB = [int]$Matches[1] * 1024
    } elseif ($ram -match '^([0-9]+)M$') {
        $ramMB = [int]$Matches[1]
    }

    if ($ramMB -gt $totalRamMB) {
        Write-Host "Warning: Requested RAM (${ram}) exceeds system RAM (${totalRamMB}M)" -ForegroundColor Red
        $confirm = Read-Host "Continue anyway? (y/N)"
        if ($confirm -notmatch '^[Yy]$') {
            Write-Host "Using suggested: $suggestedRam" -ForegroundColor Yellow
            $ram = $suggestedRam
            $source = "auto-adjusted"
        }
    }

    Write-Host "RAM set to: $ram (source: $source)" -ForegroundColor Green
    return $ram
}

# Get RAM from first argument or interactive
$MaxRam = Get-RamAmount -ArgRam $args[0]

# ============================================
# === Update & install dependencies ===
# ============================================
Write-Host "Installing basic dependencies via winget..." -ForegroundColor Green

# Check if winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget not found. Please install App Installer from Microsoft Store." -ForegroundColor Red
    exit 1
}

# Install required tools (git, jq, wget, unzip)
foreach ($pkg in @("Git.Git", "jqlang.jq", "GnuWin32.Wget", "GnuWin32.Unzip")) {
    Write-Host "Installing $pkg..." -ForegroundColor Yellow
    winget install --id $pkg --accept-package-agreements --accept-source-agreements --silent
}

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# ============================================
# === Fetch latest Minecraft version ===
# ============================================
Write-Host "Fetching latest Minecraft server version..." -ForegroundColor Green
$VersionManifestUrl = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
$manifest = Invoke-RestMethod -Uri $VersionManifestUrl
$LatestVersion = $manifest.latest.release

if (-not $LatestVersion) {
    Write-Host "Failed to fetch latest Minecraft version!" -ForegroundColor Red
    exit 1
}

$versionUrl = ($manifest.versions | Where-Object { $_.id -eq $LatestVersion }).url
if (-not $versionUrl) {
    Write-Host "Failed to resolve version URL for $LatestVersion!" -ForegroundColor Red
    exit 1
}

$versionData = Invoke-RestMethod -Uri $versionUrl
$ServerJarUrl = $versionData.downloads.server.url

if (-not $ServerJarUrl) {
    Write-Host "Failed to fetch server JAR URL!" -ForegroundColor Red
    exit 1
}

Write-Host "Latest Minecraft version: $LatestVersion" -ForegroundColor Green

# ============================================
# === Detect required Java version ===
# ============================================
function Get-RequiredJava {
    param([string]$McVersion)

    $parts = $McVersion -split '\.'
    $major = [int]$parts[0]
    $minor = [int]$parts[1]

    if ($major -ge 26) { return "25" }
    elseif ($major -eq 1 -and $minor -ge 20) { return "21" }
    elseif ($major -eq 1 -and $minor -ge 17) { return "17" }
    elseif ($major -eq 1 -and $minor -eq 16) { return "17" }
    elseif ($major -eq 1 -and $minor -ge 12) { return "11" }
    else { return "8" }
}

$RequiredJava = Get-RequiredJava -McVersion $LatestVersion
Write-Host "Minecraft $LatestVersion requires Java $RequiredJava" -ForegroundColor Yellow

# ============================================
# === Check installed Java ===
# ============================================
function Get-InstalledJavaMajor {
    try {
        $javaVersion = & java -version 2>&1 | Select-Object -First 1
        if ($javaVersion -match '"(\d+)') {
            $ver = $Matches[1]
            if ($ver -eq "1") {
                # Old format: 1.8.0_xxx
                if ($javaVersion -match '"1\.(\d+)') { return $Matches[1] }
            } else {
                return $ver
            }
        }
    } catch {}
    return $null
}

$InstalledJava = Get-InstalledJavaMajor

if ($InstalledJava -eq $RequiredJava) {
    Write-Host "Java $RequiredJava already installed." -ForegroundColor Green
} else {
    Write-Host "Installing Java $RequiredJava..." -ForegroundColor Yellow

    switch ($RequiredJava) {
        "25" {
            Write-Host "Java 25 not available via winget. Falling back to Java 21." -ForegroundColor Red
            winget install --id Microsoft.OpenJDK.21 --accept-package-agreements --accept-source-agreements --silent
            $RequiredJava = "21"
        }
        "21" { winget install --id Microsoft.OpenJDK.21 --accept-package-agreements --accept-source-agreements --silent }
        "17" { winget install --id Microsoft.OpenJDK.17 --accept-package-agreements --accept-source-agreements --silent }
        "11" { winget install --id Microsoft.OpenJDK.11 --accept-package-agreements --accept-source-agreements --silent }
        "8"  { winget install --id EclipseAdoptium.Temurin.8.JDK --accept-package-agreements --accept-source-agreements --silent }
    }

    # Refresh PATH again after Java install
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

Write-Host "Using Java $RequiredJava for Minecraft $LatestVersion" -ForegroundColor Green

# ============================================
# === Server directory ===
# ============================================
$ServerDir = Join-Path $env:USERPROFILE "minecraft-server"
Write-Host "Creating server directory: $ServerDir" -ForegroundColor Green
New-Item -ItemType Directory -Force -Path $ServerDir | Out-Null
Set-Location $ServerDir

# ============================================
# === Download server jar ===
# ============================================
Write-Host "Downloading Minecraft $LatestVersion server jar..." -ForegroundColor Green
Invoke-WebRequest -Uri $ServerJarUrl -OutFile "server.jar"

# ============================================
# === EULA ===
# ============================================
Write-Host "Accepting EULA..." -ForegroundColor Green
"eula=true" | Out-File -FilePath "eula.txt" -Encoding ASCII

# ============================================
# === Startup script with Aikar flags ===
# ============================================
Write-Host "Creating Minecraft startup script with ${MaxRam} RAM..." -ForegroundColor Green
$startScript = @"
@echo off
java -Xmx$MaxRam -Xms$MaxRam ^
  -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 ^
  -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch ^
  -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M ^
  -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 ^
  -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 ^
  -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem ^
  -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs ^
  -Daikars.new.flags=true -jar server.jar nogui
"@
$startScript | Out-File -FilePath "start.bat" -Encoding ASCII

# ============================================
# === server.properties ===
# ============================================
Write-Host "Creating server.properties..." -ForegroundColor Green
$serverProps = @"
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
"@
$serverProps | Out-File -FilePath "server.properties" -Encoding ASCII

# ============================================
# === Playit.gg ===
# ============================================
Write-Host "Installing Playit.gg tunnel agent via winget..." -ForegroundColor Green
winget install --id DevelopedMethods.playit --accept-package-agreements --accept-source-agreements --silent

# ============================================
# === Tunnel script ===
# ============================================
Write-Host "Creating Playit tunnel startup script..." -ForegroundColor Green
$tunnelScript = @"
@echo off
playit
"@
$tunnelScript | Out-File -FilePath "start_tunnel.bat" -Encoding ASCII

# ============================================
# === Summary ===
# ============================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "Minecraft version: $LatestVersion" -ForegroundColor Green
Write-Host "Java version: $RequiredJava" -ForegroundColor Green
Write-Host "Allocated RAM: $MaxRam" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "To start the Minecraft server:" -ForegroundColor Green
Write-Host "  cd $ServerDir; .\start.bat"
Write-Host "To expose via Playit.gg:" -ForegroundColor Green
Write-Host "  cd $ServerDir; .\start_tunnel.bat"
Write-Host "========================================" -ForegroundColor Green
