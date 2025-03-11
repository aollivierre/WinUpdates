# Install-PendingUpdatesWithoutWSUS.ps1
# Purpose: Temporarily disable WSUS, install all pending Windows updates, and restore WSUS settings

# Check for administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires administrative privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Function to disable/enable WSUS and manage Windows Update settings
function Set-WindowsUpdatePolicy {
    param (
        [bool]$DisableWsus = $true
    )
    
    $regPathAU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    $regPathWU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    
    # Create a hashtable to store original values for restoration
    $script:backupSettings = @{}
    
    try {
        # Back up current values if they exist
        Write-Host "Backing up Windows Update policy settings..." -ForegroundColor Cyan
        
        if (Test-Path $regPathAU) {
            $UseWUServer = Get-ItemProperty -Path $regPathAU -Name "UseWUServer" -ErrorAction SilentlyContinue
            if ($UseWUServer -ne $null) {
                $script:backupSettings.AU_UseWUServer = $UseWUServer.UseWUServer
            }
        }
        
        if (Test-Path $regPathWU) {
            $DoNotConnectToWindowsUpdateInternetLocations = Get-ItemProperty -Path $regPathWU -Name "DoNotConnectToWindowsUpdateInternetLocations" -ErrorAction SilentlyContinue
            if ($DoNotConnectToWindowsUpdateInternetLocations -ne $null) {
                $script:backupSettings.WU_DoNotConnectToWindowsUpdateInternetLocations = $DoNotConnectToWindowsUpdateInternetLocations.DoNotConnectToWindowsUpdateInternetLocations
            }
            
            $DisableWindowsUpdateAccess = Get-ItemProperty -Path $regPathWU -Name "DisableWindowsUpdateAccess" -ErrorAction SilentlyContinue
            if ($DisableWindowsUpdateAccess -ne $null) {
                $script:backupSettings.WU_DisableWindowsUpdateAccess = $DisableWindowsUpdateAccess.DisableWindowsUpdateAccess
            }
            
            $WUServer = Get-ItemProperty -Path $regPathWU -Name "WUServer" -ErrorAction SilentlyContinue
            if ($WUServer -ne $null) {
                $script:backupSettings.WU_WUServer = $WUServer.WUServer
            }
        }
        
        if ($DisableWsus) {
            # Modify settings to bypass WSUS
            Write-Host "Temporarily disabling WSUS to allow direct updates from Microsoft..." -ForegroundColor Yellow
            
            if (Test-Path $regPathAU) {
                Set-ItemProperty -Path $regPathAU -Name "UseWUServer" -Value 0 -Type DWord -Force
            }
            
            if (Test-Path $regPathWU) {
                if ((Get-ItemProperty -Path $regPathWU -Name "DoNotConnectToWindowsUpdateInternetLocations" -ErrorAction SilentlyContinue) -ne $null) {
                    Set-ItemProperty -Path $regPathWU -Name "DoNotConnectToWindowsUpdateInternetLocations" -Value 0 -Type DWord -Force
                }
                
                if ((Get-ItemProperty -Path $regPathWU -Name "DisableWindowsUpdateAccess" -ErrorAction SilentlyContinue) -ne $null) {
                    Set-ItemProperty -Path $regPathWU -Name "DisableWindowsUpdateAccess" -Value 0 -Type DWord -Force
                }
            }
            
            # Restart Windows Update service
            Restart-Service wuauserv -Force
            Write-Host "Windows Update policy temporarily modified to bypass WSUS" -ForegroundColor Green
        } else {
            # Restore original settings
            Write-Host "Restoring original Windows Update policy settings..." -ForegroundColor Yellow
            
            if ($script:backupSettings.AU_UseWUServer -ne $null -and (Test-Path $regPathAU)) {
                Set-ItemProperty -Path $regPathAU -Name "UseWUServer" -Value $script:backupSettings.AU_UseWUServer -Type DWord -Force
            }
            
            if (Test-Path $regPathWU) {
                if ($script:backupSettings.WU_DoNotConnectToWindowsUpdateInternetLocations -ne $null) {
                    Set-ItemProperty -Path $regPathWU -Name "DoNotConnectToWindowsUpdateInternetLocations" -Value $script:backupSettings.WU_DoNotConnectToWindowsUpdateInternetLocations -Type DWord -Force
                }
                
                if ($script:backupSettings.WU_DisableWindowsUpdateAccess -ne $null) {
                    Set-ItemProperty -Path $regPathWU -Name "DisableWindowsUpdateAccess" -Value $script:backupSettings.WU_DisableWindowsUpdateAccess -Type DWord -Force
                }
            }
            
            # Restart Windows Update service
            Restart-Service wuauserv -Force
            Write-Host "Original Windows Update policy settings restored" -ForegroundColor Green
        }
        
        return $true
    } catch {
        Write-Host "Error modifying Windows Update policy: $_" -ForegroundColor Red
        return $false
    }
}

# Function to install pending Windows updates using PSWindowsUpdate module
function Install-PendingWindowsUpdates {
    Write-Host "Searching for pending Windows updates..." -ForegroundColor Cyan
    
    try {
        # Check if PSWindowsUpdate module is installed
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Host "PSWindowsUpdate module is not installed. Attempting to install..." -ForegroundColor Yellow
            Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
        }
        
        # Import PSWindowsUpdate module
        Import-Module PSWindowsUpdate
        
        # Get all pending updates
        Write-Host "Retrieving pending updates..." -ForegroundColor Yellow
        $AllUpdates = Get-WUList
        $PendingUpdates = $AllUpdates | Where-Object { $_.IsInstalled -eq $false }
        
        if (-not $PendingUpdates) {
            Write-Host "No pending updates found." -ForegroundColor Green
            return @{
                Success = $true
                RebootRequired = $false
            }
        }
        
        Write-Host "Found $($PendingUpdates.Count) pending updates:" -ForegroundColor Cyan
        
        # Display update details
        $index = 1
        foreach ($update in $PendingUpdates) {
            Write-Host "$index. $($update.KB) - $($update.Title)" -ForegroundColor White
            $index++
        }
        
        # Install updates
        Write-Host "Installing updates..." -ForegroundColor Yellow
        Install-WindowsUpdate -AcceptAll -IgnoreReboot -Install -Verbose
        
        # Check if a reboot is required after installing updates
        Write-Host "Checking if reboot is required..." -ForegroundColor Yellow
        $RebootStatus = Get-WURebootStatus
        $RebootRequired = $RebootStatus.RebootRequired
        
        if ($RebootRequired) {
            Write-Host "A reboot is required after installing updates." -ForegroundColor Yellow
        } else {
            Write-Host "No reboot required after installing updates." -ForegroundColor Green
        }
        
        return @{
            Success = $true
            RebootRequired = $RebootRequired
        }
    } catch {
        Write-Host "Error installing updates: $_" -ForegroundColor Red
        return @{
            Success = $false
            RebootRequired = $false
        }
    }
}

# Main script execution
try {
    Write-Host "=========================================================" -ForegroundColor Cyan
    Write-Host "  Installing Windows Updates (Temporarily Disabling WSUS)" -ForegroundColor Cyan
    Write-Host "=========================================================" -ForegroundColor Cyan
    
    # Step 1: Disable WSUS
    if (Set-WindowsUpdatePolicy -DisableWsus $true) {
        # Step 2: Install pending updates
        $updateResult = Install-PendingWindowsUpdates
        
        # Step 3: Restore WSUS settings
        Set-WindowsUpdatePolicy -DisableWsus $false
        
        # Check if reboot is required
        if ($updateResult.RebootRequired) {
            Write-Host "`nA system restart is required to complete the installation of updates." -ForegroundColor Yellow
            
            $rebootChoice = Read-Host "Do you want to restart now? (Y/N)"
            if ($rebootChoice -eq "Y" -or $rebootChoice -eq "y") {
                Write-Host "Restarting system in 10 seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds 10
                Restart-Computer -Force
            } else {
                Write-Host "Please restart your system at your earliest convenience to complete the update process." -ForegroundColor Yellow
            }
        } else {
            Write-Host "`nAll updates have been installed successfully. No restart required." -ForegroundColor Green
        }
    } else {
        Write-Host "Failed to modify Windows Update settings. Update process aborted." -ForegroundColor Red
    }
} catch {
    Write-Host "An error occurred during the update process: $_" -ForegroundColor Red
    
    # Attempt to restore WSUS settings on error
    Set-WindowsUpdatePolicy -DisableWsus $false
}

Write-Host "`nProcess completed. WSUS settings have been restored." -ForegroundColor Cyan
