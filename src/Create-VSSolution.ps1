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
    [ValidateSet("blank", "wpf")]
    [Alias('p')]
    [string]$ProjectTemplate = "wpf",

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

function CheckDependencies {
    foreach ($dep in $dependenciesTupleList) {
        $moduleName = $dep.Item1
        $flagName = $dep.Item2
        $url = $dep.Item3
        $destinationPath = Join-Path -Path $ScriptDirectoryInc -ChildPath $moduleName

        # See if the dependency flag is present in the script scope
        $isLoaded = Get-Variable -Name $flagName -Scope Script -ErrorAction SilentlyContinue

        # If the folder doesn't exist or the flag isn't set, attempt to download and include
        if ((-not (Test-Path -Path $destinationPath)) -or ($null -eq $isLoaded) -or (-not $isLoaded.Value)) {
            Write-Warn "Dependency $moduleName is not loaded. Attempting to download and include it from $url"
            UnzipFileFromUrl -url $url -destinationPath $destinationPath
            if (Test-Path -Path (Join-Path -Path $destinationPath -ChildPath "$($moduleName).ps1")) {
                . (Join-Path -Path $destinationPath -ChildPath "$($moduleName).ps1")
            }
            else {
                Write-Warn "Downloaded dependency but could not find $($moduleName).ps1 in $destinationPath"
            }
        }
    }
    if (-not $TirsvadScript.LoggingLoaded) {
        Write-Error "TirsvadScript.Logging module is not loaded."
        exit2
    }
}

function UnzipFileFromUrl {
    param (
        [string]$url,
        [string]$destinationPath = $null
    )

    if (-not $destinationPath) {
        # Default to the script's 'inc' directory
        $destinationPath = Join-Path -Path $ScriptDirectoryInc -ChildPath ""
    }

    # Ensure destination directory exists
    if (-not (Test-Path -Path $destinationPath)) {
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
    }

    $tempZip = Join-Path -Path $env:TEMP -ChildPath ([System.IO.Path]::GetRandomFileName() + ".zip")
    Write-Debug "Downloading $url to temporary file $tempZip"
    Invoke-WebRequest -Uri $url -OutFile $tempZip
    Write-Debug "Extracting $tempZip to $destinationPath"
    Expand-Archive -Path $tempZip -DestinationPath $destinationPath -Force
    Remove-Item -Path $tempZip
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

    function Remove-DefaultClassFile {
        param (
            [string] $projectPath
        )
        $classFile = Join-Path -Path $projectPath -ChildPath "Class1.cs"
        if (Test-Path $classFile) {
            $cmd = "Remove-Item -Path `"$classFile`""
            $rc = Run $cmd
            Write-Debug "Removed default class file: $classFile"
        }
    }

    function AddReferencesToProject {
        param (
            [string] $projectPath,
            [string[]] $references
        )
        # Find the project's .csproj file
        $projCsproj = Get-ChildItem -Path $projectPath -Filter '*.csproj' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $projCsproj) {
            Write-Warn "No .csproj found in project folder: $projectPath. Skipping reference addition."
            return
        }
        $projCsprojPath = $projCsproj.FullName

        foreach ($ref in $references) {
            # Determine the sibling project directory (projects live under the same parent 'src' folder)
            $parentDir = Split-Path -Path $projectPath -Parent
            $refProjPath = Join-Path -Path $parentDir -ChildPath $ref
            $refProjFile = Join-Path -Path $refProjPath -ChildPath "$($ref).csproj"
            Write-Debug "Reference project file: $refProjFile"
            Write-Debug "Reference project path: $refProjPath"
            Write-Debug "projCsprojPath: $projCsprojPath"
            if (Test-Path $refProjFile) {
                Write-Debug "Adding reference to project: $refProjFile in $projCsprojPath"
                # Use dotnet CLI directly so we can check the exit code
                $cmd = "dotnet reference add `"$refProjFile`" --project `"$projCsprojPath`""
                $rc = Run $cmd
                if ($rc -ne 0) {
                    Write-Warn "dotnet add returned exit code $rc when adding reference $refProjFile to $projCsprojPath"
                }
                else {
                    Write-RunDone $true
                }
            }
            else {
                Write-Warn "Reference project file not found: $refProjFile"
            }
        }
    }

    $projects = @(
        @{ Name = "Domain"; Suffix = ".Domain"; Type = "classlib"; References = @() },
        @{ Name = "Core"; Suffix = ".Core"; Type = "classlib"; References = @("Domain") },
        @{ Name = "Infrastructure"; Suffix = ".Infrastructure"; Type = "classlib"; References = @("Core") }
    )
    foreach ($proj in $projects) {
        $projName = $proj.Name
        $projType = $proj.Type
        $projRefs = $proj.References
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

        # Remove Class1.cs
        Remove-DefaultClassFile $projPath

        if (-not $projRefs.Count -eq 0) {
        # Add references
        Write-Debug "project path $projPath"
        Write-Debug "project refs $projRefs"
        AddReferencesToProject -projectPath $projPath -references $projRefs
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

################################################################################
# Script initialization
################################################################################
# Get the directory of the current script
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
# Namespace
$ScriptNamespace = "TirsvadScript.CreateVSSolution"
# Path to the 'inc' directory for sourced libraries
$ScriptDirectoryInc = Join-Path -Path $ScriptDirectory -ChildPath (Join-Path -Path $ScriptNamespace -ChildPath "inc")
$ScriptDirectoryTemplates = Join-Path -Path $ScriptDirectory -ChildPath (Join-Path -Path $ScriptNamespace -ChildPath "templates")

################################################################################
# Include logging library early so helper functions (Write-Warn etc.) are available
################################################################################
. "$ScriptDirectoryInc\TirsvadScript.Logging\TirsvadScript.Logging.ps1"

# Dependencies
$dependenciesTupleList = New-Object 'System.Collections.Generic.List[System.Tuple[string,string,string]]'
# $dependenciesTupleList.Add([Tuple]::Create("TirsvadScript.Logging", "TirsvadScript.LoggingLoaded", "https://github.com/TirsvadScript/PS.Logging/releases/download/v0.1.0/TirsvadScript.Logging.zip"))

# internal include of dependencies
. "$ScriptDirectoryInc\command-handler.ps1"

CheckDependencies
# exit0

################################################################################
# Script parameters and defaults
################################################################################
# Target framework for winui projects
$TargetFrameworkWinUI = "net9.0-windows10.0.22621.0"

# Remember starting location and set baseDir to a new folder named after the solution
$startingLocation = Get-Location

$solutionPath = Join-Path -Path $startingLocation -ChildPath $SolutionName
if (-not (Test-Path $solutionPath)) {
    New-Item -ItemType Directory -Path $solutionPath | Out-Null
    Write-Debug "Created solution directory: $solutionPath"
}

# Check if solutionDirectory is empty
if ((Get-ChildItem -Path $solutionPath | Measure-Object).Count -ne 0) {
    Write-Err "The solution directory is not empty: $solutionPath"
    exit 2
}
Push-Location $solutionPath


################################################################################
# Include sourced libraries
################################################################################
. "$ScriptDirectoryInc\create-solution.ps1"

################################################################################
# Main script logic
################################################################################

Write-Header "Creating Visual Studio Solution: $SolutionName" (
    "Template: $ProjectTemplate",
    "Target Framework: $TargetFramework",
    "Solution Path: $solutionPath"
)

# Show-Help
# If user asked for help, show usage and then exit
if ($Help) {
 Show-Usage
 exit
}

# Ensure dotnet CLI or Visual Studio is available
FailIfNoDotnet

# For WinUI projects, ensure Visual Studio is available
# CheckWinUIEnvironment

# Create solution and clean architecture projects 
CreateSolution -solutionName $SolutionName -solutionPath $solutionPath
CreateSolutionDirectoryBuildProps -solutionPath $solutionPath
CreateSolutionDirectoryTargets -solutionPath $solutionPath
$projPath = CreateProjectPath -solutionPath $solutionPath
CreateCleanArchitectureProjects -solutionPath $solutionPath -targetFramework $TargetFramework

switch ($ProjectTemplate) {
    "blank" {
        Write-Info "Created blank solution: $SolutionName"
    }
    "wpf" {
        $projectType = "wpf"
        $ProjectPath = Join-Path -Path (Join-Path -Path $solutionPath -ChildPath "src") -ChildPath "WpfUI"
        $cmd = "dotnet new $projectType -n `"WpfUI`" -o `"${ProjectPath}`" -f `"$targetFramework`""
        $rc = Run $cmd
        if ($rc -ne 0) {
            Write-Warn "'dotnet new' failed for project WpfUI (rc=$rc)."
            exit 2
        }
        # Add project to solution
        $slnFile = Join-Path -Path $solutionPath -ChildPath "$($SolutionName).sln"
        $projFile = Join-Path -Path $ProjectPath -ChildPath "WpfUI.csproj"
        $added = AddProjectToSolution -slnPath $slnFile -projPath $projFile
        if (-not $added) {
            Write-Warning "Failed to add project $projName to solution."
            exit 2
        }
        Write-Info "Created WPF solution: $SolutionName"
    }
    default {
        Write-Err "Unsupported project template: $ProjectTemplate"
        exit 2
    }
}