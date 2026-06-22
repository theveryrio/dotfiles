<#
.SYNOPSIS
    Interactive WSL distribution installer.

.DESCRIPTION
    Lists every distribution that "wsl --list --online" offers, grouped by
    distribution family (Ubuntu, Debian, ...), and shows an arrow-key menu.
    Move with the arrows and press Enter to install the highlighted release.
    Already-installed distributions are marked "(installed)"; selecting one
    instead removes it (wsl --unregister) after a confirmation, which
    permanently deletes the distribution and all of its data.

    Run from an elevated PowerShell. A reboot may be required the first time
    WSL is enabled.

.EXAMPLE
    .\install_wsl.ps1
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

# Whether the WSL platform itself is installed (not just the wsl.exe stub).
# Without it, even "wsl --list --online" fails, so this must be checked first.
function Test-WslInstalled {
    # 2>&1 swallows the (UTF-16, garbled) "not installed" message; we only need
    # the exit code: 0 when WSL is present, non-zero (e.g. 50) when it is not.
    $null = wsl.exe --status 2>&1
    return ($LASTEXITCODE -eq 0)
}

# Names of the distributions that are already installed (lower-case set).
function Get-InstalledDistros {
    $set = @{}
    try {
        $out = wsl.exe --list --quiet
        if ($LASTEXITCODE -eq 0) {
            foreach ($line in $out) {
                $name = ($line -replace "`0", "").Trim()
                if ($name) { $set[$name.ToLower()] = $true }
            }
        }
    } catch { }
    $set
}

# Parse "wsl --list --online" into objects: Name, Friendly, Group, Installed.
function Get-OnlineDistros {
    $installed = Get-InstalledDistros

    $rows = @()
    foreach ($raw in (wsl.exe --list --online)) {
        $line = ($raw -replace "`0", "").TrimEnd()
        if (-not $line) { continue }

        # Real distro rows are "NAME<2+ spaces>FRIENDLY NAME". The intro text uses
        # single spaces, so it collapses to one field and is skipped; so is the
        # "NAME / FRIENDLY NAME" header row, filtered by name below.
        $parts = $line.Trim() -split '\s{2,}', 2
        if ($parts.Count -lt 2) { continue }

        $name = $parts[0].Trim()
        if ($name -eq 'NAME' -or $name -notmatch '^[A-Za-z]') { continue }

        $rows += [pscustomobject]@{
            Name      = $name
            Friendly  = $parts[1].Trim()
            # Group key: the family prefix before the first version separator.
            Group     = ($name -split '[-_]', 2)[0]
            Installed = $installed.ContainsKey($name.ToLower())
        }
    }
    $rows
}

# ---------------------------------------------------------------------------
# Interactive menu
# ---------------------------------------------------------------------------

# Render the grouped single-select menu and return the chosen item, or $null if cancelled.
function Select-Distro {
    param(
        [pscustomobject[]]$Items,   # Name / Friendly / Group / Installed
        [string]$Header
    )

    # Build the render model: a group header line followed by its item rows,
    # in first-seen order. Only item rows are selectable.
    $entries = @()                  # each: @{ Type='header'/'item'; Text=...; ItemIndex=... }
    $seen    = @{}
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $g = $Items[$i].Group
        if (-not $seen.ContainsKey($g)) {
            $seen[$g] = $true
            $entries += @{ Type = 'header'; Text = $g }
        }
        $entries += @{ Type = 'item'; ItemIndex = $i }
    }

    $nameWidth  = ($Items.Name | Measure-Object -Maximum -Property Length).Maximum
    $cursor     = 0
    $totalLines = $entries.Count + 4   # header + blank + entries + blank + hint
    $script:menuRendered = $false

    function Render {
        [Console]::CursorVisible = $false
        # Move cursor back up to the menu start (relative move = scroll-safe).
        if ($script:menuRendered) {
            $pos   = $Host.UI.RawUI.CursorPosition
            $pos.Y = [Math]::Max(0, $pos.Y - $totalLines)
            $Host.UI.RawUI.CursorPosition = $pos
        }
        $script:menuRendered = $true

        Write-Host ("  $Header".PadRight([Console]::WindowWidth - 1)) -ForegroundColor White
        Write-Host ("".PadRight([Console]::WindowWidth - 1))

        foreach ($e in $entries) {
            if ($e.Type -eq 'header') {
                # Family header in dark cyan, kept distinct from the green cursor row.
                $line = "  $($e.Text)".PadRight([Console]::WindowWidth - 1)
                Write-Host $line -ForegroundColor DarkCyan
                continue
            }

            $i       = $e.ItemIndex
            $it      = $Items[$i]
            $pointer = if ($i -eq $cursor) { ">" } else { " " }
            $suffix  = if ($it.Installed) { "(installed)" } else { "" }
            $name    = $it.Name.PadRight($nameWidth)
            $line    = "   $pointer $name   $($it.Friendly) $suffix".PadRight([Console]::WindowWidth - 1)

            # Cursor row: red when it sits on an installed distro (Enter removes it),
            # green otherwise (Enter installs). Non-cursor installed rows stay dim.
            $color = if ($i -eq $cursor) {
                        if ($it.Installed) { 'Red' } else { 'Green' }
                     } elseif ($it.Installed) { 'DarkGray' } else { $null }
            if ($color) { Write-Host $line -ForegroundColor $color }
            else        { Write-Host $line }
        }

        # Enter installs a new distro, or removes the one under the cursor if it is
        # already installed; reflect that in the hint.
        $action = if ($Items[$cursor].Installed) { "Enter: remove" } else { "Enter: install" }
        Write-Host ("".PadRight([Console]::WindowWidth - 1))
        Write-Host ("  Arrow: move  $action  Esc: cancel".PadRight([Console]::WindowWidth - 1)) -ForegroundColor DarkGray
        [Console]::CursorVisible = $true
    }

    $prevCtrlC = [Console]::TreatControlCAsInput
    try {
        # Capture Ctrl+C as a normal key instead of terminating the script.
        [Console]::TreatControlCAsInput = $true
        Render

        while ($true) {
            $key = [Console]::ReadKey($true)

            # Ctrl+C cancels, same as Esc.
            if (($key.Modifiers -band [ConsoleModifiers]::Control) -and $key.Key -eq 'C') {
                return $null
            }

            switch ($key.Key) {
                'UpArrow'   { if ($cursor -gt 0) { $cursor-- } }
                'DownArrow' { if ($cursor -lt $Items.Count - 1) { $cursor++ } }
                'Escape'    { return $null }
                'Enter'     { Render; return $Items[$cursor] }
            }

            Render
        }
    }
    finally {
        # Always restore terminal state, however we leave the menu.
        [Console]::CursorVisible = $true
        [Console]::TreatControlCAsInput = $prevCtrlC
    }
}

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------

# Enabling WSL features and installing a distribution both need admin rights.
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Stop-Script "Run this from an elevated PowerShell (Run as administrator)."
}

# The modern "wsl --install" flow targets PowerShell 5.1+.
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Stop-Script "PowerShell 5.1 or later is required (found $($PSVersionTable.PSVersion))."
}

# The wsl.exe command ships with Windows 10 2004+ and Windows 11.
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Stop-Script "wsl.exe was not found. This script needs Windows 10 (2004+) or Windows 11."
}

# Make wsl.exe emit UTF-8 so its output parses cleanly (default is UTF-16).
$env:WSL_UTF8 = "1"

# ---------------------------------------------------------------------------
# Install the WSL platform first if it is missing
# ---------------------------------------------------------------------------

# Without the WSL platform, even listing online distributions fails, so install
# it (no distribution yet) and stop: enabling WSL needs a reboot to take effect.
if (-not (Test-WslInstalled)) {
    Invoke-Step "WSL is not installed. Installing the WSL platform..." {
        wsl.exe --install --no-distribution
        if ($LASTEXITCODE -ne 0) {
            Stop-Script "wsl --install exited with code $LASTEXITCODE."
        }
    }
    Write-Host ""
    Write-Host "WSL platform installed. Reboot, then re-run this script to pick a distribution." -ForegroundColor Yellow
    exit 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# @() guards against PowerShell collapsing a single returned row into a scalar.
$distros = @(Get-OnlineDistros)
if (-not $distros) {
    Stop-Script "No installable distributions were returned by 'wsl --list --online'.`nCheck your internet connection and try again."
}

$choice = Select-Distro -Items $distros -Header "Select a WSL distribution (Enter installs, or removes if installed)"
if ($null -eq $choice) {
    Write-Host ""
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# ---------------------------------------------------------------------------
# Remove: selecting an already-installed distribution unregisters it
# ---------------------------------------------------------------------------

if ($choice.Installed) {
    Write-Host "WARNING: this permanently deletes $($choice.Name) and ALL its data" -ForegroundColor Red
    Write-Host "(files, installed packages, the whole Linux filesystem). This cannot be undone." -ForegroundColor Red
    $answer = Read-Host "Remove it? Type 'y' to confirm"
    if ($answer -ne 'y') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }

    Invoke-Step "Removing $($choice.Name)..." {
        wsl.exe --unregister $choice.Name
        if ($LASTEXITCODE -ne 0) {
            Stop-Script "wsl --unregister exited with code $LASTEXITCODE."
        }
    }

    Write-Host ""
    if ((Get-InstalledDistros).ContainsKey($choice.Name.ToLower())) {
        Write-Host "$($choice.Name) is still listed; removal may not have completed." -ForegroundColor Yellow
    } else {
        Write-Host "Done. $($choice.Name) removed." -ForegroundColor Green
        # --unregister wipes the distro data but leaves its launcher app installed;
        # remove that too for a fully clean state if you no longer want it.
        Write-Host "Its launcher app may remain; uninstall it from Settings > Apps if you want it fully gone." -ForegroundColor DarkGray
    }
    exit 0
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

Invoke-Step "Installing $($choice.Name) ($($choice.Friendly))..." {
    # --no-launch installs without dropping into the new distro's first-run setup;
    # the user can launch it later to create their UNIX account.
    wsl.exe --install -d $choice.Name --no-launch
    if ($LASTEXITCODE -ne 0) {
        Stop-Script "wsl --install exited with code $LASTEXITCODE."
    }
}

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------

Write-Host ""
if ((Get-InstalledDistros).ContainsKey($choice.Name.ToLower())) {
    Write-Host "Done. $($choice.Name) installed. Launch it with:  wsl -d $($choice.Name)" -ForegroundColor Green
} else {
    Write-Host "$($choice.Name) install started. A reboot may be required to finish enabling WSL." -ForegroundColor Yellow
    Write-Host "After rebooting, re-run this script or launch:  wsl -d $($choice.Name)" -ForegroundColor Yellow
}
