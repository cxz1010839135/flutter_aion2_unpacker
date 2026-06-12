@echo off
chcp 65001 >nul
title AION2 解包工具 - 一键安装 retoc / repak
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install_tools.ps1" %*
echo.
pause
