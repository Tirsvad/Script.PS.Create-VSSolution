# Guard: this file is intended to be dot-sourced (included) by the main script.
# If executed directly, warn and exit to avoid unintended behavior.
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "This script is a library and must be dot-sourced from the main script (e.g. `. .\Create-VSSolution.ps1`). Exiting." -ForegroundColor Yellow
    exit 1
}

# Write helpers respect numeric verbosity:0 = silent,1 = errors/warnings only,2 = errors+warnings+ok+info,3+ = debug
function Write-Info { if ($VerboseMode -ge 2) { Write-Host "[INFO]  " -ForegroundColor Cyan -NoNewline; Write-Host " $args" } }
function Write-Ok { if ($VerboseMode -ge 2) { Write-Host "[OK]    " -ForegroundColor Green -NoNewline; Write-Host " $args" } }
function Write-Err { if ($VerboseMode -ge 1) { Write-Host "[ERR]   " -ForegroundColor Red -NoNewline; Write-Host " $args" } }
function Write-Warn { if ($VerboseMode -ge 1) { Write-Host "[WARN]  " -ForegroundColor Magenta -NoNewline; Write-Host " $args" } }
function Write-Debug { if ($VerboseMode -ge 3) { Write-Host "[DEBUG] " -ForegroundColor Yellow -NoNewline; Write-Host " $args" } }
function Write-Run { if ($VerboseMode -ge 1) { Write-Host "[RUN]   " -ForegroundColor DarkGray -NoNewline; Write-Host " $args" } }
function Write-RunDone {
    param (
        [bool]$Success = $true
    )
    if ($Success) {
        $msg = 'DONE'
        $msgColor = 'DarkGray'
    }
    else {
        $msg = 'FAIL'
        $msgColor = 'Red'
    }
    if ($VerboseMode -ge1) {

        try {
            $raw = $Host.UI.RawUI
            $pos = $raw.CursorPosition
            if ($pos.Y -gt 0) {
                # Move cursor to the start of the previous line
                $up = New-Object System.Management.Automation.Host.Coordinates(0, ($pos.Y -1))
                $raw.CursorPosition = $up
                # Overwrite the [RUN] marker
                Write-Host "[$msg] " -ForegroundColor $msgColor -NoNewline
                # Restore cursor to the original line start so the rest of the message prints on the next line
                $raw.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, $pos.Y)
            }
            else {
                Write-Host "[$msg] " -ForegroundColor $msgColor -NoNewline
            }
        }
        catch {
            # Host doesn't support RawUI; just print $msg marker
            #Write-Host "[$msg] " -ForegroundColor $msgColor -NoNewline
        }

        #Write-Host " $args"
    }
}
function Write-Header {
    param (
        [string]$Message
    )
    $line = "=" * ($Message.Length + 8)
    Write-Host $line -ForegroundColor DarkCyan
    Write-Host "=== $Message ===" -ForegroundColor DarkCyan
    Write-Host $line -ForegroundColor DarkCyan
}