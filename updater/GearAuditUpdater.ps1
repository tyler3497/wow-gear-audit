<#
.SYNOPSIS
    Gear Audit updater for retail World of Warcraft (Windows).
    Downloads the latest GearAudit from GitHub and installs it into
    your WoW AddOns folder, replacing the old version.
    Personal use only. No admin rights needed unless WoW itself
    lives in a protected folder.

    Run it by double-clicking GearAuditUpdater.bat in this folder.
    That launcher runs this script with -ExecutionPolicy Bypass
    for this script only; it does not change your system policy.
#>
param()

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$RepoOwner = "tyler3497"
$RepoName  = "wow-gear-audit"
$Branch    = "main"
$RawTocUrl = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/GearAudit/GearAudit.toc"
$ZipUrl    = "https://codeload.github.com/$RepoOwner/$RepoName/zip/refs/heads/$Branch"

$SettingsDir  = Join-Path $env:APPDATA "GearAuditUpdater"
$SettingsFile = Join-Path $SettingsDir "settings.json"

# ---------------- helpers ----------------

function Write-Log {
    param([string]$Text)
    $stamp = (Get-Date).ToString("HH:mm:ss")
    $txtLog.AppendText("[$stamp] $Text`r`n")
    $txtLog.SelectionStart = $txtLog.Text.Length
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Save-Settings {
    try {
        if (-not (Test-Path $SettingsDir)) { New-Item -ItemType Directory -Path $SettingsDir -Force | Out-Null }
        @{ AddOnsPath = $txtPath.Text } | ConvertTo-Json | Set-Content -Path $SettingsFile -Encoding UTF8
    } catch { }
}

function Load-Settings {
    try {
        if (Test-Path $SettingsFile) {
            $s = Get-Content -Path $SettingsFile -Raw | ConvertFrom-Json
            if ($s.AddOnsPath) { return $s.AddOnsPath }
        }
    } catch { }
    return $null
}

function Find-AddOnsPath {
    $candidates = @()
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($base) { $candidates += (Join-Path $base "World of Warcraft\_retail_\Interface\AddOns") }
    }
    foreach ($drive in @("C:", "D:", "E:")) {
        $candidates += "$drive\World of Warcraft\_retail_\Interface\AddOns"
        $candidates += "$drive\Games\World of Warcraft\_retail_\Interface\AddOns"
        $candidates += "$drive\Program Files\World of Warcraft\_retail_\Interface\AddOns"
        $candidates += "$drive\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"
    }
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $candidates[0]
}

function Get-TocVersion {
    param([string]$TocPath)
    if (-not (Test-Path $TocPath)) { return $null }
    foreach ($line in (Get-Content -Path $TocPath)) {
        if ($line -match '^\s*##\s*Version:\s*(.+?)\s*$') { return $Matches[1] }
    }
    return $null
}

function Get-InstalledVersion {
    $toc = Join-Path $txtPath.Text "GearAudit\GearAudit.toc"
    $v = Get-TocVersion -TocPath $toc
    if ($v) { return $v } else { return "not installed" }
}

function Refresh-InstalledLabel {
    $lblInstalled.Text = "Installed: $(Get-InstalledVersion)"
}

function Get-LatestVersion {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $tocText = (Invoke-WebRequest -Uri $RawTocUrl -UseBasicParsing -TimeoutSec 30).Content
        foreach ($line in ($tocText -split "`n")) {
            if ($line -match '^\s*##\s*Version:\s*(.+?)\s*$') { return $Matches[1].Trim() }
        }
        return $null
    } catch {
        return $null
    }
}

function Check-ForUpdate {
    Write-Log "Checking GitHub for the latest version..."
    $latest = Get-LatestVersion
    if (-not $latest) {
        $lblLatest.Text = "Latest: could not reach GitHub - check your internet connection."
        $lblStatus.Text = "Status: GitHub check failed."
        Write-Log "Could not reach GitHub. Check your internet connection and try again."
        return
    }
    $lblLatest.Text = "Latest: $latest"
    $installed = Get-InstalledVersion
    if ($installed -eq "not installed") {
        $lblStatus.Text = "Status: Gear Audit is not installed yet - press Update / Install."
        Write-Log "Latest on GitHub is $latest. Gear Audit is not installed in this AddOns folder yet."
    } elseif ($installed -eq $latest) {
        $lblStatus.Text = "Status: You are up to date ($latest)."
        Write-Log "You are up to date ($latest). Nothing to install."
    } else {
        $lblStatus.Text = "Status: Update available: $installed -> $latest."
        Write-Log "Update available: $installed -> $latest."
    }
}

function Update-GearAudit {
    $addOns = $txtPath.Text.Trim()
    if (-not $addOns -or -not (Test-Path $addOns)) {
        [System.Windows.Forms.MessageBox]::Show(
            "That AddOns folder does not exist. Pick your WoW AddOns folder first (it should end in Interface\AddOns).",
            "Folder not found", "OK", "Warning") | Out-Null
        return
    }
    Save-Settings

    $wowRunning = Get-Process -Name "Wow", "WowClassic" -ErrorAction SilentlyContinue
    if ($wowRunning) {
        Write-Log "Note: WoW is running. The files will still update, but you will need /reload (or a restart) in game to load the new version."
    }

    $btnUpdate.Enabled = $false
    $btnCheck.Enabled  = $false
    try {
        $tempRoot = Join-Path $env:TEMP ("GearAuditUpdate_" + [Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        $zipPath = Join-Path $tempRoot "repo.zip"
        $extractDir = Join-Path $tempRoot "extract"
        New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

        Write-Log "Downloading the latest Gear Audit from GitHub..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $ZipUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 120
        Write-Log "Download complete. Extracting..."
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

        $newToc = Get-ChildItem -Path $extractDir -Recurse -Filter "GearAudit.toc" -ErrorAction Stop |
            Select-Object -First 1
        if (-not $newToc) { throw "Downloaded archive did not contain GearAudit.toc." }
        $newFolder = $newToc.Directory
        $newVersion = Get-TocVersion -TocPath $newToc.FullName
        Write-Log "Downloaded version: $newVersion"

        $target = Join-Path $addOns "GearAudit"
        if (Test-Path $target) {
            $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
            $backup = Join-Path $addOns "GearAudit_backup_$stamp"
            Write-Log "Backing up your old version to $backup ..."
            Move-Item -Path $target -Destination $backup
        }
        Write-Log "Installing Gear Audit $newVersion ..."
        Copy-Item -Path $newFolder.FullName -Destination $target -Recurse -Force

        $installedNow = Get-InstalledVersion
        if ($installedNow -ne $newVersion) {
            throw "Install finished but the installed version ($installedNow) does not match the downloaded version ($newVersion)."
        }
        Refresh-InstalledLabel
        $lblLatest.Text = "Latest: $newVersion"
        $lblStatus.Text = "Status: Updated to $newVersion."
        Write-Log "Done - Gear Audit $newVersion is installed."
        Write-Log "In game, use /reload (or restart WoW) if WoW was already running."
    } catch {
        $lblStatus.Text = "Status: Update failed - see the log."
        Write-Log "FAILED: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show(
            "Update failed: $($_.Exception.Message)",
            "Gear Audit Updater", "OK", "Error") | Out-Null
    } finally {
        if ($tempRoot -and (Test-Path $tempRoot)) {
            try { Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue } catch { }
        }
        $btnUpdate.Enabled = $true
        $btnCheck.Enabled  = $true
    }
}

# ---------------- window ----------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "Gear Audit Updater"
$form.Size = New-Object System.Drawing.Size(720, 520)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 28)

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "WoW AddOns folder:"
$lblPath.ForeColor = [System.Drawing.Color]::White
$lblPath.Location = New-Object System.Drawing.Point(16, 18)
$lblPath.AutoSize = $true
$form.Controls.Add($lblPath)

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(16, 40)
$txtPath.Size = New-Object System.Drawing.Size(560, 24)
$txtPath.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 46)
$txtPath.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($txtPath)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(586, 38)
$btnBrowse.Size = New-Object System.Drawing.Size(100, 28)
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Pick your WoW AddOns folder (…\Interface\AddOns)"
    $dlg.ShowNewFolderButton = $false
    if ($dlg.ShowDialog() -eq "OK") {
        $txtPath.Text = $dlg.SelectedPath
        Save-Settings
        Refresh-InstalledLabel
    }
})
$form.Controls.Add($btnBrowse)

$lblInstalled = New-Object System.Windows.Forms.Label
$lblInstalled.Text = "Installed: -"
$lblInstalled.ForeColor = [System.Drawing.Color]::White
$lblInstalled.Location = New-Object System.Drawing.Point(16, 82)
$lblInstalled.AutoSize = $true
$form.Controls.Add($lblInstalled)

$lblLatest = New-Object System.Windows.Forms.Label
$lblLatest.Text = "Latest: -"
$lblLatest.ForeColor = [System.Drawing.Color]::White
$lblLatest.Location = New-Object System.Drawing.Point(16, 106)
$lblLatest.AutoSize = $true
$form.Controls.Add($lblLatest)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Status: ready."
$lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(150, 220, 150)
$lblStatus.Location = New-Object System.Drawing.Point(16, 130)
$lblStatus.AutoSize = $true
$form.Controls.Add($lblStatus)

$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = "Check for Update"
$btnCheck.Location = New-Object System.Drawing.Point(16, 160)
$btnCheck.Size = New-Object System.Drawing.Size(160, 36)
$btnCheck.Add_Click({ Check-ForUpdate })
$form.Controls.Add($btnCheck)

$btnUpdate = New-Object System.Windows.Forms.Button
$btnUpdate.Text = "Update / Install Gear Audit"
$btnUpdate.Location = New-Object System.Drawing.Point(186, 160)
$btnUpdate.Size = New-Object System.Drawing.Size(200, 36)
$btnUpdate.Add_Click({ Update-GearAudit })
$form.Controls.Add($btnUpdate)

$btnOpen = New-Object System.Windows.Forms.Button
$btnOpen.Text = "Open AddOns Folder"
$btnOpen.Location = New-Object System.Drawing.Point(396, 160)
$btnOpen.Size = New-Object System.Drawing.Size(160, 36)
$btnOpen.Add_Click({
    if (Test-Path $txtPath.Text) { Start-Process $txtPath.Text }
})
$form.Controls.Add($btnOpen)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(16, 212)
$txtLog.Size = New-Object System.Drawing.Size(672, 250)
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 14)
$txtLog.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($txtLog)

# ---------------- start ----------------

$saved = Load-Settings
if ($saved) { $txtPath.Text = $saved } else { $txtPath.Text = Find-AddOnsPath }
Refresh-InstalledLabel
Write-Log "Gear Audit Updater ready."
Write-Log "AddOns folder: $($txtPath.Text)"
Write-Log "Checking GitHub for the latest version..."
Check-ForUpdate

[void]$form.ShowDialog()
