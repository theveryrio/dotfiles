<#
.SYNOPSIS
    Install the Chocolatey package manager.

.DESCRIPTION
    Installs Chocolatey by running the official install script from
    community.chocolatey.org: relax the process execution policy, enable TLS 1.2,
    then download and run install.ps1.

    Run from an elevated PowerShell.

.EXAMPLE
    .\install_chocolatey.ps1
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

# Chocolatey installs into C:\ProgramData and needs administrator rights.
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Stop-Script "Run this from an elevated PowerShell (Run as administrator)."
}

# The install script targets PowerShell 5.1+.
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Stop-Script "PowerShell 5.1 or later is required (found $($PSVersionTable.PSVersion))."
}

# Already installed? Nothing to do.
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "Chocolatey is already installed: $(choco --version)" -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

Invoke-Step "[1/2] Preparing session (execution policy + TLS 1.2)..." {
    # Allow the downloaded install script to run for this process only.
    Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
    # TLS 1.2 is required to reach community.chocolatey.org on older defaults.
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

Invoke-Step "[2/2] Downloading and running the Chocolatey install script..." {
    $script = (New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
    Invoke-Expression $script
}

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------

# choco lands on PATH; a fresh process may be needed to see it this session.
Write-Host ""
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "Done. Chocolatey installed: $(choco --version)" -ForegroundColor Green
} else {
    Write-Host "Chocolatey installed, but not on PATH yet. Open a new terminal and run:  choco --version" -ForegroundColor Yellow
}
