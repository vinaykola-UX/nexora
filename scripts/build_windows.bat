@echo off
setlocal enabledelayedexpansion

echo ===================================================================
echo     Nexora AI — Windows Desktop Application Release Builder
echo     BVC Engineering College Odalarevu
echo ===================================================================
echo.

:: 1. Verify Flutter CLI is available
where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Flutter SDK not found in system PATH.
    echo Please install Flutter and ensure 'flutter' is added to PATH.
    exit /b 1
)

echo [1/4] Ensuring Windows desktop target is enabled in Flutter...
call flutter config --enable-windows-desktop
if %ERRORLEVEL% neq 0 (
    echo [WARN] Could not run flutter config, continuing...
)

echo.
echo [2/4] Resolving dependencies (flutter pub get)...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [ERROR] flutter pub get failed.
    exit /b 1
)

echo.
echo [3/4] Building Windows Release Executable (flutter build windows --release)...
set CMAKE_POLICY_VERSION_MINIMUM=3.5
set CL=/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Windows release build failed.
    exit /b 1
)

echo.
echo [4/4] Packaging release distribution into dist\nexora-windows-v1.0.0...
set "SOURCE_DIR=build\windows\x64\runner\Release"
set "DEST_DIR=dist\nexora-windows-v1.0.0"

if exist "%SOURCE_DIR%" (
    if not exist "dist" mkdir "dist"
    if not exist "%DEST_DIR%" mkdir "%DEST_DIR%"
    xcopy /E /I /Y "%SOURCE_DIR%\*" "%DEST_DIR%\" >nul
    echo.
    echo ===================================================================
    echo [SUCCESS] Windows Release Build completed successfully!
    echo Location: %DEST_DIR%\nexora.exe
    echo You can now distribute this folder or zip it for students.
    echo ===================================================================
) else (
    echo [WARN] Build output directory not found at %SOURCE_DIR%.
)

endlocal
