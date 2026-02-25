# Automated Workstation Setup Script


This PowerShell script streamlines the process of provisioning a new Windows workstation. It automatically checks for administrative privileges, installs essential software packages, configures optimal power and sleep settings, and offers an optional Windows debloat.


## 🚀 Quick Start


You can execute this script directly from the web using a single command. 


Open **PowerShell as Administrator** and run:


```powershell

irm https://is.gd/damiansetup | iex

```


*Note: `irm` (Invoke-RestMethod) securely fetches the raw script, and `iex` (Invoke-Expression) runs it immediately.*


---


## ⚙️ Features


### 1. Automated Software Installation

The script uses `winget` (Windows Package Manager) to silently install or update the following core applications. If `winget` is missing, the script will attempt to register it automatically.


* Microsoft Visual C++ Redistributable (2015+)

* Google Chrome

* Mozilla Firefox (PL)

* Visual Studio Code

* WinRAR

* Resolume Arena

* Microsoft Office

* Microsoft PowerToys

* Microsoft PowerShell

* Adobe Acrobat Reader (64-bit)

* BitFocus Companion

* KeePassXC


### 2. Power Plan Configuration

To prevent interruptions during critical tasks, the script applies the following timeouts to your active power plan:


| Power Setting | Plugged In (AC) | On Battery (DC) |
| :--- | :--- | :--- |
| **Screen Off** | Never (0 min) | 30 Minutes |
| **Sleep** | Never (0 min) | 60 Minutes |
| **Hibernate** | Disabled | Disabled |


*The script runs a verification check at the end to confirm these settings were applied successfully.*


### 3. Optional Windows Debloat

Before finishing, the script will prompt you with the option to run [Raphi's Windows Debloater](https://debloat.raphi.re/). 

* Press `y` or `yes` to run the debloat utility.

* Press `n` to skip this step entirely.


---


## ✏️ Customizing the Script


If you want to add your own software to the installation list, you just need to find the correct `winget` ID and add it to the array.


1. Open PowerShell and search for the app:

   ```powershell

   winget search "App Name"

   ```

2. Find the exact string under the **Id** column (e.g., `VideoLAN.VLC`).

3. Open the script file and add the ID to the `$AppsToInstall` list, making sure to include quotes and a comma:

   ```powershell

   $AppsToInstall = @(

       "Microsoft.VCRedist.2015+.x64",

       "Google.Chrome",

       "VideoLAN.VLC" # <-- Add your custom app here

   )

   ```


---


## 📋 Prerequisites


* **OS:** Windows 10 or Windows 11.

* **Permissions:** Must be run with **Administrator privileges**. The script will halt and warn you if it is run as a standard user.

* **Network:** An active internet connection is required to fetch software packages and the optional debloat script.


---


## 🛠️ Running Locally (Alternative)


If you prefer to download the file and run it locally instead of using the web link:


1. Download the script file to your computer.

2. Open **PowerShell as Administrator**.

3. Navigate to the directory containing the downloaded file.

4. Execute the script:

   ```powershell

   .\setup-script.ps1

   ```

   *(If you encounter execution policy restrictions, temporarily bypass them by running: `Set-ExecutionPolicy Bypass -Scope Process -Force` first).*
