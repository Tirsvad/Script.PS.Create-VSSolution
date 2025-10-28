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

################################################################################
# Variables and initial setup
################################################################################

# Get the directory of the current script
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

# Name of the script we install/copy; use a single variable instead of hardcoded strings
$ScriptFileName = 'Create-VSSolution.ps1'
$ScriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptFileName)
$ScriptNameSpace = 'TirsvadScript.CreateVSSolution'
# Build the inc path as: $ScriptDirectory\TirsvadScript.CreateVSSolution\inc
$ScriptIncPath = Join-Path -Path (Join-Path -Path $ScriptDirectory -ChildPath $ScriptNameSpace) -ChildPath 'inc'

################################################################################
# Include sourced libraries
################################################################################
# Download, unzip and dot-source logging library
$loggingDir = Join-Path -Path $ScriptIncPath -ChildPath 'TirsvadScript.Logging'
$loggingScript = Join-Path -Path $loggingDir -ChildPath 'TirsvadScript.Logging.ps1'
$loggingZipUrl = 'https://github.com/TirsvadScript/PS.Logging/releases/download/v0.1.1/TirsvadScript.Logging.zip'

if (-not (Test-Path -Path $loggingScript)) {
    Write-Host "Logging library not found. Downloading from $loggingZipUrl..."
    $tmpZip = Join-Path -Path $env:TEMP -ChildPath ([System.IO.Path]::GetRandomFileName() + '.zip')
    try {
        Invoke-WebRequest -Uri $loggingZipUrl -OutFile $tmpZip -UseBasicParsing -ErrorAction Stop
        if (-not (Test-Path -Path $loggingDir)) { New-Item -ItemType Directory -Path $loggingDir -Force | Out-Null }
        Expand-Archive -Path $tmpZip -DestinationPath $loggingDir -Force
        Remove-Item -Path $tmpZip -Force
    }
    catch {
        Write-Host "Failed to download or extract logging package: $_" -ForegroundColor Red
    }
}

if (Test-Path -Path $loggingScript) {
    . $loggingScript
    Write-Debug "Loaded logging from: $loggingScript"
}
else {
    Write-Err "Logging script not found at expected location: $loggingScript"
    exit 1
}

################################################################################
# Main Script Logic
################################################################################
Write-Header "Create-VSSolution Installer"
Write-Info "Using install path: $InstallPath"

# Show-Help
# If user asked for help, show usage AND then exit
if ($Help) {
    Show-Usage
    exit 0
}

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
    Write-Debug "No action flags provided - defaulting to -AddToPath"
}

# Ensure install folder exists (safe to create even if deleting wrapper)
if (-not (Test-Path -Path $InstallPath)) {
    Write-Run "Creating install folder: $InstallPath"
    try {
        New-Item -ItemType Directory -Path $InstallPath -Force -ErrorAction Stop | Out-Null
        if (Test-Path -Path $InstallPath) {
            Write-RunDone $true
        }
        else {
            Write-RunDone $false
            Write-Err "Install folder creation reported success but path does not exist: $InstallPath"
            exit 1
        }
    }
    catch {
        Write-Err "Failed to create install folder: $InstallPath. Error: $_"
    }
}

################################################################################
# Path to source and destination
################################################################################
$dest = Join-Path $InstallPath $ScriptFileName
$source = (Join-Path $PSScriptRoot $ScriptFileName)

################################################################################
# Perform cleanup and exit
# Optionally: -Delete
################################################################################
if ($Delete) {
    Write-Run "Starting cleanup of installed artifacts..."
    [array]$errors = @()
    [array]$warnings = @()

    # Remove script and shim
    $scriptPath = $dest
    $shimPath = Join-Path $InstallPath 'Create-VSSolution.cmd'
    if (Test-Path $scriptPath) {
        try { Remove-Item -Path $scriptPath -Force -ErrorAction Stop; Write-Debug "Removed script: $scriptPath" } catch { $errors += "Failed to remove script: $_" }
    }
    else { Write-Debug "Script not found: $scriptPath" }
    if (Test-Path $shimPath) {
        try { Remove-Item -Path $shimPath -Force -ErrorAction Stop; Write-Debug "Removed shim: $shimPath" } catch { $errors += "Failed to remove shim: $_" }
    }
    else { $warnings += "Shim not found: $shimPath"}

    #Remove folder if it exists
    $incDir = Join-Path $InstallPath $ScriptNameSpace
    if (Test-Path $incDir) {
        try { Remove-Item -Path $incDir -Recurse -Force -ErrorAction Stop; Write-Debug "Removed inc folder: $incDir" } catch { $errors += "Failed to remove inc folder: $_" }
    }
    else { $warnings += "Inc folder not found: $incDir" }

    # Remove module folder
    $moduleDir = Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules\Create-VSSolution'
    if (Test-Path $moduleDir) {
        try { Remove-Item -Path $moduleDir -Recurse -Force -ErrorAction Stop; Write-Debug "Removed module folder: $moduleDir" } catch { $errors += "Failed to remove module folder: $_" }
    }
    else { $warnings += "Module folder not found: $moduleDir" }

    # Remove install path from user PATH
    try {
        $current = [Environment]::GetEnvironmentVariable('Path', 'User')
        if ($current -and $current -like "*${InstallPath}*") {
            $parts = $current -split ';' | Where-Object { $_ -ne '' }
            $newParts = $parts | Where-Object { -not ([string]::Equals($_, $InstallPath, [System.StringComparison]::InvariantCultureIgnoreCase)) }
            $new = [string]::Join(';', $newParts)
            [Environment]::SetEnvironmentVariable('Path', $new, 'User')
            Write-Debug "Removed $InstallPath from user PATH. Restart terminals to pick up change."
        }
        else {
            Write-Debug "User PATH did not contain $InstallPath"
        }
    }
    catch { $errors +=  "Failed to update user PATH: $_" }

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
            Write-Debug "Removed Create-VSSolution wrapper from profile ($PROFILE)."
        }
        catch { $errors += "Failed to remove wrapper from profile: $_" }
    }
    else {
        Write-Debug "Profile $PROFILE does not exist. Nothing to remove."
    }

    if ($errors.Count -eq 0 ) {
        Write-RunDone $true
    }
    else {
        Write-RunDone $false
    }

    if ($warnings.Count -gt 0) {
        Write-Host "Cleanup completed with warnings:"
        foreach ($warn in $warnings) {
            Write-Warn " - $warn"
        }
    }

    if ($errors.Count -gt 0) {
        Write-Host "Cleanup completed with errors:"
        foreach ($err in $errors) {
            Write-Err " - $err"
        }
        exit 1
    }
    exit 0
}

################################################################################
# Add script path to user PATH
# Optionally: -AddToPath
################################################################################
if ($AddToPath) {
    Write-Run "Adding $InstallPath to user PATH..."
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($current -notlike "*${InstallPath}*") {
        $new = if ([string]::IsNullOrEmpty($current)) { $InstallPath } else { $current + ';' + $InstallPath }
        [Environment]::SetEnvironmentVariable('Path', $new, 'User')
        Write-RunDone $true
        Write-Debug "Added $InstallPath to user PATH. Restart terminals to pick up change."
    }
    else {
        Write-RunDone $true
        Write-Warn "$InstallPath already in user PATH."
    }
}

################################################################################
# Copy Scripts and inc folder
################################################################################
# If not deleting, perform copy to install path
if (-not $DeleteProfileFunction) {
    Write-Run "Copying $ScriptFileName to $InstallPath..."
    [array]$errors = @()
    [array]$warnings = @()
    # Use a variable for Test-Path result to avoid parsing issues on some PowerShell versions
    $destExists = Test-Path $dest
    # When checking for existing destination or aborting, ensure we use `exit 1`
    if ($destExists) {
        if (-not $Force) {
            $resp = Read-Host "File $dest already exists. Overwrite? (y/N)"
            if ($resp -notin @('y', 'Y')) {
                Write-RunDone $false
                Write-Warn "Aborting installation to avoid overwriting existing file."
                exit 1
            }
        }
    }
    try {
        Copy-Item -Path $source -Destination $dest -Force:$Force -ErrorAction Stop
        Write-Debug "Copied $ScriptFileName to $dest"
    }
    catch {
        $errors += "Failed to copy $ScriptFileName to ${dest}: $_"
    }

    # Copy 'inc' folder if it exists
    if (Test-Path $ScriptNameSpace) {
        Write-Info "Copying $ScriptNameSpace folder to $InstallPath"
        try {
            Copy-Item -Path $ScriptNameSpace -Destination $InstallPath -Recurse -Force:$Force -ErrorAction Stop
            Write-Debug "Copied '$ScriptNameSpace' folder to $InstallPath"
        }
        catch {
            $errors += "Failed to copy '$ScriptNameSpace' folder to ${InstallPath}: $_"
        }
    }
    else {
        $errors += "$ScriptNameSpace folder not found at expected location: $sourceInc"
    }
    if ($errors.Count -eq 0 ) {
        Write-RunDone $true
    }
    else {
        Write-RunDone $false
        foreach ($err in $errors) {
            Write-Err " - $err"
        }
        exit 1
    }
}

################################################################################
# Install as a simple module
# Optionally: -AsModule
################################################################################
if ($AsModule) {
    Write-Run "Installing Create-VSSolution as a PowerShell module..."
    $moduleDir = Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules\Create-VSSolution'
    if (-not (Test-Path $moduleDir)) { New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null }
    $moduleFile = Join-Path $moduleDir 'Create-VSSolution.psm1'
    try {
        if ($Force) { Copy-Item -Path $source -Destination $moduleFile -Force -ErrorAction Stop } else { Copy-Item -Path $source -Destination $moduleFile -ErrorAction Stop }
        Copy-Item -Path $sourceInc -Destination (Join-Path $moduleDir 'inc') -Recurse -Force:$Force -ErrorAction Stop
        Unblock-File -Path $moduleFile -ErrorAction SilentlyContinue
    }
    catch {
        Write-RunDone $false
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
    Write-RunDone $true
    Write-Info "Module import with 'Import-Module Create-VSSolution' or call the exported functions after a restart."
}

Write-Info "Done."