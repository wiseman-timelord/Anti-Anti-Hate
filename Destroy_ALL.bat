@echo off
setlocal enabledelayedexpansion
title ERASE_ALL_DATA
color 80

:: ===== IMPROVED DP0 HANDLING =====
:: (Removed redundant string manipulation)
pushd "%~dp0" || exit /b 1
echo Script directory: %CD%

:: ===== STREAMLINED ADMIN CHECK =====
:: (Faster failure path with timestamp)
net session >nul 2>&1 || (
    echo [%time%] ERROR: Admin privileges required
    echo [%time%] Right-click -> "Run as administrator"
    timeout /t 3 >nul
    exit /b 1
)
echo [%time%] Admin confirmed

:: ===== ENHANCED WARNING PHASE =====
:: (More visible warning with color)
cls
echo ========================================================================
echo                          ERASE_ALL_DATA
echo ========================================================================
echo.
<nul set /p "=WARNING: " & color C0
echo This will PERMANENTLY DESTROY ALL DATA ON ALL DRIVES!
echo.
color 80
timeout /t 5 /nobreak >nul  && echo.

:: ===== OPTIMIZED POWERSHELL LAUNCH =====
:: (Added error handling and priority boost)
start "" /high /wait powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "Destory_ALL.ps1"

:: ===== EMERGENCY EXIT =====
:: (Added error logging just in case)
if %errorlevel% neq 0 (
    echo [%time%] WARNING: Execution failed with error %errorlevel%
    pause
)
popd
exit /b