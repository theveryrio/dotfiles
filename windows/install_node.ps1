<#
.SYNOPSIS
    Install the latest Node.js LTS via WinGet.

.DESCRIPTION
    Installs Node.js LTS using WinGet's OpenJS.NodeJS.LTS package, which always
    tracks the current Active LTS release. Requires WinGet (see install_winget.ps1).

    Run from an elevated PowerShell.

.EXAMPLE
    .\install_node.ps1
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

# A machine-scope install needs administrator rights.
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Stop-Script "Run this from an elevated PowerShell (Run as administrator)."
}

# WinGet drives the install; bail early with a pointer if it is missing.
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Stop-Script "WinGet not found. Install it first with windows\install_winget.ps1"
}

# Already installed? Nothing to do.
if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Host "Node.js is already installed: $(node --version)" -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

Invoke-Step "[1/1] Installing Node.js LTS via WinGet..." {
    # OpenJS.NodeJS.LTS always resolves to the current LTS; bundles npm.
    winget install --id OpenJS.NodeJS.LTS --exact --silent `
        --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget exited with code $LASTEXITCODE" }
}

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------

# Node lands on PATH; a fresh process may be needed to see it this session.
Write-Host ""
if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Host "Done. Node.js installed: $(node --version), npm $(npm --version)" -ForegroundColor Green
} else {
    Write-Host "Node.js installed, but not on PATH yet. Open a new terminal and run:  node --version" -ForegroundColor Yellow
}
