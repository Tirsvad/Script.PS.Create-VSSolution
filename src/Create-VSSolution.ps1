<#
.SYNOPSIS
    Create a solution skeleton where src folder has three library projects, and one UI project.

.PARAMETER SolutionName
 Name of the solution to create.

.PARAMETER ProjectTemplate
    One of: "wpf", "winui-blank", "winui-package"

.PARAMETER TargetFramework
    Target framework for class library projects (default: net9.0).

.EXAMPLE
    .\Create-VSSolution.ps1 -SolutionName MyApp -ProjectTemplate wpf
#>

[CmdletBinding(DefaultParameterSetName='Default')]
param (
    [Parameter(HelpMessage='Show this help message and exit')]
    [Alias('h')]
    [switch]$Help,

    [Parameter(Mandatory = $true)]
    [Alias('s')]
    [string]$SolutionName,

    [Parameter(Mandatory = $true)]
    [ValidateSet("blank", "wpf", "winui-blank", "winui-package")]
    [Alias('p')]
    [string]$ProjectTemplate = "winui-package",

    [ValidateSet("net9.0", "net8.0")]
    [Alias('t')]
    [string]$TargetFramework = "net9.0", # default target framework; can be adjusted as needed

    [Alias('v')]
    [int]$VerboseMode = 1
)

function Show-Usage {
    # Print a concise usage summary
    $scriptName = (Split-Path -Leaf $PSCommandPath)
    Write-Host
    Write-Host "Usage: $scriptName [-Help] [-SolutionName <name>] [-ProjectTemplate <template>] [-TargetFramework <framework>] [-VerboseMode <0|1|2>]"
    Write-Host ""
    Write-Host "  -SolutionName             Name of the solution to create."
    Write-Host "  -ProjectTemplate          One of: 'wpf', 'winui-blank', 'winui-package'"
    Write-Host "  -TargetFramework          Target framework for class library projects (default: net9.0)."
    Write-Host ""
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

function FailIfNoDotnet {
    # Ensure either dotnet CLI or Visual Studio's devenv is available before proceeding
    $hasDotnet = (Get-Command dotnet -ErrorAction SilentlyContinue) -ne $null

    # Detect Visual Studio's devenv either via a known variable or via PATH
    $hasDevenv = $false
    # If the script-level variable `devenvPath` exists, validate it safely
    if (Get-Variable -Name devenvPath -Scope Script -ErrorAction SilentlyContinue) {
        if ($script:devenvPath) { $hasDevenv = Test-Path $script:devenvPath }
    }
    else {
        # Fallback: check if devenv is available on the PATH
        $hasDevenv = (Get-Command devenv -ErrorAction SilentlyContinue) -ne $null
    }

    if (-not ($hasDotnet -or $hasDevenv)) {
        Write-Error "Neither dotnet CLI nor Visual Studio (devenv.exe) was found. Install the .NET SDK or provide a valid Visual Studio path."
        exit2
    }
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
        Write-Debug "Running: $cmd $($argList -join ' ')"
        $proc = Start-Process -FilePath $cmd -ArgumentList $argList -Wait -PassThru -WindowStyle Hidden
    }
    else {
        Write-Debug "Running: $cmd"
        $proc = Start-Process -FilePath "powershell" -ArgumentList @('-NoProfile', '-Command', $cmd) -Wait -PassThru -WindowStyle Hidden
    }
    if ($proc.ExitCode -ne 0) {
        Write-Err "Process $cmd $($argList -join ' ') failed with exit code $($proc.ExitCode)"
    }
    return $proc.ExitCode
}

function SetCorrectProjectTemplate {
    param ([string]$template)

    switch ($template) {
        "winui-blank" { return "Blank App, Unpackaged (WinUI3)" }
        "winui-package" { return "Blank App, Packaged (WinUI3)" }
        default { return $template }
    }
}

# Helper: try creating a project using Visual Studio's devenv automation; return $true on success
function TryCreateWithDevenv {
    param (
        [string]$templateName,
        [string]$projectName,
        [string]$projectPath,
        [string]$solutionPath
    )

    if (-not $devenvPath -or -not (Test-Path $devenvPath)) {
        return $false
    }

    # Build the single /Command argument for devenv
    $command = 'Project.AddNewProject "' + $templateName + '" "' + $projectName + '" "' + $solutionPath + '"'
    $arg = "/Command:$command"

    Write-Host "Attempting to create project via Visual Studio: $templateName -> $projectName"
    try {
        $proc = Start-Process -FilePath $devenvPath -ArgumentList $arg -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
        if ($proc.ExitCode -eq 0) {
            Write-Host "Created project via Visual Studio: $projectName"
            return $true
        }
        else {
            Write-Warning "devenv returned exit code $($proc.ExitCode) when creating $projectName"
            return $false
        }
    }
    catch {
        Write-Warning "devenv automation failed: $($_.Exception.Message)"
        return $false
    }
}

# Helper to add a project to a specific solution and verify
function AddProjectToSolution {
    param (
        [string]$slnPath,
        [string]$projPath
    )

    if (-not (Test-Path $slnPath)) {
        Write-Warning "Solution file not found: $slnPath"
        return $false
    }
    if (-not (Test-Path $projPath)) {
        Write-Warning "Project file not found: $projPath"
        return $false
    }

    Write-Host "Adding project to solution: $projPath -> $slnPath"
    & dotnet sln $slnPath add $projPath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "dotnet sln add failed with exit code $LASTEXITCODE"
        return $false
    }

    return $true
}

function CreateSolution {
    param (
        [string]$solutionName,
        [string]$solutionPath
    )
    Write-Debug "Creating solution: $solutionName"
    $cmd = "dotnet new sln -n `"$solutionName`" -o `"$solutionPath`""
    $rc = Run $cmd
    if ($rc -ne 0) {
        Write-Warn "'dotnet new sln' failed (rc=$rc)."
        exit 2
    }
}

function CreateSolutionDirectoryBuildProps {
    param (
        [string]$solutionPath
    )
    $slnDir = Get-Item $solutionPath
    $slnPropFile = Join-Path $slnDir.FullName "Directory.Build.props"
    $content = @'
<Project>
  <PropertyGroup>
    <!-- Resolve drive root: prefer SolutionDir (when building from solution), otherwise use project directory -->
    <SolutionDriveRoot Condition="'$(SolutionDriveRoot)' == '' and '$(SolutionDir)' != ''">$([System.IO.Path]::GetPathRoot('$(SolutionDir)'))</SolutionDriveRoot>
    <SolutionDriveRoot Condition="'$(SolutionDriveRoot)' == ''">$([System.IO.Path]::GetPathRoot('$(MSBuildProjectDirectory)'))</SolutionDriveRoot>
      
    <!-- Only set these if not already specified (allows per-project overrides) -->
    <BaseOutputPath Condition="'$(BaseOutputPath)' == ''">$([System.IO.Path]::Combine('$(SolutionDriveRoot)','g','$(MSBuildProjectName)'))</BaseOutputPath>
    <BaseIntermediateOutputPath Condition="'$(BaseIntermediateOutputPath)' == ''">$([System.IO.Path]::Combine('$(BaseOutputPath)','obj'))</BaseIntermediateOutputPath>

    <!-- keep IntermediateOutputPath consistent -->
    <IntermediateOutputPath>$(BaseIntermediateOutputPath)</IntermediateOutputPath>

    <!-- generated-source controls -->
    <EmitCompilerGeneratedFiles Condition="'$(EmitCompilerGeneratedFiles)' == ''">true</EmitCompilerGeneratedFiles>
    <CompilerGeneratedFilesOutputPath Condition="'$(CompilerGeneratedFilesOutputPath)' == ''">$([System.IO.Path]::Combine('$(BaseOutputPath)','gen','$(MSBuildProjectName)'))</CompilerGeneratedFilesOutputPath>
    <GeneratedFilesDestination Condition="'$(GeneratedFilesDestination)' == ''">$(CompilerGeneratedFilesOutputPath)</GeneratedFilesDestination>

    <!-- Default AppX/package layout path for WinUI/MSIX packaging; can be overridden per-project -->
    <PackageLayoutPath Condition="'$(PackageLayoutPath)' == ''">$([System.IO.Path]::Combine('$(BaseOutputPath)','AppX'))</PackageLayoutPath>
    <AppxPackageDir Condition="'$(AppxPackageDir)' == ''">$([System.IO.Path]::Combine('$(BaseOutputPath)','AppX'))</AppxPackageDir>
    <PackageLayout Condition="'$(PackageLayout)' == ''">$([System.IO.Path]::Combine('$(BaseOutputPath)','AppX'))</PackageLayout>
  </PropertyGroup>
</Project>
'@
    Write-Debug "Creating Directory.Build.props at: $slnPropFile"
    $content | Out-File -FilePath $slnPropFile -Encoding UTF8 -Force
}

function CreateSolutionDirectoryTargets {
    param (
        [string]$solutionPath
    )
    $slnDir = Get-Item $solutionPath
    $slnTargetFile = Join-Path $slnDir.FullName "Directory.Build.targets"
    $content = @'
<Project>
  <!-- Ensure output/intermediate/generated directories exist before any project builds -->
  <Target Name="EnsureSolutionDriveRootDirs" BeforeTargets="BeforeBuild">
    <MakeDir Directories="$(BaseIntermediateOutputPath)" Condition="'$(BaseIntermediateOutputPath)' != ''" />
    <MakeDir Directories="$(CompilerGeneratedFilesOutputPath)" Condition="'$(CompilerGeneratedFilesOutputPath)' != ''" />
  </Target>
</Project>
'@
    Write-Debug "Creating Directory.Build.targets at: $slnTargetFile"
    $content | Out-File -FilePath $slnTargetFile -Encoding UTF8 -Force
}

function CreateProjectPath {
    param (
        [string]$solutionPath,
        [string]$projectPath = "src"
    )
    $projPath = Join-Path $solutionPath $projectPath
    if (-not (Test-Path $projPath)) {
        New-Item -ItemType Directory -Path $projPath | Out-Null
        Write-Debug "Created project directory: $projPath"
    }
    return $projPath
}

function CreateCleanArchitectureProjects {
    param (
        [string]$solutionPath,
        [string]$projectPath = "src",
        [string]$targetFramework
    )
    $projects = @(
        @{ Name = "Core"; Suffix = ".Core"; Type = "classlib" },
        @{ Name = "Infrastructure"; Suffix = ".Infrastructure"; Type = "classlib" },
        @{ Name = "Domain"; Suffix = ".Domain"; Type = "classlib" }
    )
    foreach ($proj in $projects) {
        $projName = $proj.Name
        $projType = $proj.Type
        # Build path as: $solutionPath\$projectPath\$projName
        $projPath = Join-Path -Path (Join-Path -Path $solutionPath -ChildPath $projectPath) -ChildPath $projName
        Write-Debug "Creating project: $projName at $projPath"
        $cmd = "dotnet new $projType -n `"$projName`" -o `"$projPath`" -f `"$targetFramework`""
 $rc = Run $cmd
 if ($rc -ne 0) {
 Write-Warn "'dotnet new' failed for project $projName (rc=$rc)."
 exit 2
 }
        # Add project to solution
        $slnFile = Join-Path $solutionPath "$($SolutionName).sln"
        $projFile = Join-Path $projPath "$($projName).csproj"
        $added = AddProjectToSolution -slnPath $slnFile -projPath $projFile
        if (-not $added) {
            Write-Warning "Failed to add project $projName to solution."
            exit 2
        }
        CreateSubFolderForEachCleanArchitectureProjects -ProjectPath $projPath -projectName $projName
    }
}

function CreateSubFolderForEachCleanArchitectureProjects {
    param (
        [string] $ProjectPath,
        [string] $projectName
    )

    switch ($projectName) {
        "Core" {
            $subFolders = @("DTOs", "Services", "Abstract")
        }
        "Infrastructure" {
            $subFolders = @("Persistence", "Repositories", "ExternalServices", "Configurations")
        }
        "Domain" {
            $subFolders = @("Entities", "Enums", "Attributes")
        }
        default {
            $subFolders = @()
        }
    }

    foreach ($folder in $subFolders) {
        $fullPath = Join-Path -Path $ProjectPath -ChildPath $folder
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath | Out-Null
            # add gitkeep file to ensure folder is tracked
            New-Item -ItemType File -Path (Join-Path -Path $fullPath -ChildPath ".gitkeep") | Out-Null
            Write-Debug "Created subfolder: $fullPath"
        }
    }
}

function CreateWinUIProject {
    param (
        [string]$projectName,
        [string]$projectTemplate,
        [string]$solutionPath
    )

    # Determine target project path (create under solution folder)
    $projectPath = Join-Path $solutionPath $projectName

    # Try Visual Studio automation first
    if ($devenvPath -and (Test-Path $devenvPath)) {
        $ok = TryCreateWithDevenv -templateName $projectTemplate -projectName $projectName -projectPath $projectPath -solutionPath $solutionPath
        if ($ok) { return }
        Write-Warning "devenv creation failed or was unsupported; falling back to dotnet new."
    }

    # Fallback: use dotnet new
    Write-Host "Creating WinUI project with 'dotnet new winui': $projectName"
    $cmd = "dotnet new winui -n `"$projectName`" -o `"$projectPath`""
    $rc = Run $cmd
    if ($rc -ne 0) {
        Write-Warning "'dotnet new winui' failed (rc=$rc). Ensure WinUI templates / Windows App SDK are installed."
    }

    # Verify project created
    if (-not (Test-Path $projectPath)) {
        Write-Error "Failed to create the project: $projectName"
        exit2
    }
}

function CheckDevEnv {
    param ([string]$devenvExe)
    Write-Debug "Checking for Visual Studio's devenv at: $devenvExe"
    if (Test-Path $devenvExe) {
        $script:devenvPath = $devenvExe
        Write-Ok "Using Visual Studio's devenv at: $devenvExe"
    }
    else {
        Write-Warn "Visual Studio's devenv.exe not found at expected path: $devenvExe"
        $userInput = Read-Host 'Enter full path to devenv.exe (leave empty to skip)'
        if (-not [string]::IsNullOrWhiteSpace($userInput)) {
            CheckDevEnv $userInput
        }
        else {
             $script:devenvPath = $null
             Write-Warn "Proceeding without Visual Studio's devenv; dotnet CLI will be used where possible."
        }
    }
}

function CheckWinUIEnvironment {
    # Ensure that either Visual Studio or dotnet CLI has WinUI templates installed
    $hasWinUITemplates = $false
    # Check via dotnet CLI
    $templates = & dotnet new --list
    if ($templates -match "winui") {
        $hasWinUITemplates = $true
    }
    if (-not $hasWinUITemplates) {
        Write-Warn "WinUI templates not found in dotnet CLI."
        if ($devenvPath -and (Test-Path $devenvPath)) {
            Write-Ok "Visual Studio is available; assuming WinUI support is present."
            $hasWinUITemplates = $true
        }
        else {
            Write-Err "Neither dotnet CLI nor Visual Studio has WinUI support. Please install the Windows App SDK."
            exit 2
        }
    }
}

# Remember starting location and set baseDir to a new folder named after the solution
$startingLocation = Get-Location
$baseDir = Join-Path -Path $startingLocation -ChildPath $SolutionName
if (-not (Test-Path $baseDir)) {
    New-Item -ItemType Directory -Path $baseDir | Out-Null
    Write-Ok "Created solution directory: $baseDir"
}
# Check if baseDir is empty
if ((Get-ChildItem -Path $baseDir | Measure-Object).Count -ne 0) {
    Write-Err "The solution directory is not empty: $baseDir"
    exit 2
}
Push-Location $baseDir

# Default path to Visual Studio's (adjust for your version/edition if needed)
$devenvExe = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe"

# Check for Visual Studio's devenv.exe
CheckDevEnv $devenvExe

# Main script logic

# Show-Help
# If user asked for help, show usage and then exit
if ($Help) {
 Show-Usage
 exit0
}

# Ensure dotnet CLI or Visual Studio is available
FailIfNoDotnet

# For WinUI projects, ensure Visual Studio is available
CheckWinUIEnvironment

# Create solution and clean architecture projects 
CreateSolution -solutionName $SolutionName -solutionPath $baseDir
CreateSolutionDirectoryBuildProps -solutionPath $baseDir
CreateSolutionDirectoryTargets -solutionPath $baseDir
$projPath = CreateProjectPath -solutionPath $baseDir
CreateCleanArchitectureProjects -solutionPath $baseDir -targetFramework $TargetFramework

switch ($ProjectTemplate) {
    "blank" {
        Write-Ok "Created blank solution: $SolutionName"
    }
    "wpf" {
        $projectType = "WPF"
        Write-Ok "Created WPF solution: $SolutionName"
    }
    default {
        Write-Err "Unsupported project template: $ProjectTemplate"
        exit 2
    }
}
