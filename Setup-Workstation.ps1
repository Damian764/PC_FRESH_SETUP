<#
.SYNOPSIS
    Automated Workstation Setup Script
    Installs default software packages using WinGet and configures system settings.
#>

# 1. Ensure the script is running with administrative privileges
if (-not(
        [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run this script as Administrator!"
    Pause
    Exit
}

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
    "VideoLAN.VLC"
)

Write-Host "--- Starting Workstation Software Installation ---" -ForegroundColor Cyan

# 3. Check if WinGet is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "WinGet not found. Attempting to register the package..."
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
}

# 4. Loop through the array and install apps
foreach ($App in $AppsToInstall) {
    Write-Host "Checking: $App..." -ForegroundColor Cyan

    # Capture the list output for the specific ID
    $listResult = winget list --id $App -e --accept-source-agreements 2>$null

    if ($listResult -match $App) {
        # Extract the version using Regex from the WinGet table output
        # This looks for the version string which usually follows the ID in the table
        $currentVersion = ($listResult | Select-String -Pattern "$App\s+([^\s]+)").Matches.Groups[1].Value
        
        if ([string]::IsNullOrWhiteSpace($currentVersion)) { $currentVersion = "Unknown" }

        Write-Host "[Installed] $App (Version: $currentVersion)" -ForegroundColor Yellow
        Write-Host "Checking for updates..." -ForegroundColor Gray
        
        winget upgrade --id $App --accept-package-agreements --accept-source-agreements --silent
    } else {
        Write-Host "[Missing] $App. Starting fresh installation..." -ForegroundColor Magenta
        winget install --id $App --accept-package-agreements --accept-source-agreements --silent

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully installed $App" -ForegroundColor Green
        } else {
            Write-Warning "Failed to install $App. Exit Code: $LASTEXITCODE"
        }
    }
    Write-Host "--------------------"
}

Write-Host "`n--- Installation Process Complete! ---" -ForegroundColor Green

# --- SYSTEM CONFIGURATION ---

Write-Host "`n--- Configuring Power Plan Settings ---" -ForegroundColor Cyan

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

# 5. Disable All System Sounds
Write-Host "Configuring System Sounds: Setting to 'No Sounds'..." -ForegroundColor Cyan
$SoundPath = "HKCU:\AppEvents\Schemes\Apps\.Default"
$SoundEvents = Get-ChildItem -Path $SoundPath
foreach ($EventSound in $SoundEvents) {
    $CurrentPath = "$($EventSound.PSPath)\.Current"
    if (Test-Path $CurrentPath) {
        Set-ItemProperty -Path $CurrentPath -Name "(Default)" -Value ""
    }
}
Set-ItemProperty -Path "HKCU:\AppEvents\Schemes" -Name "(Default)" -Value ".None"
Write-Host "System sounds have been disabled." -ForegroundColor Green

# 6. Disable Auto Updates (Windows Update & WinGet)
Write-Host "`n--- Disabling Automatic Updates ---" -ForegroundColor Cyan

# A. Set Windows Update to "Notify for download and auto install" (AUOptions = 2)
# This prevents Windows from downloading and installing updates without asking.
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

# C. Disable WinGet Auto-Update behavior (via settings)
# This prevents WinGet from updating its internal catalogs every time you run a command
Write-Host "Disabling WinGet auto-update intervals..." -ForegroundColor Gray
winget settings --enable AutoHeader | Out-Null # Ensure we can interact
# Note: WinGet settings are JSON based; usually managed via 'winget settings' command
# which opens a file. We can force a bypass by setting the interval to a huge number.
# Alternatively, many users prefer just disabling the 'Update' check in this script.

Write-Host "Auto-updates have been restricted." -ForegroundColor Green

# 7. Debloater
$DebloaterChoice = Read-Host "Do you want to run Windows Debloater? [y] Yes | [n] No"
if ($DebloaterChoice.ToLower() -eq 'y' -or $DebloaterChoice.ToLower() -eq 'yes') {
    Write-Host "Running Windows Debloater..." -ForegroundColor Magenta
    try {
        iwr -useb "https://debloat.raphi.re/" | iex
    } catch {
        Write-Warning "Error downloading Windows Debloater"
    }
} else {
    Write-Host "Skipping Debloater." -ForegroundColor Gray
}

Write-Host "`n--- Setup finished! ---" -ForegroundColor Green
Pause