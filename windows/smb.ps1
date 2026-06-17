<#
.SYNOPSIS
    Interactive SMB share manager: mount and unmount network shares on a server.

.DESCRIPTION
    Lists the disk shares on a server and shows an arrow-key menu. Shares that are
    already mounted start checked (with their drive letter); unchecking one unmounts
    it, checking an unmounted share mounts it on the next free drive letter (Z -> A).

.EXAMPLE
    .\smb.ps1 192.168.1.1
#>
param(
    [Parameter(Mandatory)]
    [string]$Server
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Print an error and stop the script.
function Stop-Script([string]$Message) {
    Write-Error $Message
    exit 1
}

# Run `net use` and report success plus captured output.
function Invoke-NetUse {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    $output = net use @Arguments 2>&1
    [pscustomobject]@{
        Success = ($LASTEXITCODE -eq 0)
        Output  = $output
    }
}

# Free drive letters, Z down to A.
function Get-FreeDriveLetters {
    @([char[]](90..65) |
        ForEach-Object { [string]$_ } |
        Where-Object { -not (Test-Path "${_}:") })
}

# Map of currently mounted network drives: UNC path (lower-case) -> drive letter.
function Get-MountedShareMap {
    $map = @{}
    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=4" -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($_.ProviderName) {
                $map[$_.ProviderName.ToLower()] = $_.DeviceID.TrimEnd(':')
            }
        }
    $map
}

# Authenticate to the server and return its browsable disk-share names.
function Get-ServerShares {
    param([string]$ServerUnc, [string]$Username, [string]$Password)

    $ipc = Invoke-NetUse "$ServerUnc\IPC$" $Password /user:$Username
    if (-not $ipc.Success) {
        throw "Could not connect or authenticate to ${ServerUnc}:`n$($ipc.Output -join "`n")"
    }

    try {
        @((net view $ServerUnc /all 2>&1) |
            Where-Object { $_ -match 'Disk' } |
            ForEach-Object { ($_ -split '\s+')[0] } |
            Where-Object { -not $_.EndsWith('$') })
    }
    finally {
        Invoke-NetUse "$ServerUnc\IPC$" /delete | Out-Null
    }
}

# ---------------------------------------------------------------------------
# Interactive menu
# ---------------------------------------------------------------------------

# Render the checkbox menu and return the final checked-state array, or $null if cancelled.
function Select-Shares {
    param(
        [string[]]$Items,
        [string]$Header,
        [string[]]$MountedOn,      # parallel array: drive letter if already mounted, else $null
        [string[]]$Available       # free drive letters, Z down to A
    )

    $cursor      = 0
    $checked     = @(0..($Items.Count - 1) | ForEach-Object { [bool]$MountedOn[$_] })  # pre-check mounted shares
    $totalLines  = $Items.Count + 4   # header + blank + items + blank + hint
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

        Write-Host "  $Header" -ForegroundColor White
        Write-Host ""

        $next = 0   # pointer into $Available for the new-mount drive-letter preview
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $pointer = if ($i -eq $cursor) { ">" } else { " " }
            $box     = if ($checked[$i]) { '[x]' } else { '[ ]' }

            if ($MountedOn[$i]) {
                # Already mounted: keep (checked) or unmount (unchecked)
                if ($checked[$i]) { $suffix = "(on $($MountedOn[$i]):)";      $base = 'Green' }
                else              { $suffix = "(unmount $($MountedOn[$i]):)"; $base = 'Yellow' }
            }
            elseif ($checked[$i]) {
                # Not mounted, selected: preview the drive letter it will get
                if ($next -lt $Available.Count) { $suffix = "-> $($Available[$next]):"; $next++ }
                else                            { $suffix = "-> (no free drive)" }
                $base = 'Green'
            }
            else {
                $suffix = ""
                $base   = $null
            }

            $color = if ($i -eq $cursor) { 'Cyan' } else { $base }
            $line  = "$pointer $box $($Items[$i])   $suffix".PadRight([Console]::WindowWidth - 1)
            if ($color) { Write-Host $line -ForegroundColor $color }
            else        { Write-Host $line }
        }

        Write-Host ""
        Write-Host "  Arrow: move  Space: toggle  Enter: confirm  Esc: cancel" -ForegroundColor DarkGray
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
                'Spacebar'  { $checked[$cursor] = -not $checked[$cursor] }
                'Escape'    { return $null }
                'Enter'     { Render; return $checked }
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
# Main
# ---------------------------------------------------------------------------

# Accept the server IP / hostname only (no leading backslashes).
$Server = $Server.Trim().TrimStart('\')
if ($Server -match '\\') {
    Stop-Script "Enter the server IP/hostname only, e.g.  .\smb.ps1 192.168.1.1"
}
$ServerUnc = "\\$Server"

# The Workstation service handles network drive mapping; net use fails without it.
$ws = Get-Service LanmanWorkstation -ErrorAction SilentlyContinue
if ($ws.Status -ne 'Running') {
    Stop-Script "Workstation service (LanmanWorkstation) is not running.`nStart it from an elevated PowerShell:  Start-Service LanmanWorkstation"
}

$cred     = Get-Credential -Message "Enter credentials"
$username = $cred.UserName
$password = $cred.GetNetworkCredential().Password

# Discover shares (authenticates via IPC$).
# @() guards against PowerShell collapsing a single returned share into a scalar string.
try {
    $shares = @(Get-ServerShares -ServerUnc $ServerUnc -Username $username -Password $password)
} catch {
    Stop-Script "$_"
}
if (-not $shares) {
    Stop-Script "Connected to $ServerUnc, but no browsable disk shares were found."
}

# Current state and resources for the menu.
$mountedMap = Get-MountedShareMap
$mountedOn  = @(foreach ($s in $shares) {
    $unc = "$ServerUnc\$s".ToLower()
    if ($mountedMap.ContainsKey($unc)) { $mountedMap[$unc] } else { $null }
})
$available  = @(Get-FreeDriveLetters)

$selection = Select-Shares -Items $shares -Header "Shares on $ServerUnc" -MountedOn $mountedOn -Available $available
if ($null -eq $selection) {
    Write-Host ""
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}
$checked = @($selection)   # guard against single-element collapse, mirroring $shares

Write-Host ""

# Apply changes: compare the final checked state against the initial mounted state.
$next    = 0
$changed = $false
for ($i = 0; $i -lt $shares.Count; $i++) {
    $wasMounted = [bool]$mountedOn[$i]
    $nowChecked = $checked[$i]
    $uncPath    = "$ServerUnc\$($shares[$i])"

    if ($wasMounted -and -not $nowChecked) {
        # Unmount
        $changed = $true
        $drive   = $mountedOn[$i]
        $r = Invoke-NetUse "${drive}:" /delete /y
        if ($r.Success) { Write-Host "Unmounted: ${drive}: ($uncPath)" -ForegroundColor Yellow }
        else            { Write-Warning "Failed to unmount ${drive}:`n$($r.Output)" }
    }
    elseif (-not $wasMounted -and $nowChecked) {
        # Mount
        $changed = $true
        if ($next -ge $available.Count) {
            Write-Warning "No more drive letters available. Skipping: $uncPath"
            continue
        }
        $drive = $available[$next]; $next++
        $r = Invoke-NetUse "${drive}:" $uncPath $password /user:$username /persistent:yes
        if ($r.Success) { Write-Host "Mounted: ${drive}: -> $uncPath" -ForegroundColor Green }
        else            { Write-Warning "Failed: ${drive}: -> ${uncPath}`n$($r.Output)" }
    }
}

if (-not $changed) {
    Write-Host "No changes." -ForegroundColor DarkGray
}
