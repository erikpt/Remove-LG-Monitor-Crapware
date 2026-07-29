# LG Monitor App Remover

A pair of PowerShell scripts for completely uninstalling **LG Monitor App** (any version) from a Windows machine — including the provisioned package, all per-user installed instances, and leftover files in `WindowsApps` that a normal uninstall often leaves behind.

> **Why this matters right now:** This tool was put together in response to Gamers Nexus's recent investigation, [*"DO NOT BUY: LG's Spyware TVs, Monitors, and Wiretapping Concerns"*](https://www.youtube.com/watch?v=Q9uefFYe6bM), which found that the LG Monitor App Installer gets silently pushed to PCs through Windows Update as soon as an LG monitor is plugged in — no prompt, no consent — and then serves McAfee "free trial" pop-ups on nearly every boot. The issue was originally documented by Reddit user u/Mags_Smash in [this r/pcmasterrace thread](https://old.reddit.com/r/pcmasterrace/comments/1uk7v0v/windows_update_silently_installed_lg_bloatware/), who traced the install back to Windows' device-metadata pipeline using Reliability Monitor and Event Viewer, before Gamers Nexus picked it up and reproduced it independently.
>
> Further reading / how the story developed:
> - [Windows Update silently installed LG bloatware, which causes a McAfee pop up](https://old.reddit.com/r/pcmasterrace/comments/1uk7v0v/windows_update_silently_installed_lg_bloatware/) — the original r/pcmasterrace report
> - [LG TVs and monitors said to surveil users and...](https://old.reddit.com/r/pcmasterrace/comments/1uyxivn/lg_tvs_and_monitors_said_to_surveil_users_and/) — follow-up on the broader privacy/surveillance concerns
> - [The LG adware situation](https://old.reddit.com/r/microsoftsucks/comments/1v5u4w5/the_lg_adware_situation/) — r/microsoftsucks discussion on Microsoft enabling the silent install
> - [LG to remove unwanted monitor pop-ups following...](https://old.reddit.com/r/pcgaming/comments/1v4zw9a/lg_to_remove_unwanted_monitor_popups_following/) — r/pcgaming thread on LG/Microsoft's response
>
> Microsoft has since said LG agreed to drop the McAfee pop-up specifically, but the app itself still installs silently and isn't removed by that fix — hence this script.

There are two ways to run the removal:

| Script | Description |
|---|---|
| [`Remove-LGMonitorApp-GUI.ps1`](#gui-version) | A simple Windows Forms GUI — check status, click a button, watch a live log. |
| [`Remove-LGMonitorApp.ps1`](#script-only-version) | A silent/scriptable console version for automation, remote sessions, or RMM deployment. |

> Rename the files above to match whatever you actually push to the repo (e.g. `gui.ps1` and `console.ps1`) and update the links accordingly.

---

## Why this exists

LG's bundled Monitor App is installed as a provisioned AppX package, which means:
- It reinstalls itself for every new user profile created on the machine.
- A normal "Uninstall" from Settings only removes it for the *current* user.
- Leftover folders in `C:\Program Files\WindowsApps` can persist and block clean reinstalls or updates.

Both scripts handle all three of these cases in one pass:
1. **Deprovision** the package so it stops reinstalling for new profiles.
2. **Remove** the installed package for *all* existing users (with a per-SID fallback if the bulk removal fails).
3. **Clean up** any orphaned folders left behind, taking ownership and adjusting permissions as needed.

---

## GUI Version

A lightweight status-and-action window:

- **Status indicator** — shows `INSTALLED` (red) or `NOT INSTALLED` (green) at a glance.
- **Refresh Status** — re-scans for provisioned and installed packages.
- **Uninstall LG Monitor App** — runs the full removal with a confirmation prompt first.
- **Live log panel** — every step is logged in the window and mirrored to `%ProgramData%\LGMonitorAppRemoval.log`.

<p align="center">
  <img src="docs/screenshot-installed.png" alt="LG Monitor App Remover — status: INSTALLED" width="500">
  <br>
  <em>Status shown as INSTALLED, with the uninstall button enabled</em>
</p>

<p align="center">
  <img src="docs/screenshot-complete.png" alt="LG Monitor App Remover — removal complete" width="500">
  <br>
  <em>Removal log after a successful run, status back to NOT INSTALLED</em>
</p>

### Running the GUI version

1. Download `Remove-LGMonitorApp-GUI.ps1`.
2. Right-click **PowerShell** (or Windows Terminal) and choose **Run as administrator** — the script requires elevation for `Remove-AppxProvisionedPackage` and `Remove-AppxPackage -AllUsers`.
3. Navigate to the folder containing the script and run:

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
   .\Remove-LGMonitorApp-GUI.ps1
   ```

   `-Scope Process` means the bypass only applies to this one PowerShell session/process — it does not change your system-wide execution policy.

4. The window opens already showing the current status. Click **Uninstall LG Monitor App**, confirm the prompt, and watch the log until it finishes.

---

## Script-Only Version

A non-interactive console script that performs the same three-step removal (deprovision → remove installed → clean leftovers) and finishes with a verification check, all written to the console and to `%ProgramData%\LGMonitorAppRemoval.log`. Useful for:

- Silent deployment via Intune, GPO startup scripts, or an RMM tool.
- Running over a remote PowerShell session (`Invoke-Command`, PSRemoting).
- Anyone who just wants to run it once from a terminal without a GUI.

### Running the script-only version

1. Download `Remove-LGMonitorApp.ps1`.
2. Open **PowerShell as Administrator**.
3. Run:

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
   .\Remove-LGMonitorApp.ps1
   ```

4. Review the console output (or the log file) for the final `VERIFIED CLEAN` or `WARNING` line.

---

## Log File

Both scripts write to the same location:

```
%ProgramData%\LGMonitorAppRemoval.log
```

which resolves to something like `C:\ProgramData\LGMonitorAppRemoval.log`. Check this file if you need details on what was removed, skipped, or failed.

---

## Requirements

- Windows 10/11
- PowerShell 5.1+ (built-in Windows PowerShell is fine)
- Administrator privileges (both scripts start with `#Requires -RunAsAdministrator`, so they'll refuse to run otherwise)

---

## Disclaimer

These scripts remove Windows packages and can take ownership of / delete files under `C:\Program Files\WindowsApps`. Review the code before running it on a production machine, and test in a non-critical environment first if you're unsure. Use at your own risk.
