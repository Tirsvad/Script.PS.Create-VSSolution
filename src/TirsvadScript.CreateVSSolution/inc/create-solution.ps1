# Guard: this file is intended to be dot-sourced (included) by the main script.
# If executed directly, warn and exit to avoid unintended behavior.
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "This script is a library and must be dot-sourced from the main script (e.g. `. .\Create-VSSolution.ps1`). Exiting." -ForegroundColor Yellow
    exit 1
}

# Define paths for solution-level configuration files
$solutionDirectoryBuildPropsDestPath = Join-Path -Path $solutionPath -ChildPath "Directory.Build.props"
$solutionDirectoryBuildPropsSourcePath = Join-Path -Path $ScriptDirectoryInc -ChildPath "templates\Directory.Build.props"
$solutionDirectoryBuildTargetsDestPath = Join-Path -Path $solutionPath -ChildPath "Directory.Build.targets"
$solutionDirectoryBuildTargetsSourcePath = Join-Path -Path $ScriptDirectoryInc -ChildPath "templates\Directory.Build.targets"

function CreateSolution {
    param (
        [string]$solutionName,
        [string]$solutionPath
    )
    $cmd = "dotnet new sln -n `"$solutionName`" -o `"$solutionPath`""
    Write-Run "Command: $cmd"
    $rc = Run $cmd
    if ($rc -ne 0) {
        Write-RunDone $false
        Write-Err "'dotnet new sln' failed (rc=$rc)."
        exit 2
    }
    Write-RunDone $true
}

# TODO : implement Directory.Build.props content as needed

function CreateSolutionDirectoryBuildProps {
    param (
        [string]$solutionPath
    )
    $slnDir = Get-Item $solutionPath
    $slnPropFile = Join-Path $slnDir.FullName "Directory.Build.props"
    Write-Debug "Creating Directory.Build.props at: $slnPropFile"
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