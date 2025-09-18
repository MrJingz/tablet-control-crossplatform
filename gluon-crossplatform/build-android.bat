@echo off
setlocal enabledelayedexpansion

echo ===============================================
echo    飞象中控系统 - Android APK 构建脚本
echo ===============================================

:: 设置颜色输出
for /f %%A in ('"prompt $H &echo on &for %%B in (1) do rem"') do set BS=%%A

:: 检查Java环境
echo [1/8] 检查Java环境...
java -version >nul 2>&1
if errorlevel 1 (
    echo %BS%[91m错误: 未找到Java环境，请安装JDK 8或更高版本%BS%[0m
    pause
    exit /b 1
)

:: 检查Maven环境
echo [2/8] 检查Maven环境...
mvn -version >nul 2>&1
if errorlevel 1 (
    echo %BS%[91m错误: 未找到Maven，请安装Apache Maven%BS%[0m
    pause
    exit /b 1
)

:: 检查Android SDK
echo [3/8] 检查Android SDK环境...
if "%ANDROID_HOME%"=="" (
    echo %BS%[93m警告: ANDROID_HOME环境变量未设置%BS%[0m
    echo 尝试自动检测Android SDK...
    
    :: 常见的Android SDK路径
    set "SDK_PATHS=%LOCALAPPDATA%\Android\Sdk;C:\Android\Sdk;%USERPROFILE%\AppData\Local\Android\Sdk"
    
    for %%P in (%SDK_PATHS%) do (
        if exist "%%P\platform-tools\adb.exe" (
            set "ANDROID_HOME=%%P"
            echo 找到Android SDK: !ANDROID_HOME!
            goto :sdk_found
        )
    )
    
    echo %BS%[91m错误: 未找到Android SDK，请设置ANDROID_HOME环境变量%BS%[0m
    echo 或安装Android Studio并配置SDK
    pause
    exit /b 1
)

:sdk_found
echo Android SDK路径: %ANDROID_HOME%

:: 检查Android NDK
echo [4/8] 检查Android NDK环境...
if "%ANDROID_NDK_HOME%"=="" (
    echo 尝试自动检测Android NDK...
    
    :: 在SDK目录下查找NDK
    for /d %%D in ("%ANDROID_HOME%\ndk\*") do (
        set "ANDROID_NDK_HOME=%%D"
        echo 找到Android NDK: !ANDROID_NDK_HOME!
        goto :ndk_found
    )
    
    echo %BS%[93m警告: 未找到Android NDK，可能影响构建%BS%[0m
    echo 建议通过Android Studio安装NDK
)

:ndk_found
if not "%ANDROID_NDK_HOME%"=="" (
    echo Android NDK路径: %ANDROID_NDK_HOME%
)

:: 清理之前的构建
echo [5/8] 清理之前的构建...
if exist "target" (
    rmdir /s /q target
    echo 清理target目录完成
)

:: 编译项目
echo [6/8] 编译项目源代码...
echo 执行: mvn clean compile
mvn clean compile
if errorlevel 1 (
    echo %BS%[91m错误: 项目编译失败%BS%[0m
    pause
    exit /b 1
)

echo %BS%[92m项目编译成功%BS%[0m

:: 构建Android APK
echo [7/8] 构建Android APK...
echo 执行: mvn gluonfx:build -Pandroid

:: 设置构建参数
set "MAVEN_OPTS=-Xmx2g -XX:MaxPermSize=512m"

:: 开始构建
mvn gluonfx:build -Pandroid -Dverbose=true
if errorlevel 1 (
    echo %BS%[91m错误: Android APK构建失败%BS%[0m
    echo.
    echo 可能的解决方案:
    echo 1. 检查Android SDK和NDK是否正确安装
    echo 2. 确保ANDROID_HOME和ANDROID_NDK_HOME环境变量正确设置
    echo 3. 检查网络连接，确保可以下载依赖
    echo 4. 查看上面的错误信息进行具体排查
    echo.
    pause
    exit /b 1
)

:: 查找生成的APK文件
echo [8/8] 查找生成的APK文件...

set "APK_FOUND=false"
set "APK_PATH="

:: 可能的APK路径
set "APK_PATHS=target\gluonfx\aarch64-android\TabletControl.apk;target\gluonfx\x86_64-android\TabletControl.apk;target\gluonfx\arm-android\TabletControl.apk"

for %%P in (%APK_PATHS%) do (
    if exist "%%P" (
        set "APK_FOUND=true"
        set "APK_PATH=%%P"
        goto :apk_found
    )
)

:: 搜索所有可能的APK文件
for /r "target" %%F in (*.apk) do (
    set "APK_FOUND=true"
    set "APK_PATH=%%F"
    goto :apk_found
)

:apk_found
if "%APK_FOUND%"=="true" (
    echo %BS%[92m===============================================%BS%[0m
    echo %BS%[92m          Android APK 构建成功！%BS%[0m
    echo %BS%[92m===============================================%BS%[0m
    echo.
    echo APK文件位置: %APK_PATH%
    
    :: 获取APK文件信息
    for %%A in ("%APK_PATH%") do (
        echo 文件大小: %%~zA 字节
        echo 修改时间: %%~tA
    )
    
    echo.
    echo %BS%[96m下一步操作:%BS%[0m
    echo 1. 将APK文件传输到Android设备
    echo 2. 在设备上启用"未知来源"安装
    echo 3. 安装并测试应用
    echo.
    
    :: 询问是否打开APK所在目录
    set /p "OPEN_DIR=是否打开APK所在目录? (y/n): "
    if /i "!OPEN_DIR!"=="y" (
        for %%A in ("%APK_PATH%") do (
            explorer "%%~dpA"
        )
    )
    
    :: 询问是否启动ADB安装
    set /p "INSTALL_ADB=是否通过ADB安装到连接的设备? (y/n): "
    if /i "!INSTALL_ADB!"=="y" (
        call :install_via_adb "%APK_PATH%"
    )
    
) else (
    echo %BS%[91m错误: 未找到生成的APK文件%BS%[0m
    echo 请检查构建日志中的错误信息
)

echo.
echo 构建脚本执行完成
pause
exit /b 0

:: ADB安装函数
:install_via_adb
set "APK_FILE=%~1"

echo.
echo 通过ADB安装APK...

:: 检查ADB是否可用
"%ANDROID_HOME%\platform-tools\adb.exe" version >nul 2>&1
if errorlevel 1 (
    echo %BS%[91m错误: ADB不可用%BS%[0m
    goto :eof
)

:: 检查设备连接
echo 检查设备连接...
"%ANDROID_HOME%\platform-tools\adb.exe" devices
"%ANDROID_HOME%\platform-tools\adb.exe" get-state >nul 2>&1
if errorlevel 1 (
    echo %BS%[93m警告: 未检测到连接的设备%BS%[0m
    echo 请确保:
    echo 1. 设备已连接并启用USB调试
    echo 2. 已安装设备驱动程序
    echo 3. 设备已授权此计算机进行调试
    goto :eof
)

:: 安装APK
echo 正在安装APK到设备...
"%ANDROID_HOME%\platform-tools\adb.exe" install -r "%APK_FILE%"
if errorlevel 1 (
    echo %BS%[91m安装失败%BS%[0m
) else (
    echo %BS%[92m安装成功！%BS%[0m
    echo 可以在设备上找到"飞象中控系统"应用
)

goto :eof
