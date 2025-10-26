<# 
.SYNOPSIS 
    Install Create-VSSolution.ps1 so it can be run globally from the command line or as a module.
.DESCRIPTION 
    Copies Create-VSSolution.ps1 to a user scripts folder, optionally adds that folder to the user PATH, creates a small PowerShell profile wrapper, installs the script as a simple module, or removes installed artifacts. Designed for interactive use; respects -Force to overwrite without prompting.

.PARAMETER InstallPath 
    Destination folder for the script and shim. Defaults to %USERPROFILE%\Scripts.

.PARAMETER AddToPath 
    Add InstallPath to the user's PATH environment variable so the script or its shim can be invoked from any shell.

.PARAMETER CreateProfileFunction 
    Add a small Create-VSSolution wrapper function to the user's PowerShell profile to call the installed script.

.PARAMETER DeleteProfileFunction 
    Remove the Create-VSSolution wrapper from the user's PowerShell profile.

.PARAMETER Delete 
    Remove installed script, shim, module, profile wrapper and user PATH entry (cleanup mode).

.PARAMETER AsModule 
    Install Create-VSSolution.ps1 as a simple module under Documents\PowerShell\Modules\Create-VSSolution.

.PARAMETER Force 
    Overwrite existing files and manifest entries without prompting.

.EXAMPLE To add script path to user PATH:
    .\install.ps1 -AddToPath

.EXAMPLE To create a profile wrapper function:
    .\install.ps1 -CreateProfileFunction -InstallPath C:\Tools\Scripts
    Installs the script to C:\Tools\Scripts and creates a profile wrapper function.

.EXAMPLE To install as a module:
    .\install.ps1 -AsModule -Force
    Installs the script as a module, overwriting any existing module files without prompt.

.NOTES 
    After adding InstallPath to the user's PATH or modifying your PowerShell profile, restart shells to pick up changes.
    This installer expects Create-VSSolution.ps1 to be present in the repository (commonly under src\Create-VSSolution.ps1).
#>

[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
    [Parameter(HelpMessage = 'Show this help message and exit')]
    [Alias('h')]
    [switch]$Help,

    [string]$InstallPath = [System.IO.Path]::Combine($env:USERPROFILE, 'Scripts'),

    [switch]$AddToPath,

    [switch]$CreateProfileFunction,

    [switch]$DeleteProfileFunction,

    [switch]$Delete,

    [switch]$AsModule,

    [switch]$Force,

    [Alias('v')]
    [int]$VerboseMode = 1
)

function Show-Usage {
    # Print a concise usage summary
    $scriptName = (Split-Path -Leaf $PSCommandPath)
    Write-Host
    Write-Host "Usage: $scriptName [-Help] [-InstallPath <path>] [-AddToPath] [-CreateProfileFunction] [-DeleteProfileFunction] [-Delete] [-AsModule] [-Force] [-VerboseMode <0|1|2>]"
    Write-Host ""
    Write-Host "  -InstallPath              Destination folder for the script and shim. Defaults to %USERPROFILE%\Scripts."
    Write-Host "  -AddToPath                Add InstallPath to the user's PATH environment variable."
    Write-Host "  -CreateProfileFunction    Add a Create-VSSolution wrapper function to the user's PowerShell profile."
    Write-Host "  -DeleteProfileFunction    Remove the Create-VSSolution wrapper from the user's PowerShell profile."
    Write-Host "  -Delete                   Remove installed script, shim, module, profile wrapper and user PATH entry."
    Write-Host "  -AsModule                 Install Create-VSSolution.ps1 as a simple module."
    Write-Host "  -Force                    Overwrite existing files and manifest entries without prompting."
    Write-Host
    Write-Host "For full help (detailed parameter descriptions), run:" -ForegroundColor Green
    Write-Host "  Get-Help $scriptName -Full"
    Write-Host
}

# Write helpers respect numeric verbosity:0 = silent,1 = errors/warnings only,2 = errors+warnings+ok+info,3+ = debug
function Write-Info { if ($VerboseMode -ge 2) { Write-Host "[INFO]" -ForegroundColor Cyan -NoNewline; Write-Host " $args" } }
function Write-Ok { if ($VerboseMode -ge 2) { Write-Host "[OK]" -ForegroundColor Green -NoNewline; Write-Host " $args" } }
function Write-Err { if ($VerboseMode -ge 1) { Write-Host "[ERR]" -ForegroundColor Red -NoNewline; Write-Host " $args" } }
function Write-Warn { if ($VerboseMode -ge 1) { Write-Host "[WARN]" -ForegroundColor Magenta -NoNewline; Write-Host " $args" } }
function Write-Debug { if ($VerboseMode -ge 3) { Write-Host "[DEBUG]" -ForegroundColor Yellow -NoNewline; Write-Host " $args" } }

# Name of the script we install/copy; use a single variable instead of hardcoded strings
$ScriptFileName = 'Create-VSSolution.ps1'
$ScriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptFileName)

# Main Script Logic

# Show-Help
# If user asked for help, show usage AND the comment-based help summary via Get-Help, then exit
if ($Help) {
    Show-Usage
    exit0
}

if ($VerboseMode -ge 2) { Write-Host "Starting installation script for $ScriptBaseName..." -ForegroundColor Green }

# Determine whether any action switches were provided. Discover switch parameters from the script's parameter metadata instead of hardcoding.
# Exclude non-action switches such as Help, Force and VerboseMode.
$nonActionSwitches = @('Help', 'Force', 'VerboseMode')
$actionSwitches = @()

try {
    $cmd = Get-Command -Name $PSCommandPath -ErrorAction SilentlyContinue
    if ($null -ne $cmd -and $cmd.Parameters) {
        foreach ($entry in $cmd.Parameters.GetEnumerator()) {
            # $entry is a DictionaryEntry: Key = parameter name, Value = ParameterMetadata
            if ($entry.Value.ParameterType -eq [System.Management.Automation.SwitchParameter]) {
                if (-not ($nonActionSwitches -contains $entry.Key)) {
                    $actionSwitches += $entry.Key
                }
            }
        }
    }
}
catch {
    # Ignore and fall back
}

$actionProvided = $false
foreach ($name in $actionSwitches) {
    if ($PSBoundParameters.ContainsKey($name) -and $PSBoundParameters[$name]) {
        $actionProvided = $true
        Write-Debug "Action switch provided: -$name"
        break
    }
}

# Default behavior: if no action switches provided, enable AddToPath
if (-not $actionProvided) {
    $AddToPath = $true
    $CreateProfileFunction = $true
    Write-Ok "No action flags provided - defaulting to -AddToPath"
}

# Ensure install folder exists (safe to create even if deleting wrapper)
if (-not (Test-Path -Path $InstallPath)) {
    try {
        New-Item -ItemType Directory -Path $InstallPath -Force -ErrorAction Stop | Out-Null
        if (Test-Path -Path $InstallPath) {
            Write-Ok "Created install folder: $InstallPath"
        }
        else {
            Write-Warn "Failed to create install folder: $InstallPath"
        }
    }
    catch {
        Write-Warn "Failed to create install folder: $InstallPath. Error: $_"
    }
}

$dest = Join-Path $InstallPath $ScriptFileName

if (-not $DeleteProfileFunction) {
    $source = $null
    # Determine source script path (assume repo root where this installer lives)
    $possibleSources = @(
        (Join-Path $PSScriptRoot (Join-Path 'src' $ScriptFileName)),
        (Join-Path $PSScriptRoot $ScriptFileName),
        (Join-Path (Get-Location).Path (Join-Path 'src' $ScriptFileName)),
        (Join-Path (Get-Location).Path $ScriptFileName)
    )

    # Select the first existing path (use a simple loop to avoid Select-Object parsing issues)
    foreach ($p in $possibleSources) {
        if (Test-Path $p) { $source = $p; break }
    }

    if (-not $source) {
        # When source not found, exit with code1
        Write-Err "Source '$ScriptFileName' not found in repo - skipping copy/module installation. You can still use -AddToPath to add the scripts folder to PATH."
        exit1
    }
}

# If -Delete specified, perform cleanup and exit
if ($Delete) {
    Write-Info "Running -Delete: will remove script, shim, module, profile wrapper and user PATH entry if present."

    # Remove script and shim
    $scriptPath = $dest
    $shimPath = Join-Path $InstallPath 'Create-VSSolution.cmd'
    if (Test-Path $scriptPath) {
        try { Remove-Item -Path $scriptPath -Force -ErrorAction Stop; Write-Ok "Removed script: $scriptPath" } catch { Write-Err "Failed to remove script: $_" }
    }
    else { Write-Ok "Script not found: $scriptPath" }
    if (Test-Path $shimPath) {
        try { Remove-Item -Path $shimPath -Force -ErrorAction Stop; Write-Ok "Removed shim: $shimPath" } catch { Write-Err "Failed to remove shim: $_" }
    }
    else { Write-Warn "Shim not found: $shimPath" }

    # Remove module folder
    $moduleDir = Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules\Create-VSSolution'
    if (Test-Path $moduleDir) {
        try { Remove-Item -Path $moduleDir -Recurse -Force -ErrorAction Stop; Write-Ok "Removed module folder: $moduleDir" } catch { Write-Err "Failed to remove module folder: $_" }
    }
    else { Write-Warn "Module folder not found: $moduleDir" }

    # Remove install path from user PATH
    try {
        $current = [Environment]::GetEnvironmentVariable('Path', 'User')
        if ($current -and $current -like "*${InstallPath}*") {
            $parts = $current -split ';' | Where-Object { $_ -ne '' }
            $newParts = $parts | Where-Object { -not ([string]::Equals($_, $InstallPath, [System.StringComparison]::InvariantCultureIgnoreCase)) }
            $new = [string]::Join(';', $newParts)
            [Environment]::SetEnvironmentVariable('Path', $new, 'User')
            Write-Ok "Removed $InstallPath from user PATH. Restart terminals to pick up change."
        }
        else {
            Write-Ok "User PATH did not contain $InstallPath"
        }
    }
    catch { Write-Err "Failed to update user PATH: $_" }

    # Remove wrapper from profile (reuse existing removal logic)
    if (Test-Path -Path $PROFILE) {
        try {
            $lines = Get-Content -Path $PROFILE -ErrorAction SilentlyContinue
            $out = @()
            foreach ($line in $lines) {
                if ($line -match '# Wrapper to run Create-VSSolution') { continue }
                if ($line -match 'function\s+Create-VSSolution') { continue }
                $out += $line
            }
            Set-Content -Path $PROFILE -Value $out
            Write-Ok "Removed Create-VSSolution wrapper from profile ($PROFILE)."
        }
        catch { Write-Err "Failed to remove wrapper from profile: $_" }
    }
    else {
        Write-Ok "Profile $PROFILE does not exist. Nothing to remove."
    }

    Write-Host "Delete complete." -ForegroundColor Cyan
    exit 0
}

# Optionally add to user PATH
if ($AddToPath) {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($current -notlike "*${InstallPath}*") {
        $new = if ([string]::IsNullOrEmpty($current)) { $InstallPath } else { $current + ';' + $InstallPath }
        [Environment]::SetEnvironmentVariable('Path', $new, 'User')
        Write-Ok "Added $InstallPath to user PATH. Restart terminals to pick up change."
    }
    else {
        Write-Info "$InstallPath already in user PATH."
    }
}

# If not deleting, perform copy to install path
if (-not $DeleteProfileFunction) {
    # Use a variable for Test-Path result to avoid parsing issues on some PowerShell versions
    $destExists = Test-Path $dest
    # When checking for existing destination or aborting, ensure we use `exit1`
    if ($destExists) {
        if (-not $Force) {
            $resp = Read-Host "File $dest already exists. Overwrite? (y/N)"
            if ($resp -notin @('y', 'Y')) {
                Write-Warn "Aborting installation to avoid overwriting existing file."
                exit 1
            }
        }
    }
    try {
        Copy-Item -Path $source -Destination $dest -Force:$Force -ErrorAction Stop
        Write-Ok "Copied $ScriptFileName to $dest"
    }
    catch {
        Write-Err "Failed to copy $ScriptFileName to ${dest}: $_"
        exit 1
    }
    # If -AsModule specified, install as simple module
    if ($AsModule) {
        $moduleDir = Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules\Create-VSSolution'
        try {
            if (-not (Test-Path -Path $moduleDir)) {
                New-Item -ItemType Directory -Path $moduleDir -Force -ErrorAction Stop | Out-Null
                Write-Ok "Created module directory: $moduleDir"
            }
            $moduleDest = Join-Path $moduleDir $ScriptFileName
            Copy-Item -Path $source -Destination $moduleDest -Force:$Force -ErrorAction Stop
            Write-Ok "Installed Create-VSSolution as module in: $moduleDest"
        }
        catch {
            Write-Err "Failed to install module: $_"
            exit 1
        }
    }
}

# Optionally install as a simple module
if ($AsModule) {
    $moduleDir = Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules\Create-VSSolution'
    if (-not (Test-Path $moduleDir)) { New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null }
    $moduleFile = Join-Path $moduleDir 'Create-VSSolution.psm1'
    try {
        if ($Force) { Copy-Item -Path $source -Destination $moduleFile -Force -ErrorAction Stop } else { Copy-Item -Path $source -Destination $moduleFile -ErrorAction Stop }
        Unblock-File -Path $moduleFile -ErrorAction SilentlyContinue
    }
    catch {
        Write-Err "Failed to copy module file: $_"
        exit 1
    }

    # Create a minimal module manifest (.psd1) if not present
    $psd1 = Join-Path $moduleDir 'Create-VSSolution.psd1'
    if (-not (Test-Path $psd1)) {
        @{
            RootModule    = 'Create-VSSolution.psm1'
            ModuleVersion = '1.0.0'
            GUID          = [guid]::NewGuid().ToString()
            Author        = ''
            CompanyName   = ''
            Copyright     = ''
            Description   = 'Create-VSSolution PowerShell module'
        } | Out-String | Set-Content -Path $psd1
    }
    Write-Ok "Installed as module at $moduleDir. Import with 'Import-Module Create-VSSolution' or call the exported functions after a restart."
}

if ($VerboseMode -ge 2) { Write-Host "Done." -ForegroundColor Green }