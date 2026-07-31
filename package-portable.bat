@echo off
echo ========================================
echo   PM3 GUI 便携式打包
echo ========================================

set RELEASE_DIR=src-tauri\target\release
set OUTPUT_DIR=portable

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo 复制可执行文件...
copy "%RELEASE_DIR%\pm3gui-tauri.exe" "%OUTPUT_DIR%\PM3GUI.exe" >nul

echo 创建启动脚本...
(
echo @echo off
echo cd /d "%%~dp0"
echo start "" "PM3GUI.exe"
) > "%OUTPUT_DIR%\启动PM3GUI.bat"

echo 创建说明文件...
(
echo PM3 GUI - Proxmark3 图形界面 v0.1.0
echo =======================================
echo.
echo 便携式版本，无需安装。
echo.
echo 使用方法：
echo   1. 双击 "启动PM3GUI.bat" 或直接运行 "PM3GUI.exe"
echo   2. 在连接页面设置 PM3 client 目录路径
echo   3. 选择串口并连接
echo.
echo 系统要求：
echo   - Windows 10 21H2+ 或 Windows 11
echo   - 需要 WebView2 运行时（Win10/11 通常已内置）
echo.
echo PM3 客户端目录应包含：
echo   - proxmark3.exe
echo   - pm3 脚本
echo   - libs/shell/bash.exe（Windows）
echo   - dictionaries/
echo   - resources/
) > "%OUTPUT_DIR%\README.txt"

echo.
echo ========================================
echo 打包完成！
echo 文件位置: %OUTPUT_DIR%\
echo ========================================
dir "%OUTPUT_DIR%"
