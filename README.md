[![downloads][downloads-shield]][downloads-url] [![Contributors][contributors-shield]][contributors-url] [![Forks][forks-shield]][forks-url] [![Stargazers][stars-shield]][stars-url] [![Issues][issues-shield]][issues-url] [![License][license-shield]][license-url] [![LinkedIn][linkedin-shield]][linkedin-url]

# ![Logo][Logo] Create VSSolution File - Clean Architecture
Create a solution file for Visual Studio with a clean architecture.

[![Screenshot1][screenshot1]][screenshot1-url]

## Overview
This PowerShell script automates the creation of a Visual Studio solution structure with multiple projects, including a UI project (WPF, WinUI, or MAUI) and associated class libraries. It sets up a standard folder layout and configures project references.
The script is designed to streamline the initial setup of a .NET solution, saving time and ensuring consistency across projects.

## Features
- Creates a solution folder with a `src` subfolder.
- Generates three class library projects: `Domain`, `Core`, and `Infrastructure`.
- Generates a UI project based on user selection (WPF).

## Quick Start

### Prerequisites
- .NET SDK installed and `dotnet` available on PATH.

### Installation


## Make `Create-VSSolution.ps1` available globally
There are a few simple options to make the script available from any location. This repository includes an installer script `install.ps1` that automates common steps.

Quick installer examples

- Install (default): add `%USERPROFILE%\Scripts` to your user PATH. If you run `install.ps1` with no action flags it will default to `-AddToPath` (and currently also sets the `-CreateProfileFunction` flag by default).

 `.\install.ps1` or from repo root:
 `.\install.ps1` (adjust path as needed)

- Install + request a wrapper function to be added to your PowerShell profile (note: the installer exposes `-CreateProfileFunction`, but the current implementation does not create the wrapper automatically):

 `.\install.ps1 -AddToPath -CreateProfileFunction`

- Install as a simple PowerShell module:

 `.\install.ps1 -AsModule`

- Remove everything added by the installer (script, shim entry removal logic, module, PATH entry, and profile wrapper removal logic):

 `.\install.ps1 -Delete`

Notes about what the installer does (current behavior)

- Default behavior: when called without action switches the installer will perform `-AddToPath`. The script also sets `-CreateProfileFunction` by default in the parameter handling, but the wrapper creation is not implemented in the current script.
- It copies `Create-VSSolution.ps1` into the install folder (default: `%USERPROFILE%\Scripts`) when the source script is available in the repository.
- The installer exposes flags and removal logic for a `Create-VSSolution.cmd` shim and a PowerShell profile wrapper. However, the current implementation does not create the shim or the profile wrapper; the `-Delete` and `-DeleteProfileFunction` flags attempt to remove wrapper/shim artifacts if they already exist.
- It can install the script as a minimal PowerShell module under `%USERPROFILE%\Documents\PowerShell\Modules\Create-VSSolution\` when `-AsModule` is used.
- It supports `-Force` to overwrite existing files without prompting (when the copy logic runs it respects `-Force`).
- The installer has a `-VerboseMode` parameter controlling informational output (numeric verbosity levels).

Using the wrapper or shim

- PowerShell wrapper: if you add a wrapper to your profile manually, reload your profile (`. $PROFILE`) or restart PowerShell, then run:

 `Create-VSSolution`

- CMD/shim: if you create a shim manually and add the install folder to your PATH you can run from any shell:

 `Create-VSSolution`

Troubleshooting and environment

- If you downloaded the script from the internet, unblock it first:
 `Unblock-File .\Create-VSSolution.ps1`
- Ensure execution policy allows running scripts:
 `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`
- If PATH changes don't appear in an open shell, either restart the shell or add the folder to the session manually:
 `$env:Path += ';' + "$env:USERPROFILE\Scripts"`

## Adjusting the Target Framework Moniker (TFM)
The projects created by the script use a default TFM. To change the TFM (for example from `net6.0` to `net7.0`), you have several options:

1. Edit the script before running
- Open `src\Create-VSSolution.ps1` and look for the variable that sets the TFM (commonly something like `$TFM = 'net6.0'`). Change it to the desired TFM (for example `'net7.0'`).

2. Use the `-f` / `--framework` option when using `dotnet new` directly
- When creating projects manually, pass the framework to the template: `dotnet new classlib -f net7.0 -o MyLib`.

3. Change TFMs for generated projects after creation (bulk replace)
- Run a PowerShell replace over the generated project files. Example to replace `net6.0` with `net7.0`:

 `Get-ChildItem -Path . -Recurse -Filter *.csproj | ForEach-Object { (Get-Content $_.FullName) -replace 'net6.0', 'net7.0' | Set-Content $_.FullName }
`

- Alternatively, use `sed`/`perl` or an editor to update the `<TargetFramework>` element in each `.csproj`.

Notes
- Ensure all referenced libraries and NuGet packages support the target TFM you choose.
- After changing TFMs, run `dotnet restore` and `dotnet build` to validate everything compiles.

## How to use `Create-VSSolution.ps1`

The generator script is located at `src\Create-VSSolution.ps1`. You can run it directly from the repository or after installing it with `install.ps1`.

Prerequisites

- .NET SDK installed and `dotnet` available on PATH.
- On Windows, additional templates may be required for WPF/WinUI projects (Windows App SDK / WinUI templates).
- Ensure execution policy allows running local scripts: `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`.

Run the script directly (no install)

- From the repository root:

 `& "Create-VSSolution.ps1" -SolutionName MyApp -ProjectType wpf`

- From the `src` folder:

 `& ".\src\Create-VSSolution.ps1" -SolutionName MyApp -ProjectType wpf`

Installed usage (recommended)

- If you used `install.ps1 -AddToPath` (the default installer behavior), you can run the installed script after adding `\Scripts` folder to PATH:

 `Create-VSSolution -SolutionName MyApp -ProjectType wpf`

- If you prefer a cross-shell command and create a shim manually in the install folder, the shim would let you call the same `Create-VSSolution` command from cmd.exe or other shells once the install folder is on PATH.

Parameters for `install.ps1`

- `-InstallPath` (default: `%USERPROFILE%\\Scripts`): Destination folder for the script and any shims.
- `-AddToPath`: Add `InstallPath` to the user's PATH environment variable.
- `-CreateProfileFunction`: Flag exposed by the installer to request a wrapper function in the PowerShell profile (currently not implemented).
- `-DeleteProfileFunction`: Flag to remove a profile wrapper if present.
- `-Delete`: Remove installed script, module folder, PATH entry and profile wrapper lines (best-effort removal behavior).
- `-AsModule`: Install `Create-VSSolution.ps1` as a simple PowerShell module under `Documents\PowerShell\Modules\Create-VSSolution`.
- `-Force`: Overwrite existing files without prompting when copying.
- `-VerboseMode`: Numeric verbosity level for installer output (0..n).

Examples

- Add the scripts folder to user PATH (default behavior when called with no action switches):
 `.\install.ps1`

- Install as a module (overwrite existing module files if needed):
 `.\install.ps1 -AsModule -Force`

Notes

- The script uses `net8.0` by default for generated projects. Edit `src\Create-VSSolution.ps1` to change the TFM.
- After installing with `-CreateProfileFunction` (once wrapper creation is implemented), reload your profile (`. $PROFILE`) or restart PowerShell to use the wrapper immediately.

Troubleshooting

- If a `dotnet new` template fails, install the required SDKs/templates and restart your shell.
- If commands still fail due to script blocking, run `Unblock-File` on the script and set an appropriate execution policy.

## Contributing
Contributions are welcome. Please follow the guidelines in `CONTRIBUTING.md` and open issues or pull requests.

See [CONTRIBUTING.md](CONTRIBUTING.md)

## Reporting Bugs
1. Go to the Issues page: [GitHub Issues][githubIssue-url]
2. Click "New Issue" and provide steps to reproduce, expected behavior, actual behavior, environment, and attachments (logs/screenshots).

## License
Distributed under the AGPL-3.0 License. See [LICENSE.txt](LICENSE.txt) or [license link][license-url].

## Contact
Jens Tirsvad Nielsen - [LinkedIn][linkedin-url]

## Acknowledgments
Thanks to contributors and the open-source community.

<!-- MARKDOWN LINKS & IMAGES -->
[contributors-shield]: https://img.shields.io/github/contributors/Tirsvad/Script.PS.Create-VSSolution?style=for-the-badge
[contributors-url]: https://github.com/Tirsvad/Script.PS.Create-VSSolution/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/Tirsvad/Script.PS.Create-VSSolution?style=for-the-badge
[forks-url]: https://github.com/Tirsvad/Script.PS.Create-VSSolution/network/members
[stars-shield]: https://img.shields.io/github/stars/Tirsvad/Script.PS.Create-VSSolution?style=for-the-badge
[stars-url]: https://github.com/Tirsvad/Script.PS.Create-VSSolution/stargazers
[issues-shield]: https://img.shields.io/github/issues/Tirsvad/Script.PS.Create-VSSolution?style=for-the-badge
[issues-url]: https://github.com/Tirsvad/Script.PS.Create-VSSolution/issues
[license-shield]: https://img.shields.io/github/license/Tirsvad/Script.PS.Create-VSSolution?style=for-the-badge
[license-url]: https://github.com/Tirsvad/Script.PS.Create-VSSolution/blob/master/LICENSE.txt
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://www.linkedin.com/in/jens-tirsvad-nielsen-13b795b9/
[githubIssue-url]: https://github.com/Tirsvad/Script.PS.Create-VSSolution/issues/
[logo]: https://raw.githubusercontent.com/Tirsvad/Script.PS.Create-VSSolution/main/images/logo/32x32/logo.png


[downloads-shield]: https://img.shields.io/github/downloads/Tirsvad/Script.PS.Create-VSSolution/total?style=for-the-badge
[downloads-url]: https://github.com/Tirsvad/Script.PS.Create-VSSolution/releases

<!-- screenshots -->
[screenshot1]: https://raw.githubusercontent.com/Tirsvad/Script.PS.Create-VSSolution/main/images/small/ScreenshotSolutionExplore1.jpg
[screenshot1-url]: https://raw.githubusercontent.com/Tirsvad/Script.PS.Create-VSSolution/main/images/ScreenshotSolutionExplore1.png
