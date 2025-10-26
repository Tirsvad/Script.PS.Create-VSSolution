# Contributing to VSSolution Creation Script

Thank you for your interest in contributing! Your help is greatly appreciated.  
This document outlines the process for contributing to the project.

## Coding Guidelines

This project uses PowerShell for scripting. Follow these PowerShell-specific guidelines:

- Follow PowerShell best practices and the PowerShell Style Guidelines.
- Use approved verbs for functions (see `Get-Verb`) and choose clear, descriptive function names.
- Prefer advanced functions with `CmdletBinding()` so common parameters and `-Verbose`/`-Debug` are available.
- Use strong typing and parameter validation attributes (`[Parameter()]`, `ValidateSet`, `ValidateNotNullOrEmpty`, etc.).
- Support pipeline input for functions where appropriate and implement `Begin/Process/End` blocks when processing pipeline input.
- Provide comment-based help for all public functions and scripts (examples, parameters, outputs).
- Avoid aliases and use full cmdlet names in committed code (aliases are fine interactively).
- Use `ShouldProcess`/`-WhatIf` for destructive operations and honor `-Confirm` when appropriate.
- Use `Try/Catch` for error handling and throw or `Write-Error` as appropriate; prefer terminating errors when callers must act on failures.
- Use `Write-Verbose`, `Write-Debug`, `Write-Warning`, and `Write-Error` for structured output and logging; do not write unstructured progress to stdout.
- Keep formatting consistent (4-space indentation is recommended), avoid global variables, and keep functions focused and small.
- Use `PSScriptAnalyzer` to lint scripts and address reported issues. Include a baseline or configuration if needed.
- Organize modules with a `.psm1` and `.psd1` manifest; explicitly export public functions with `Export-ModuleMember`.
- Write unit tests with `Pester` and place tests under a `tests/` folder. Run tests locally and in CI.
- Avoid hard-coded credentials/secrets; use secure methods (secure strings, environment variables, or secret stores).
- Use semantic versioning for modules and include a changelog for releases.

## How Can I Contribute?

### Reporting Bugs

- Open an issue on [GitHub Issues](https://github.com/Tirsvad/Script.PS.Create-VSSolution/issues).
- Use a clear and descriptive title.
- Include steps to reproduce, expected and actual behavior, and environment details.

### Suggesting Enhancements

- Open an issue and label it as an enhancement.
- Clearly describe the feature, why it would be useful, and any ideas for implementation.

### Pull Requests

1. **Fork the repository** and clone it locally.
2. **Create a new branch** for your feature or fix
```
git checkout -b feature/YourFeatureName
```

3. **Make your changes** with clear, concise commits.
4. **Write or update tests** as needed.
5. **Ensure all tests pass** before submitting.
6. **Push to your fork** and submit a pull request to the `main` branch.
7. **Describe your changes** in the pull request and reference any related issues.

### Code Style

- Follow the existing code style and conventions.
- Use meaningful names and XML documentation where appropriate.
- Keep methods and classes focused and concise.

### Commit Messages

- Use clear, descriptive commit messages.
- Reference issues or pull requests when relevant.

## Code of Conduct

Please be respectful and considerate in all interactions.  
See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Questions?

Open an issue or contact the maintainer via [LinkedIn](https://www.linkedin.com/in/jens-tirsvad-nielsen-13b795b9/).

---
Thank you for helping make TirsvadWeb.JwtAuth better!