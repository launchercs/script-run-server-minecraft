@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title Minecraft Server Auto Setup

REM ---------- متغیرها ----------
set "RAM=%~1"
set "MC_VERSION=%~2"
if "%RAM%"=="" set "RAM=2048"
if "%MC_VERSION%"=="" set "MC_VERSION=latest"

echo ==========================================
echo   Minecraft Server Auto Setup (Windows)
echo ==========================================
echo.

REM ---------- بررسی winget ----------
where winget >nul 2>&1
if errorlevel 1 (
  echo [FAIL] winget نصب نیست. از Microsoft Store نصب کن: App Installer
  exit /b 1
)

REM ---------- بررسی Java ----------
where java >nul 2>&1
if errorlevel 1 (
  echo [INFO] نصب Java 21 (Temurin)...
  winget install --id EclipseAdoptium.Temurin.21.JDK -e --accept-source-agreements --accept-package-agreements
) else (
  echo [ OK ] Java از قبل نصب است.
)

REM ---------- بکاپ world ----------
if exist world (
  for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
  set ts=!datetime:~0,8!-!datetime:~8,6!
  echo [INFO] بکاپ world → world-backup-!ts!.zip
  powershell -Command "Compress-Archive -Path 'world' -DestinationPath 'world-backup-!ts!.zip' -Force"
)

REM ---------- دانلود server.jar (اصلاح شده) ----------
echo [INFO] دریافت آخرین نسخه از Mojang...
powershell -Command ^
  "$m = Invoke-RestMethod 'https://launchermeta.mojang.com/mc/game/version_manifest.json';" ^
  "$v = if ('%MC_VERSION%' -eq 'latest') { $m.latest.release } else { '%MC_VERSION%' };" ^
  "$vu = ($m.versions | Where-Object id -eq $v).url;" ^
  "$j = Invoke-RestMethod $vu;" ^
  "Invoke-WebRequest -Uri $j.downloads.server.url -OutFile 'server.jar';" ^
  "Write-Host '[ OK ] server.jar دانلود شد.'"

REM ---------- ساخت start.bat ----------
(
  echo @echo off
  echo setlocal enabledelayedexpansion
  echo title Minecraft Server
  echo java -Xms%RAM%M -Xmx%RAM%M -XX:+UseG1GC -XX:+ParallelRefProcEnabled -jar server.jar nogui
) > start.bat
echo [ OK ] start.bat ساخته شد.

REM ---------- server.properties ----------
if not exist server.properties (
  (
    echo motd=§aMinecraft Server §7^| §ePowered by script-run-server-minecraft
    echo server-port=25565
    echo max-players=20
    echo online-mode=true
    echo difficulty=normal
    echo gamemode=survival
    echo view-distance=10
    echo simulation-distance=8
  ) > server.properties
  echo [ OK ] server.properties ساخته شد.
)

REM ---------- EULA ----------
if not exist eula.txt (
  echo eula=true > eula.txt
  echo [ OK ] eula.txt ساخته شد.
)

REM ---------- پایان ----------
echo.
echo ==========================================
echo   🎉 راهاندازی کامل شد!
echo ==========================================
echo   اجرای سرور:  start.bat
echo   تنظیمات:     server.properties
echo.
pause
endlocal
