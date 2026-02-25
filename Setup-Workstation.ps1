<#
.SYNOPSIS
    Automated Workstation Setup Script
    Installs default software packages using WinGet.
#>

# 1. Ensure the script is running with administrative privilages

if (-not(
        [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run this script as Administrator!"
    Pause
    Exit
}

# 2. Define list of Apps (Using WinGet IDs for precision)
# To find an ID, run: winget search "App Name"

$AppsToInstall = @(
    "Microsoft.VCRedist.2015+.x64",
    "Google.Chrome",
    "Mozilla.Firefox.pl",
    "Microsoft.VisualStudioCode",
    "RARLab.WinRAR",
    "Resolume.Arena",
    "Microsoft.Office",
    "Adobe.Acrobat.Reader.64-bit",
    "BitFocus.Companion",
    "KeePassXCTeam.KeePassXC"
)

Write-Host "--- Starting Workstation Software Installation ---" -ForegroundColor Cyan

# 3. Check if WinGet is available, if not, try to register it
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "WinGet not found. Attempting to register the package..."
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
}

# 4. Loop through the array and install apps
foreach ($App in $AppsToInstall) {
    Write-Host "Checking/Installing: $App..." -ForegroundColor Cyan
    
    # Check if the app is already installed
    $isInstalled = winget list --id $App -e --accept-source-agreements
    
    if ($isInstalled -match $App) {
        Write-Host "$App is already installed. Checking for updates..." -ForegroundColor Yellow
        # Optional: Try to upgrade instead of install
        winget upgrade --id $App --accept-package-agreements --accept-source-agreements --silent
    } else {
        # Perform fresh installation
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

Write-Host "`n--- Configuring Power Plan Settings ---" -ForegroundColor Cyan

# 1. Set "Turn off display" (Monitor Timeout)
# AC = Plugged In | DC = Battery | Value is in Minutes ( 0 = Never )

Write-Host "Setting Display Timeouts..." -ForegroundColor Gray
powercfg /change monitor-timeout-dc 30
powercfg /change monitor-timeout-ac 0

# 2. Set "Put computer to sleep" (Standby Timeout)

Write-Host "Setting Sleep Timeouts..." -ForegroundColor Gray
powercfg /change standby-timeout-dc 60
powercfg /change standby-timeout-ac 0

# 3. Disable hibernation

Write-Host "Disabling hibernation..." -ForegroundColor Gray
powercfg /change hibernate-timeout-dc 0
powercfg /change hibernate-timeout-ac 0


# 4. Verification
Write-Host "`nVeryfying current settings for the active plan:" -ForegroundColor Gray

function Get-PowerSetting {
    param($SubGroup, $Setting, $Name)
    $output = powercfg /q SCHEME_CURRENT $SubGroup $Setting
    
    # Extract Hex values
    $acHex = ($output | Select-String "AC Power Setting Index").ToString().Split(":")[1].Trim()
    $dcHex = ($output | Select-String "DC Power Setting Index").ToString().Split(":")[1].Trim()
    
    # Convert Hex to Decimal (Seconds) and then to Minutes
    $acMin = [System.Convert]::ToInt32($acHex, 16) / 60
    $dcMin = [System.Convert]::ToInt32($dcHex, 16) / 60
 
    return [PSCustomObject]@{
        Name      = $Name
        Setting   = $Setting
        PluggedIn = if ($acMin -eq 0) { "Never" } else { "$acMin Minutes" }
        OnBattery = if ($dcMin -eq 0) { "Never" } else { if ($dcMin -ge 60) { "$($dcMin/60) Hour(s)" } else { "$dcMin Minutes" } }
    }
}
 
$results = @()
$results += Get-PowerSetting "SUB_VIDEO" "VIDEOIDLE" "Screen Off"    # Screen Off
$results += Get-PowerSetting "SUB_SLEEP" "STANDBYIDLE" "Sleep"  # Sleep
$results += Get-PowerSetting "SUB_SLEEP" "HIBERNATEIDLE" "Hibernate" # Hibernate
 
$results | Format-Table -Property Name, Setting, PluggedIn, OnBattery -AutoSize

Write-Host "`n--- Power settings applied successfully! ---" -ForegroundColor Green


#5 Debloater

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
