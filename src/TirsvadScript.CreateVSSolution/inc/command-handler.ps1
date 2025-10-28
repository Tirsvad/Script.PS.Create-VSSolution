# Guard: this file is intended to be dot-sourced (included) by the main script.
# If executed directly, warn and exit to avoid unintended behavior.
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "This script is a library and must be dot-sourced from the main script (e.g. `. .\Create-VSSolution.ps1`). Exiting." -ForegroundColor Yellow
    exit 1
}

function Run {
    param (
        [string]$cmd,
        [object]$second = $null
    )

    # If second argument provided, treat as executable path + args; otherwise treat first as a PowerShell command string
    if ($null -ne $second) {
        $argList = @()
        if ($second -is [System.Array]) { $argList = $second } else { $argList = @($second) }
            Write-Run "Running: $cmd $($argList -join ' ')"
        $proc = Start-Process -FilePath $cmd -ArgumentList $argList -Wait -PassThru -WindowStyle Hidden
    }
    else {
        Write-Run "Running: $cmd"
        $proc = Start-Process -FilePath "powershell" -ArgumentList @('-NoProfile', '-Command', $cmd) -Wait -PassThru -WindowStyle Hidden
    }
    if ($proc.ExitCode -ne 0) {
        Write-RunDone $false
        Write-Err "Process $cmd $($argList -join ' ') failed with exit code $($proc.ExitCode)"
    }
    else {
        Write-RunDone $true
    }
    return $proc.ExitCode
}