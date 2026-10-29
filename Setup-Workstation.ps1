<#
.SYNOPSIS
    Automated Workstation Setup Script
    Installs default software packages using WinGet and configures system settings.
#>

# --- SCRIPT METADATA ---
$ScriptVersion = "1.6.0"
$ScriptDescription = "Automated environment provisioning: Apps, Power, Sounds, Visual Effects, Registry Backup, and Update Management."

# Helper function for user confirmations
function Confirm-Action {
    param (
        [string]$Message,
        [bool]$DefaultYes = $true
    )
    $choices = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
    $response = Read-Host "$Message $choices"
    
    # If the user presses Enter without typing, use the default
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $DefaultYes
    }
    return ($response.Trim().ToLower() -in @('y', 'yes'))
}

# 1. Ensure the script is running with administrative privileges
if (-not(
        [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run this script as Administrator!"
    Pause
    Exit
}

# Clear the screen and show Header
Clear-Host
Write-Host "==========================================================" -ForegroundColor Gray
Write-Host " WORKSTATION SETUP SCRIPT " -ForegroundColor White -BackgroundColor DarkBlue
Write-Host " Version: $ScriptVersion" -ForegroundColor Cyan
Write-Host " Description: $ScriptDescription" -ForegroundColor Gray
Write-Host "==========================================================`n" -ForegroundColor Gray

# 2. Define list of Apps (Using WinGet IDs for precision)
$AppsToInstall = @(
    "Microsoft.VCRedist.2015+.x64",
    "Google.Chrome",
    "Mozilla.Firefox.pl",
    "Microsoft.VisualStudioCode",
    "RARLab.WinRAR",
    "Resolume.Arena",
    "Microsoft.Office",
    "Microsoft.PowerToys",
    "Microsoft.PowerShell",
    "Adobe.Acrobat.Reader.64-bit",
    "BitFocus.Companion",
    "KeePassXCTeam.KeePassXC",
    "VideoLAN.VLC",
    "MOTU.MSeries",
    "LocalSend.LocalSend",
    "NDI.NDITools",
    "Devolutions.UniGetUI"
)

# --- SOFTWARE INSTALLATION STEP ---
if (Confirm-Action "`n[STEP 1] Do you want to process software installations/updates?") {

    # Check if WinGet is available
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning "WinGet not found."
        if (Confirm-Action "Attempt to register Microsoft Desktop App Installer package?") {
            Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
        }
    }

    # Loop through the array and prompt for each app
    foreach ($App in $AppsToInstall) {
        if (-not (Confirm-Action "  -> Do you want to install/update '$App'?" -DefaultYes $true)) {
            Write-Host "  Skipping: $App`n" -ForegroundColor DarkGray
            continue
        }

        Write-Host "Checking: $App..." -ForegroundColor Cyan

        # Capture the list output for the specific ID
        $listResult = winget list --id $App -e --accept-source-agreements 2>$null

        if ($listResult -match $App) {
            $currentVersion = ($listResult | Select-String -Pattern "$App\s+([^\s]+)").Matches.Groups[1].Value
            if ([string]::IsNullOrWhiteSpace($currentVersion)) { $currentVersion = "Unknown" }

            Write-Host "[Installed] $App (Version: $currentVersion)" -ForegroundColor Yellow
            Write-Host "Checking for updates..." -ForegroundColor Gray
            
            winget upgrade --id $App --accept-package-agreements --accept-source-agreements --silent
        } else {
            Write-Host "[Missing] $App. Starting fresh installation..." -ForegroundColor Yellow
            winget install --id $App --accept-package-agreements --accept-source-agreements --silent

            if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully installed $App" -ForegroundColor Green
            } else {
                Write-Warning "Failed to install $App. Exit Code: $LASTEXITCODE"
            }
        }
        Write-Host "--------------------"
    }

    Write-Host "--- Software Installation Complete! ---`n" -ForegroundColor Green
} else {
    Write-Host "Skipping software installation.`n" -ForegroundColor DarkGray
}

# --- REGISTRY & SYSTEM BACKUP STEP ---
if (Confirm-Action "[STEP 2] Create a Registry Backup before applying system modifications?") {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFolder = Join-Path -Path $env:USERPROFILE -ChildPath "Desktop\RegistryBackups_$timestamp"

    if (-not (Test-Path $backupFolder)) {
        New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null
    }

    Write-Host "Backing up affected registry branches to: $backupFolder" -ForegroundColor Cyan

    # Export registry keys that this script modifies
    $keysToBackup = @{
        "HKCU_AppEvents"        = "HKEY_CURRENT_USER\AppEvents\Schemes"
        "HKCU_WindowMetrics"    = "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics"
        "HKCU_Desktop"          = "HKEY_CURRENT_USER\Control Panel\Desktop"
        "HKCU_ExplorerAdvanced" = "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        "HKCU_DWM"              = "HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM"
        "HKLM_WindowsUpdate"    = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    }

    foreach ($name in $keysToBackup.Keys) {
        $regPath = $keysToBackup[$name]
        $outFile = Join-Path $backupFolder "$name.reg"
        Start-Process reg.exe -ArgumentList "export `"$regPath`" `"$outFile`" /y" -Wait -WindowStyle Hidden 2>$null
    }

    # Optional: Attempt to create a Windows System Restore Point
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Pre-WorkstationSetup_$timestamp" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "System Restore Point created successfully." -ForegroundColor Green
    } catch {
        Write-Host "System Restore Point could not be created (System Protection may be disabled). Registry files were saved." -ForegroundColor Yellow
    }

    Write-Host "Registry backup complete.`n" -ForegroundColor Green
} else {
    Write-Host "Skipping registry backup.`n" -ForegroundColor DarkGray
}

# --- POWER SETTINGS STEP ---
if (Confirm-Action "[STEP 3] Configure Power Plan settings (timeouts and disable hibernation)?") {
    Write-Host "Setting Display and Sleep Timeouts..." -ForegroundColor Gray
    powercfg /change monitor-timeout-dc 30
    powercfg /change monitor-timeout-ac 0
    powercfg /change standby-timeout-dc 60
    powercfg /change standby-timeout-ac 0

    Write-Host "Disabling hibernation..." -ForegroundColor Gray
    powercfg /hibernate off

    # Power Setting Verification Function
    function Get-PowerSetting {
        param($SubGroup, $Setting, $Name)
        $output = powercfg /q SCHEME_CURRENT $SubGroup $Setting
        $acHex = ($output | Select-String "AC Power Setting Index").ToString().Split(":")[1].Trim()
        $dcHex = ($output | Select-String "DC Power Setting Index").ToString().Split(":")[1].Trim()
        $acMin = [System.Convert]::ToInt32($acHex, 16) / 60
        $dcMin = [System.Convert]::ToInt32($dcHex, 16) / 60

        return [PSCustomObject]@{
            Name      = $Name
            PluggedIn = if ($acMin -eq 0) { "Never" } else { "$acMin Minutes" }
            OnBattery = if ($dcMin -eq 0) { "Never" } else { "$dcMin Minutes" }
        }
    }

    $results = @()
    $results += Get-PowerSetting "SUB_VIDEO" "VIDEOIDLE" "Screen Off"
    $results += Get-PowerSetting "SUB_SLEEP" "STANDBYIDLE" "Sleep"
    $results | Format-Table -AutoSize
    Write-Host "Power plan configured.`n" -ForegroundColor Green
} else {
    Write-Host "Skipping power plan configuration.`n" -ForegroundColor DarkGray
}

# --- SYSTEM SOUNDS STEP ---
if (Confirm-Action "[STEP 4] Disable all Windows system sounds (set scheme to 'No Sounds')?") {
    Write-Host "Configuring System Sounds..." -ForegroundColor Gray
    $SoundPath = "HKCU:\AppEvents\Schemes\Apps\.Default"
    $SoundEvents = Get-ChildItem -Path $SoundPath
    foreach ($EventSound in $SoundEvents) {
        $CurrentPath = "$($EventSound.PSPath)\.Current"
        if (Test-Path $CurrentPath) {
            Set-ItemProperty -Path $CurrentPath -Name "(Default)" -Value ""
        }
    }
    Set-ItemProperty -Path "HKCU:\AppEvents\Schemes" -Name "(Default)" -Value ".None"
    Write-Host "System sounds have been disabled.`n" -ForegroundColor Green
} else {
    Write-Host "Skipping system sounds configuration.`n" -ForegroundColor DarkGray
}

# --- DISABLE AUTO UPDATES STEP ---
if (Confirm-Action "[STEP 5] Disable Automatic Updates (Windows Update & WinGet)?") {
    # A. Set Windows Update to "Notify for download and auto install" (AUOptions = 2)
    $UpdateKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (-not (Test-Path $UpdateKey)) {
        New-Item -Path $UpdateKey -Force | Out-Null
    }
    Set-ItemProperty -Path $UpdateKey -Name "NoAutoUpdate" -Value 0
    Set-ItemProperty -Path $UpdateKey -Name "AUOptions" -Value 2
    Write-Host "Windows Update set to 'Notify Only'." -ForegroundColor Gray

    # B. Disable the Windows Update Service (wuauserv)
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Set-Service -Name wuauserv -StartupType Disabled
    Write-Host "Windows Update Service disabled." -ForegroundColor Gray

    # C. Disable WinGet Auto-Update behavior
    Write-Host "Disabling WinGet auto-update intervals..." -ForegroundColor Gray
    winget settings --enable AutoHeader | Out-Null

    Write-Host "Auto-updates have been restricted.`n" -ForegroundColor Green
} else {
    Write-Host "Skipping auto-update restrictions.`n" -ForegroundColor DarkGray
}

# --- VISUAL EFFECTS & WINDOW BEHAVIOR STEP ---
if (Confirm-Action "[STEP 6] Apply visual effects (disable window zoom, disable taskbar peek, keep taskbar animations)?") {
    Write-Host "Configuring Visual Effects..." -ForegroundColor Gray

    # 1. Animate windows when minimizing and maximizing -> OFF
    $MetricsPath = "HKCU:\Control Panel\Desktop\WindowMetrics"
    Set-ItemProperty -Path $MetricsPath -Name "MinAnimate" -Value "0" -Type String

    # 2. Enable Peek (Aero Peek / Taskbar Live Preview) -> OFF
    $AdvancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $AdvancedPath -Name "DisablePreviewWindow" -Value 1 -Type DWord
    Set-ItemProperty -Path $AdvancedPath -Name "DisablePreviewDesktop" -Value 1 -Type DWord

    $DwmPath = "HKCU:\Software\Microsoft\Windows\DWM"
    if (-not (Test-Path $DwmPath)) { New-Item -Path $DwmPath -Force | Out-Null }
    Set-ItemProperty -Path $DwmPath -Name "EnableAeroPeek" -Value 0 -Type DWord

    # 3. Taskbar Animations -> ON (matches custom performance configuration)
    Set-ItemProperty -Path $AdvancedPath -Name "TaskbarAnimations" -Value 1 -Type DWord

    # 4. Prevent windows shrinking/minimizing when external monitors are connected/disconnected
    $DesktopPath = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $DesktopPath -Name "MonitorRemovalRecalcBehavior" -Value 1 -Type DWord
    Set-ItemProperty -Path $DesktopPath -Name "RestorePreviousStateRecalcBehavior" -Value 0 -Type DWord

    Write-Host "Visual effects updated.`n" -ForegroundColor Green
} else {
    Write-Host "Skipping visual effects and window behavior adjustments.`n" -ForegroundColor DarkGray
}

# --- DEBLOATER STEP ---
if (Confirm-Action "[STEP 7] Do you want to run the Windows Debloater script?" -DefaultYes $false) {
    Write-Host "Running Windows Debloater..." -ForegroundColor Magenta
    try {
        iwr -useb "https://debloat.raphi.re/" | iex
    } catch {
        Write-Warning "Error downloading Windows Debloater: $_"
    }
} else {
    Write-Host "Skipping Debloater.`n" -ForegroundColor DarkGray
}

Write-Host "--- Setup finished! ---" -ForegroundColor Green
Pause
