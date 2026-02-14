@echo off
title MT5 Data Feed Launcher
color 0A

:: ================= CONFIGURATION =================
set "PYTHON_EXE=E:\Quantitative trading model\Trading\Scripts\python.exe"
set "SCRIPT_PATH=%~dp0feed_replay.py"
:: =================================================

echo [Launcher] Starting Data Feed...
echo [Launcher] Python: "%PYTHON_EXE%"
echo [Launcher] Script: "%SCRIPT_PATH%"
echo.

:: Directly run the command with quotes
"%PYTHON_EXE%" "%SCRIPT_PATH%"
