# Automated Workstation Setup Script

A modular, interactive PowerShell script to quickly provision and configure a fresh Windows workstation—tailored especially for live production, AV control, and power-user performance.

The script runs interactively with confirmation prompts for each phase, allowing you to accept defaults or skip steps and individual applications as you see fit.

---

## 🚀 Quick Start

Run the script directly via PowerShell with Administrator privileges:

```powershell
irm https://is.gd/damiansetup | iex
```

> **Note:** `irm` (*Invoke-RestMethod*) fetches the raw script, and `iex` (*Invoke-Expression*) executes it in your current session.

---

## ⚙️ Features & Steps

### 1. Interactive Software Installation (WinGet)
The script uses the Windows Package Manager (`winget`) to install or update packages silently. It verifies WinGet presence (installing it if missing) and **prompts you for each application**, so you only install what you need.

### 2. Power & Sleep Optimizations
Prevents unexpected shutdowns, sleep modes, or display blanks during mission-critical tasks or live performances:

| Setting | Plugged In (AC) | On Battery (DC) |
| :--- | :--- | :--- |
| **Screen Off** | Never (0 min) | 30 Minutes |
| **Sleep** | Never (0 min) | 60 Minutes |
| **Hibernation** | Disabled | Disabled |

*The script prints a summary table at the end of the step to verify the active power plan.*

### 3. System Sounds Disabled
Sets the active Windows sound scheme to **"No Sounds"** and mutes system event cues—preventing stray notification chimes and dings from routing through live audio interfaces (e.g., MOTU/Dante/USB).

### 4. Controlled Updates
Avoids background reboots and unexpected bandwidth spikes during active workstation use:
* Sets Windows Update policy to **Notify for download and auto install** (`AUOptions = 2`).
* Disables the automatic background Windows Update service (`wuauserv`).
* Restricts automatic WinGet repository update checks.

### 5. Optional Windows Debloater
Prompts whether to execute [Raphi's Windows Debloater](https://debloat.raphi.re/) to strip telemetry and unwanted pre-installed Windows consumer bloatware. Defaults to `No` (`[y/N]`) for safety.

---

## 🎮 How the Prompts Work

Every step utilizes an interactive prompt with smart defaults:
* **`[Y/n]`**: Pressing Enter defaults to **Yes**.
* **`[y/N]`**: Pressing Enter defaults to **No** (used for potentially disruptive actions like the external debloater).
* You can explicitly type `y`, `yes`, `n`, or `no` (case-insensitive).

---

## ✏️ Customizing the Application List

If you fork or download the script, you can easily add or remove software in the `$AppsToInstall` array:

1. Search for the package ID using WinGet:
   ```powershell
   winget search "App Name"
   ```
2. Copy the exact value from the **Id** column.
3. Add or remove entries in the `$AppsToInstall` array inside the script:
   ```powershell
   $AppsToInstall = @(
       "Google.Chrome",
       "VideoLAN.VLC",
       "OBSProject.OBSStudio"  # <-- Your custom app here
   )
   ```

---

## 📋 Prerequisites

* **Operating System:** Windows 10 or Windows 11.
* **Privileges:** Administrator privileges are required (the script self-checks and exits if unprivileged).
* **Network:** Active internet connection to fetch packages and winget sources.

---

## 🛠️ Running Locally

If you prefer to clone or download the file instead of running it via the web link:

1. Open **PowerShell as Administrator**.
2. If script execution is restricted on your machine, temporarily bypass it:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   ```
3. Run the script:
   ```powershell
   .\setup-script.ps1
   ```
