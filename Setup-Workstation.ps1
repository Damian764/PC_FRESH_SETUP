<#
.SYNOPSIS
    Automated Workstation Setup Script
    Installs default software packages using WinGet and configures system settings.
#>

# --- SCRIPT METADATA ---
$ScriptVersion = "1.3.0"
$ScriptDescription = "Automated environment provisioning: Apps, Power, Sounds, and Update Management."

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

# --- POWER SETTINGS STEP ---
if (Confirm-Action "[STEP 2] Configure Power Plan settings (timeouts and disable hibernation)?") {
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

        return [PSResourceObject]@{
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
if (Confirm-Action "[STEP 3] Disable all Windows system sounds (set scheme to 'No Sounds')?") {
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
if (Confirm-Action "[STEP 4] Disable Automatic Updates (Windows Update & WinGet)?") {
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

# --- DEBLOATER STEP ---
if (Confirm-Action "[STEP 5] Do you want to run the Windows Debloater script?" -DefaultYes $false) {
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
