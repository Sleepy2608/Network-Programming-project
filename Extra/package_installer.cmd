@echo off
setlocal enabledelayedexpansion
title SinChat - Build Installer (jpackage)
color 0A

echo ============================================================
echo          SINCHAT CLIENT - BUILD INSTALLER (jpackage)
echo ============================================================
echo.
echo [!] Yeu cau: JDK 25 + JavaFX 25 jmods
echo.

:: ========== CAU HINH ==========
set "APP_NAME=SinChat"
set "APP_VERSION=1.0"
set "APP_VENDOR=SinChatTeam"
set "MAIN_CLASS=com.client.Launcher"
set "JAVA_VERSION=25"

:: Thu muc goc cua du an
cd /d "%~dp0..\Code\Client"
set "PROJECT_DIR=%CD%"
set "EXTRA_DIR=%~dp0"

:: ========== BUOC 0: Tim jpackage ==========
echo Tim jpackage.exe...
set "JPACKAGE="

:: Cach 1: Kiem tra JAVA_HOME
if defined JAVA_HOME (
    if exist "!JAVA_HOME!\bin\jpackage.exe" (
        set "JPACKAGE=!JAVA_HOME!\bin\jpackage.exe"
    )
)

:: Cach 2: Su dung java de tim java.home
if "!JPACKAGE!"=="" (
    for /f "tokens=2 delims== " %%a in ('java -XshowSettings:properties -version 2^>^&1 ^| findstr "java.home"') do (
        set "JAVA_HOME_DETECTED=%%a"
    )
    if defined JAVA_HOME_DETECTED (
        if exist "!JAVA_HOME_DETECTED!\bin\jpackage.exe" (
            set "JPACKAGE=!JAVA_HOME_DETECTED!\bin\jpackage.exe"
        )
    )
)

:: Cach 3: Do tim trong C:\Program Files\Java\
if "!JPACKAGE!"=="" (
    for /d %%d in ("C:\Program Files\Java\jdk-*") do (
        if exist "%%d\bin\jpackage.exe" (
            set "JPACKAGE=%%d\bin\jpackage.exe"
        )
    )
)

if "!JPACKAGE!"=="" (
    color 0C
    echo [LOI] Khong tim thay jpackage.exe!
    echo Vui long dat JAVA_HOME tro den thu muc JDK 25+.
    echo Hoac them thu muc bin cua JDK vao PATH.
    pause
    exit /b 1
)
echo [OK] jpackage: !JPACKAGE!
echo.
echo ============================================================
echo   BAT DAU DONG GOI SINCHAT INSTALLER
echo ============================================================
echo.

:: ========== BUOC 1: Build fat JAR ==========
echo [1/4] Dang build fat JAR bang Maven...
call mvn clean package -q
if %ERRORLEVEL% NEQ 0 (
    color 0C
    echo [LOI] Build that bai! Kiem tra lai Maven va pom.xml.
    pause
    exit /b 1
)
echo [OK] Build thanh cong.

:: Kiem tra JAR da duoc tao chua
set "JAR_FILE=%PROJECT_DIR%\target\sinchat-client.jar"
if not exist "!JAR_FILE!" (
    :: Fallback: tim file jar trong target
    for %%f in ("%PROJECT_DIR%\target\*.jar") do set "JAR_FILE=%%f"
)
if not exist "!JAR_FILE!" (
    color 0C
    echo [LOI] Khong tim thay file JAR trong target/
    pause
    exit /b 1
)
echo [OK] JAR: !JAR_FILE!

:: ========== BUOC 2: Kiem tra JavaFX jmods ==========
echo.
echo [2/4] Kiem tra JavaFX jmods...

:: Thu tim jmods trong thu muc Extra hoac thu muc download mac dinh
set "JMODS_DIR="

:: Kiem tra Extra/lib/javafx-jmods-25.0.3 (vi tri mac dinh)
if exist "%EXTRA_DIR%lib\javafx-jmods-25.0.3\javafx.controls.jmod" (
    set "JMODS_DIR=%EXTRA_DIR%lib\javafx-jmods-25.0.3"
)
:: Kiem tra Extra/javafx-jmods-25 (vi tri cu)
if "!JMODS_DIR!"=="" (
    if exist "%EXTRA_DIR%javafx-jmods-25\javafx.controls.jmod" (
        set "JMODS_DIR=%EXTRA_DIR%javafx-jmods-25"
    )
)
:: Kiem tra C:\Program Files\Java\javafx-jmods-25
if "!JMODS_DIR!"=="" (
    if exist "C:\Program Files\Java\javafx-jmods-25\javafx.controls.jmod" (
        set "JMODS_DIR=C:\Program Files\Java\javafx-jmods-25"
    )
)

if "!JMODS_DIR!"=="" (
    echo.
    echo ============================================================
    echo [CAN THIEP] Khong tim thay JavaFX jmods!
    echo.
    echo Ban can tai JavaFX %JAVA_VERSION% jmods tu:
    echo   https://gluonhq.com/products/javafx/
    echo.
    echo Chon: "JavaFX Windows jmods" -> tai file zip
    echo Giai nen vao thu muc:
    echo   %EXTRA_DIR%lib\javafx-jmods-25.0.3
    echo.
    echo Sau do chay lai script nay.
    echo ============================================================
    pause
    exit /b 1
)
echo [OK] JavaFX jmods: !JMODS_DIR!

:: ========== BUOC 3: Tao installer ==========
echo.
echo [3/4] Dang tao installer bang jpackage...

set "OUTPUT_DIR=%PROJECT_DIR%\target\installer"

:: Xoa installer cu neu co
if exist "!OUTPUT_DIR!" rmdir /s /q "!OUTPUT_DIR!"

:: Kiem tra icon
set "ICON_PATH=%EXTRA_DIR%app-icon.ico"
set "ICON_ARG="
if exist "!ICON_PATH!" (
    set "ICON_ARG=--icon !ICON_PATH!"
    echo [OK] Icon: !ICON_PATH!
) else (
    echo [!] Chua co icon app-icon.ico trong Extra/, se bo qua icon.
)

:: Kiem tra WiX (can de tao .exe/.msi)
set "PACKAGE_TYPE=app-image"
set "WIX_FOUND="
set "WIN_OPTS="

:: Them cac thu muc WiX vao PATH de tim
set "WIX_PATH_3=%SystemDrive%\Program Files (x86)\WiX Toolset v3.14\bin"
set "WIX_PATH_4=%SystemDrive%\Program Files\WiX Toolset v4\bin"
if exist "!WIX_PATH_3!\light.exe" set "PATH=!PATH!;!WIX_PATH_3!"
if exist "!WIX_PATH_4!\wix.exe"    set "PATH=!PATH!;!WIX_PATH_4!"

:: Kiem tra WiX 3 (light.exe + candle.exe)
where light >nul 2>&1 && where candle >nul 2>&1
if !ERRORLEVEL! EQU 0 set "WIX_FOUND=WiX3"

:: Kiem tra WiX 4/5 (wix.exe)
if not defined WIX_FOUND (
    where wix >nul 2>&1
    if !ERRORLEVEL! EQU 0 set "WIX_FOUND=WiX4"
)

if defined WIX_FOUND (
    set "PACKAGE_TYPE=exe"
    set "WIN_OPTS=--win-dir-chooser --win-menu --win-shortcut"
    echo [OK] WiX tim thay, tao installer .exe
) else (
    echo [!] WiX khong co, tao app-image ^(thu muc ung dung^)
    echo     Cai WiX de tao .exe: https://wixtoolset.org/
    echo     Hoac nen thu muc output thanh .zip de phan phoi.
)

:: Railway server config for packaged app
set "RAILWAY_HOST=acela.proxy.rlwy.net"
set "RAILWAY_PORT=45139"
echo [Mode] Packaged app will connect to Railway: %RAILWAY_HOST%:%RAILWAY_PORT%

:: Chay jpackage
echo Dang chay jpackage (type: !PACKAGE_TYPE!)...
"!JPACKAGE!" ^
    --name "%APP_NAME%" ^
    --input "%PROJECT_DIR%\target" ^
    --main-jar "sinchat-client.jar" ^
    --main-class "%MAIN_CLASS%" ^
    --type "!PACKAGE_TYPE!" ^
    --dest "!OUTPUT_DIR!" ^
    --app-version "%APP_VERSION%" ^
    --vendor "%APP_VENDOR%" ^
    --java-options "-Dtcp.host=%RAILWAY_HOST%" ^
    --java-options "-Dtcp.port=%RAILWAY_PORT%" ^
    --add-modules javafx.controls,javafx.swing ^
    --module-path "!JMODS_DIR!" ^
    !WIN_OPTS! ^
    !ICON_ARG!

if %ERRORLEVEL% NEQ 0 (
    color 0C
    echo.
    echo [LOI] jpackage that bai!
    echo Kiem tra lai JDK phien ban (can JDK %JAVA_VERSION%+) 
    echo va JavaFX jmods dung phien ban.
    pause
    exit /b 1
)

:: ========== BUOC 4: Ket qua ==========
echo.
echo [4/4] Hoan thanh!
echo ============================================================
echo   INSTALLER DA DUOC TAO THANH CONG!
echo.
echo   Thu muc chua installer:
echo     !OUTPUT_DIR!
echo.
dir "!OUTPUT_DIR!" /b 2>nul
echo.
echo   Gui file .exe trong thu muc tren cho nguoi dung.
echo   Nguoi dung chi can chay file exe de cai dat SinChat.
echo ============================================================

:: Mo thu muc installer
explorer "!OUTPUT_DIR!"

pause
endlocal
