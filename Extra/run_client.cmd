@echo off
title SinChat Client Launcher
color 0A
echo ===================================================
echo             STARTING SINCHAT TCP CLIENT            
echo ===================================================
echo.

:: Navigate to Client directory
cd /d "%~dp0..\Code\Client"

echo [1/2] Cleaning and Compiling Client code...
call mvn clean compile -q
if %ERRORLEVEL% NEQ 0 (
    color 0C
    echo.
    echo ===================================================
    echo [ERROR] Client compilation failed!
    echo        Make sure Maven ^(mvn^) is installed and in PATH.
    echo ===================================================
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/2] Launching JavaFX Client...
echo ===================================================
:: Auto-detect PORT from server .env, fallback to 3000
if not defined TCP_PORT (
    set "TCP_PORT=3000"
    if exist "%~dp0..\Code\Server\.env" (
        for /f "tokens=2 delims==" %%a in ('findstr /b "PORT=" "%~dp0..\Code\Server\.env" 2^>nul') do set "TCP_PORT=%%a"
    )
)
if not defined TCP_HOST set "TCP_HOST=127.0.0.1"

echo [Mode] Connect to %TCP_HOST%:%TCP_PORT% (default)
echo        Set TCP_HOST / TCP_PORT env vars to override.
echo.
call mvn javafx:run
if %ERRORLEVEL% NEQ 0 (
    color 0C
    echo.
    echo [ERROR] Client stopped with an error code.
    pause
)
exit /b 0
