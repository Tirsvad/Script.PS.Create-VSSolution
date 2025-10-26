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

