:: Script: `.\NConvert-Batch.Bat`

:: Initialization
@echo off
setlocal enabledelayedexpansion
title ERASE_ALL_DATA
color 80
echo Initialization Complete.
timeout /t 1 >nul

:: Skip past headers and function definitions
goto :main_logic

:: Function to print a header
:printHeader
echo ========================================================================================================================
echo    %~1
echo ========================================================================================================================
goto :eof

:: Function to print a separator
:printSeparator
echo ========================================================================================================================
goto :eof

:: Main Logic
:main_logic
:: DP0 TO SCRIPT BLOCK, DO NOT, MODIFY or MOVE: START
set "ScriptDirectory=%~dp0"
set "ScriptDirectory=%ScriptDirectory:~0,-1%"
cd /d "%ScriptDirectory%"
echo Dp0'd to Script.
:: DP0 TO SCRIPT BLOCK, DO NOT, MODIFY or MOVE: END

:: CHECK ADMIN BLOCK, DO NOT, MODIFY or MOVE: START
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Error: Admin Required!
    timeout /t 2 >nul
    echo Right Click, Run As Administrator.
    timeout /t 2 >nul
    goto :end_of_script
)
echo Status: Administrator
timeout /t 1 >nul
:: CHECK ADMIN BLOCK, DO NOT, MODIFY or MOVE: END

:: Main Code Begin
cls
call :printHeader "ERASE_ALL_DATA"
echo.

:: Run Powershell script
powershell.exe -ExecutionPolicy Bypass -File ERASE_ALL_DATA.ps1

:end_of_file
cls  :: do not remove line
call :printHeader "Exit ERASE_ALL_DATA"
echo.
timeout /t 1 >nul
echo Exiting ERASE_ALL_DATA
timeout /t 1 >nul
echo All processes finished.
timeout /t 1 >nul
exit /b