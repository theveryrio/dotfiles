<#
.SYNOPSIS
    Install WinGet without the Microsoft Store.

.DESCRIPTION
    Installs WinGet (App Installer) from PowerShell Gallery, for machines that
    lack the Microsoft Store: register the NuGet provider, install the official
    Microsoft.WinGet.Client module, then let Repair-WinGetPackageManager pull
    down WinGet and its dependencies.

    Run from an elevated PowerShell.

.EXAMPLE
    .\winget.ps1
#>

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Print an error and stop the script.
function Stop-Script([string]$Message) {
    Write-Error $Message
    exit 1
}

# Run a labelled install step, stopping the script with context on failure.
function Invoke-Step {
    param([string]$Label, [scriptblock]$Action)
    Write-Host $Label -ForegroundColor Cyan
    try   { & $Action }
    catch { Stop-Script "$Label`n$_" }
}

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------

# Module installs and dependency repair both need administrator rights.
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Stop-Script "Run this from an elevated PowerShell (Run as administrator)."
}

# Repair-WinGetPackageManager is only available on PowerShell 5.1+.
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Stop-Script "PowerShell 5.1 or later is required (found $($PSVersionTable.PSVersion))."
}

# Already installed? Nothing to do.
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "WinGet is already installed: $(winget --version)" -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

# TLS 1.2 is required to reach PowerShell Gallery on older defaults.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Invoke-Step "[1/3] Installing NuGet package provider..." {
    Install-PackageProvider -Name NuGet -Force -ErrorAction Stop | Out-Null
}

Invoke-Step "[2/3] Installing Microsoft.WinGet.Client module..." {
    # Trust PSGallery so the install runs without an interactive prompt.
    if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -ErrorAction Stop
}

Invoke-Step "[3/3] Building and installing WinGet and dependencies..." {
    Repair-WinGetPackageManager -Latest -Force -ErrorAction Stop
}

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------

# winget lands on PATH; a fresh process may be needed to see it this session.
Write-Host ""
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Done. WinGet installed: $(winget --version)" -ForegroundColor Green
} else {
    Write-Host "WinGet installed, but not on PATH yet. Open a new terminal and run:  winget --version" -ForegroundColor Yellow
}
