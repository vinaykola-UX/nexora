@echo off
setlocal
cd /d "%~dp0"

echo ============================================================
echo   Starting Nexora AI — Intelligent Academic Web Assistant
echo   Host: http://localhost:3000
echo ============================================================

:: Check if port 3000 is already active
netstat -ano | findstr :3000 >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [Info] Server is already active on http://localhost:3000
) else (
    echo [Info] Starting background HTTP server on port 3000...
    start /b python -m http.server 3000 --directory "%~dp0"
    timeout /t 2 /nobreak >nul
)

echo [Info] Launching Nexora AI at http://localhost:3000 ...
start http://localhost:3000

echo [Ready] Nexora AI is running on http://localhost:3000
