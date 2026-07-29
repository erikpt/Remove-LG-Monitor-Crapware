#Requires -RunAsAdministrator

<#
.SYNOPSIS
    GUI wrapper for removing LG Monitor App (any version) — provisioned
    package + all installed user instances + leftover file cleanup.

.NOTES
    Must be run as Administrator (elevation is required for
    Remove-AppxProvisionedPackage and Remove-AppxPackage -AllUsers).
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------
# Config
# ---------------------------------------------------------
$NamePattern = "LGElectronics.LGMonitorApp*"
$LogPath     = "$env:ProgramData\LGMonitorAppRemoval.log"

# ---------------------------------------------------------
# Form setup
# ---------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "LG Monitor App Remover"
$form.Size = New-Object System.Drawing.Size(560, 460)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Status label
$lblStatusHeader = New-Object System.Windows.Forms.Label
$lblStatusHeader.Text = "Status:"
$lblStatusHeader.Location = New-Object System.Drawing.Point(15, 15)
$lblStatusHeader.AutoSize = $true
$form.Controls.Add($lblStatusHeader)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Checking..."
$lblStatus.Location = New-Object System.Drawing.Point(70, 15)
$lblStatus.AutoSize = $true
$lblStatus.Font = New-Object System.Drawing.Font($lblStatus.Font, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblStatus)

# Refresh button
$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh Status"
$btnRefresh.Location = New-Object System.Drawing.Point(400, 10)
$btnRefresh.Size = New-Object System.Drawing.Size(130, 28)
$form.Controls.Add($btnRefresh)

# Uninstall button
$btnUninstall = New-Object System.Windows.Forms.Button
$btnUninstall.Text = "Uninstall LG Monitor App"
$btnUninstall.Location = New-Object System.Drawing.Point(15, 50)
$btnUninstall.Size = New-Object System.Drawing.Size(515, 36)
$btnUninstall.Enabled = $false
$btnUninstall.BackColor = [System.Drawing.Color]::IndianRed
$btnUninstall.ForeColor = [System.Drawing.Color]::White
$btnUninstall.Font = New-Object System.Drawing.Font($btnUninstall.Font, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnUninstall)

# Log label
$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Text = "Log:"
$lblLog.Location = New-Object System.Drawing.Point(15, 95)
$lblLog.AutoSize = $true
$form.Controls.Add($lblLog)

# Log display
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtLog.Location = New-Object System.Drawing.Point(15, 118)
$txtLog.Size = New-Object System.Drawing.Size(515, 280)
$form.Controls.Add($txtLog)

# Close button
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(445, 405)
$btnClose.Size = New-Object System.Drawing.Size(85, 28)
$form.Controls.Add($btnClose)

# ---------------------------------------------------------
# Helpers
# ---------------------------------------------------------
function Write-GuiLog {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $line = "[$timestamp] $Message"
    $txtLog.AppendText("$line`r`n")
    $line | Out-File -FilePath $LogPath -Append -Encoding utf8
    [System.Windows.Forms.Application]::DoEvents()
}

function Test-LGMonitorAppInstalled {
    $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like $NamePattern }
    $installed = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like $NamePattern }

    return [PSCustomObject]@{
        Provisioned = $provisioned
        Installed   = $installed
        Found       = ($provisioned -or $installed)
    }
}

function Update-StatusDisplay {
    Write-GuiLog "Checking current status..."
    $state = Test-LGMonitorAppInstalled

    if ($state.Found) {
        $lblStatus.Text = "INSTALLED"
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkRed
        $btnUninstall.Enabled = $true

        if ($state.Provisioned) {
            foreach ($p in $state.Provisioned) {
                Write-GuiLog "  Provisioned package found: $($p.PackageName)"
            }
        }
        if ($state.Installed) {
            foreach ($i in $state.Installed) {
                Write-GuiLog "  Installed package found: $($i.PackageFullName)"
            }
        }
    }
    else {
        $lblStatus.Text = "NOT INSTALLED"
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
        $btnUninstall.Enabled = $false
        Write-GuiLog "  No provisioned or installed LG Monitor App found."
    }

    return $state
}

function Remove-LGMonitorApp {
    Write-GuiLog "=== Starting removal ==="

    # 1. Deprovision
    $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like $NamePattern }

    if ($provisioned) {
        foreach ($prov in $provisioned) {
            Write-GuiLog "Deprovisioning: $($prov.PackageName)"
            try {
                Remove-AppxProvisionedPackage -PackageName $prov.PackageName -Online -ErrorAction Stop | Out-Null
                Write-GuiLog "  -> SUCCESS"
            }
            catch {
                Write-GuiLog "  -> FAILED: $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-GuiLog "No provisioned package to remove."
    }

    # 2. Remove installed instances for all users
    $installed = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like $NamePattern }

    if ($installed) {
        foreach ($pkg in $installed) {
            Write-GuiLog "Removing installed package: $($pkg.PackageFullName)"
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                Write-GuiLog "  -> SUCCESS"
            }
            catch {
                Write-GuiLog "  -> FAILED: $($_.Exception.Message) — trying per-user fallback"
                $profiles = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
                    Where-Object { -not $_.Special }
                foreach ($profile in $profiles) {
                    try {
                        Remove-AppxPackage -Package $pkg.PackageFullName -User $profile.SID -ErrorAction Stop
                        Write-GuiLog "    -> Removed for SID $($profile.SID)"
                    }
                    catch {
                        # not installed for this SID, ignore
                    }
                }
            }
        }
    }
    else {
        Write-GuiLog "No installed package to remove."
    }

    # 3. Clean up leftover folders
    $leftovers = Get-ChildItem "C:\Program Files\WindowsApps" -Directory `
        -Filter "LGElectronics.LGMonitorApp*" -ErrorAction SilentlyContinue

    foreach ($path in $leftovers) {
        Write-GuiLog "Found leftover folder: $($path.FullName)"
        try {
            takeown /F "$($path.FullName)" /R /D Y | Out-Null
            icacls "$($path.FullName)" /grant Administrators:F /T /C | Out-Null
            Remove-Item -Path $path.FullName -Recurse -Force -ErrorAction Stop
            Write-GuiLog "  -> Removed leftover folder"
        }
        catch {
            Write-GuiLog "  -> Could not remove leftover folder: $($_.Exception.Message)"
        }
    }

    Write-GuiLog "=== Removal complete ==="
}

# ---------------------------------------------------------
# Event handlers
# ---------------------------------------------------------
$btnRefresh.Add_Click({
    Update-StatusDisplay | Out-Null
})

$btnUninstall.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "This will remove LG Monitor App (provisioned + installed) for all users on this machine. Continue?",
        "Confirm Uninstall",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
        $btnUninstall.Enabled = $false
        $btnRefresh.Enabled = $false
        Remove-LGMonitorApp
        $state = Update-StatusDisplay

        if (-not $state.Found) {
            [System.Windows.Forms.MessageBox]::Show(
                "LG Monitor App has been removed successfully.",
                "Done",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        else {
            [System.Windows.Forms.MessageBox]::Show(
                "Some components could not be removed. Check the log for details.",
                "Warning",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }
        $btnRefresh.Enabled = $true
    }
})

$btnClose.Add_Click({ $form.Close() })

# ---------------------------------------------------------
# Initial load
# ---------------------------------------------------------
Write-GuiLog "LG Monitor App Remover started. Log file: $LogPath"
Update-StatusDisplay | Out-Null

[void]$form.ShowDialog()
