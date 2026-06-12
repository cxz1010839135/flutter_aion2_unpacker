@echo off
chcp 65001 >nul
title AION2 解包工具 - 一键打包 Windows EXE
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_windows.ps1" %*
echo.
pause
