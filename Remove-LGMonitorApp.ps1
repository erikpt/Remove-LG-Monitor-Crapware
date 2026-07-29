#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Nukes LG Monitor App — provisioned package, all installed user instances,
    and leftover files/registry traces. Version-agnostic.
#>

$NamePattern = "LGElectronics.LGMonitorApp*"
$LogPath = "$env:ProgramData\LGMonitorAppRemoval.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp - $Message"
    Write-Host $line
    $line | Out-File -FilePath $LogPath -Append -Encoding utf8
}

Write-Log "=== Starting LG Monitor App removal ==="

# ---------------------------------------------------------
# 1. Remove provisioned package (stops it reinstalling for new profiles)
# ---------------------------------------------------------
$provisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $NamePattern }

if ($provisioned) {
    foreach ($prov in $provisioned) {
        Write-Log "Deprovisioning: $($prov.PackageName)"
        try {
            Remove-AppxProvisionedPackage -PackageName $prov.PackageName -Online -ErrorAction Stop | Out-Null
            Write-Log "  -> SUCCESS"
        }
        catch {
            Write-Log "  -> FAILED: $($_.Exception.Message)"
        }
    }
}
else {
    Write-Log "No provisioned package found (already clean or not present)."
}

# ---------------------------------------------------------
# 2. Remove installed package for every user profile on the box
# ---------------------------------------------------------
$installed = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $NamePattern }

if ($installed) {
    foreach ($pkg in $installed) {
        Write-Log "Removing installed package: $($pkg.PackageFullName)"
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
            Write-Log "  -> SUCCESS"
        }
        catch {
            Write-Log "  -> FAILED: $($_.Exception.Message) — attempting per-user removal"
            # Fallback: try removing per-user SID if -AllUsers fails (e.g. package in odd state)
            Get-ChildItem "HKU:\" -ErrorAction SilentlyContinue | Out-Null
            if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
                New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
            }
            foreach ($profile in (Get-CimInstance Win32_UserProfile | Where-Object { -not $_.Special })) {
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -User $profile.SID -ErrorAction Stop
                    Write-Log "  -> Removed for SID $($profile.SID)"
                }
                catch {
                    # Not installed for this SID, ignore
                }
            }
        }
    }
}
else {
    Write-Log "No installed package found for any user."
}

# ---------------------------------------------------------
# 3. Verify and clean leftover files (belt and suspenders)
# ---------------------------------------------------------
$leftoverPaths = Get-ChildItem "C:\Program Files\WindowsApps" -Directory -Filter "LGElectronics.LGMonitorApp*" -ErrorAction SilentlyContinue

foreach ($path in $leftoverPaths) {
    Write-Log "Found leftover folder: $($path.FullName) — attempting cleanup"
    try {
        takeown /F "$($path.FullName)" /R /D Y | Out-Null
        icacls "$($path.FullName)" /grant Administrators:F /T /C | Out-Null
        Remove-Item -Path $path.FullName -Recurse -Force -ErrorAction Stop
        Write-Log "  -> Removed leftover folder"
    }
    catch {
        Write-Log "  -> Could not remove leftover folder: $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------
# 4. Final verification
# ---------------------------------------------------------
$stillProvisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $NamePattern }
$stillInstalled = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $NamePattern }

if (-not $stillProvisioned -and -not $stillInstalled) {
    Write-Log "VERIFIED CLEAN: No provisioned or installed LG Monitor App remains."
}
else {
    Write-Log "WARNING: LG Monitor App still detected after cleanup attempt. Manual review needed."
    if ($stillProvisioned) { Write-Log "  Still provisioned: $($stillProvisioned.PackageName -join ', ')" }
    if ($stillInstalled)   { Write-Log "  Still installed: $($stillInstalled.PackageFullName -join ', ')" }
}

Write-Log "=== Removal script complete ==="