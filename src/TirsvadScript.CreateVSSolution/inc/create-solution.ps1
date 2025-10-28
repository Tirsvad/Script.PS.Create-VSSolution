# Guard: this file is intended to be dot-sourced (included) by the main script.
# If executed directly, warn and exit to avoid unintended behavior.
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "This script is a library and must be dot-sourced from the main script (e.g. `. .\Create-VSSolution.ps1`). Exiting." -ForegroundColor Yellow
    exit 1
}

# Define paths for solution-level configuration files
$solutionDirectoryBuildPropsDestPath = Join-Path -Path $solutionPath -ChildPath "Directory.Build.props"
$solutionDirectoryBuildPropsSourcePath = Join-Path -Path $ScriptDirectoryTemplates -ChildPath "solution/Directory.Build.props"
$solutionDirectoryBuildTargetsDestPath = Join-Path -Path $solutionPath -ChildPath "Directory.Build.targets"
$solutionDirectoryBuildTargetsSourcePath = Join-Path -Path $ScriptDirectoryTemplates -ChildPath "solution/Directory.Build.targets"

function CreateSolution {
    param (
        [string]$solutionName,
        [string]$solutionPath
    )
    Write-Info "Creating solution '$solutionName' at path: $solutionPath"
    $cmd = "dotnet new sln -n `"$solutionName`" -o `"$solutionPath`""
    $rc = Run $cmd
    if ($rc -ne 0) {
        Write-Err "'dotnet new sln' failed (rc=$rc)."
        exit 2
    }
}

# TODO : implement Directory.Build.props content as needed

function CreateSolutionDirectoryBuildProps {
    param (
        [string]$solutionPath
    )
    $rc = Run "Copy-Item -Path `"$solutionDirectoryBuildPropsSourcePath`" -Destination `"$solutionDirectoryBuildPropsDestPath`" -Force"
}

function CreateSolutionDirectoryTargets {
    param (
        [string]$solutionPath
    )
    $rc = Run "Copy-Item -Path `"$solutionDirectoryBuildTargetsSourcePath`" -Destination `"$solutionDirectoryBuildTargetsDestPath`" -Force"
}

# Helper to add a project to a specific solution and verify
function AddProjectToSolution {
    param (
        [string]$slnPath,
        [string]$projPath
    )

    if (-not (Test-Path $slnPath)) {
        Write-Warn "Solution file not found: $slnPath"
        return $false
    }
    if (-not (Test-Path $projPath)) {
        Write-Warn "Project file not found: $projPath"
        return $false
    }

    Write-Debug "Adding project to solution: $projPath -> $slnPath"
    & dotnet sln $slnPath add $projPath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "dotnet sln add failed with exit code $LASTEXITCODE"
        return $false
    }
    return $true
}