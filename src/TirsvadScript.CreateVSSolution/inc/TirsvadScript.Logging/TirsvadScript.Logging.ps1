# Guard: this file is intended to be dot-sourced (included) by the main script.
# If executed directly, warn but continue so tests and other runspaces that dot-source still get the definitions.
if ($MyInvocation.InvocationName -ne '.') {
 Write-Host "This script is a library and is intended to be dot-sourced (e.g. `. .\Create-VSSolution.ps1`). Continuing anyway." -ForegroundColor Yellow
}

# Mark that logging was loaded in a global helper object. Be defensive: the global may not exist or may be a primitive.
$existingVar = Get-Variable -Name TirsvadScript -Scope Global -ErrorAction SilentlyContinue
if ($null -eq $existingVar) {
 # Create a PSCustomObject container to hold markers
 $global:TirsvadScript = [PSCustomObject]@{ LoggingLoaded = $true }
}
else {
 $container = $existingVar.Value
 if ($container -is [System.Collections.Hashtable]) {
 $container['LoggingLoaded'] = $true
 }
 elseif ($container -is [System.Management.Automation.PSCustomObject]) {
 # Add or update property
 if ($container.PSObject.Properties.Match('LoggingLoaded').Count -eq0) {
 $container | Add-Member -NotePropertyName LoggingLoaded -NotePropertyValue $true
 }
 else {
 $container.LoggingLoaded = $true
 }
 }
 else {
 # Primitive or other type: preserve original value under 'OriginalValue' and replace global with a hashtable
 $global:TirsvadScript = @{ OriginalValue = $container; LoggingLoaded = $true }
 }
}

# Ensure a reasonable default verbosity when the caller hasn't set one.
# When this file is dot-sourced it runs in the caller's script scope, so
# checking for a script-scoped variable lets callers pre-set it (test expects that).
if (-not (Get-Variable -Name VerboseMode -Scope Script -ErrorAction SilentlyContinue)) {
 $script:VerboseMode =2
}

# Write helpers respect numeric verbosity:0 = silent,1 = errors/warnings only,2 = errors+warnings+ok+info,3+ = debug
function Write-Info { if ($script:VerboseMode -ge2) { Write-Host "[INFO] " -ForegroundColor Cyan -NoNewline; Write-Host " $args" } }
function Write-Ok { if ($script:VerboseMode -ge2) { Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host " $args" } }
function Write-Err { if ($script:VerboseMode -ge1) { Write-Host "[ERR] " -ForegroundColor Red -NoNewline; Write-Host " $args" } }
function Write-Warn { if ($script:VerboseMode -ge1) { Write-Host "[WARN] " -ForegroundColor Magenta -NoNewline; Write-Host " $args" } }
function Write-Debug { if ($script:VerboseMode -ge3) { Write-Host "[DEBUG] " -ForegroundColor Yellow -NoNewline; Write-Host " $args" } }
function Write-Run { if ($script:VerboseMode -ge2) { Write-Host "[RUN] " -ForegroundColor DarkGray -NoNewline; Write-Host " $args" } }

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
    if ($script:VerboseMode -ge 2) {

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
        [string]$Message,
        [array]$SubMessages = @()
    )

    if ($script:VerboseMode -lt 1) { return }

    # Determine maximum content width (consider submessages)
    $maxLength =0
    if ($Message) { $maxLength = $Message.Length }
    foreach ($subMsg in $SubMessages) {
        if ($subMsg.Length -gt $maxLength) { $maxLength = $subMsg.Length }
    }

    # Add extra whitespace padding around the message for visual separation
    $innerWidth = $maxLength +4 # two spaces on each side when centered

    # Build top/bottom rule length: '===' + ' ' + inner + ' ' + '===' -> innerWidth +8
    $ruleLength = $innerWidth +8
    $line = '=' * $ruleLength
    Write-Host $line -ForegroundColor DarkCyan

    # Center the main message within the inner width
    if ($Message) {
        $leftPadding = [int](([double]($innerWidth - $Message.Length) /2.0) + $Message.Length)
        if ($leftPadding -lt $Message.Length) { $leftPadding = $Message.Length }
        $centered = $Message.PadLeft($leftPadding).PadRight($innerWidth)
        Write-Host "=== " -NoNewline -ForegroundColor DarkCyan
        Write-Host "$centered" -NoNewline -ForegroundColor white
        Write-Host " ===" -ForegroundColor DarkCyan
    }

    # Optionally print sub-messages centered as well
    if ($SubMessages -and $SubMessages.Count -gt0) {
        foreach ($sub in $SubMessages) {
            $leftPadding = [int](([double]($innerWidth - $sub.Length) /2.0) + $sub.Length)
            if ($leftPadding -lt $sub.Length) { $leftPadding = $sub.Length }
            $centeredSub = $sub.PadLeft($leftPadding).PadRight($innerWidth)
            Write-Host "=== $centeredSub ===" -ForegroundColor DarkCyan
        }
    }

    Write-Host $line -ForegroundColor DarkCyan
}