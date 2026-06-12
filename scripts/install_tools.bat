@echo off
chcp 65001 >nul
title AION2 解包工具 - 依赖安装
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_tools.ps1" %*
echo.
pause
