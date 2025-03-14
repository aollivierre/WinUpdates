# Install-PendingUpdatesWithoutWSUS-Dotnet.ps1
# Purpose: Temporarily disable WSUS, install all pending Windows updates with special focus on .NET Framework and modern .NET updates, and restore WSUS settings

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
        Write-Host "Error modifying Windows Update policy: $($Error[0].Message)" -ForegroundColor Red
        return $false
    }
}

# Function to check if a specific .NET update is already installed
function Test-DotNetUpdateInstalled {
    param (
        [string]$KB
    )
    
    try {
        $hotfix = Get-HotFix -Id $KB -ErrorAction SilentlyContinue
        return ($hotfix -ne $null)
    }
    catch {
        return $false
    }
}

# Function to detect currently installed .NET Framework versions
function Get-InstalledDotNetVersions {
    Write-Host "Detecting installed .NET Framework versions..." -ForegroundColor Cyan
    
    $dotNetVersions = @()
    
    # Check for .NET Framework 4.5 and later versions using registry
    $netRegKey = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
    if (Test-Path $netRegKey) {
        $release = (Get-ItemProperty $netRegKey -Name Release).Release
        
        if ($release -ge 528040) {
            $dotNetVersions += ".NET Framework 4.8"
        }
        elseif ($release -ge 461808) {
            $dotNetVersions += ".NET Framework 4.7.2"
        }
        elseif ($release -ge 461308) {
            $dotNetVersions += ".NET Framework 4.7.1"
        }
        elseif ($release -ge 460798) {
            $dotNetVersions += ".NET Framework 4.7"
        }
        elseif ($release -ge 394802) {
            $dotNetVersions += ".NET Framework 4.6.2"
        }
        elseif ($release -ge 394254) {
            $dotNetVersions += ".NET Framework 4.6.1"
        }
        elseif ($release -ge 393295) {
            $dotNetVersions += ".NET Framework 4.6"
        }
        elseif ($release -ge 379893) {
            $dotNetVersions += ".NET Framework 4.5.2"
        }
        elseif ($release -ge 378675) {
            $dotNetVersions += ".NET Framework 4.5.1"
        }
        elseif ($release -ge 378389) {
            $dotNetVersions += ".NET Framework 4.5"
        }
    }
    
    # Check for .NET Framework 3.5 and earlier
    $netFramework35 = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5" -Name Install -ErrorAction SilentlyContinue
    if ($netFramework35 -ne $null -and $netFramework35.Install -eq 1) {
        $dotNetVersions += ".NET Framework 3.5"
    }
    
    # Display detected versions
    if ($dotNetVersions.Count -gt 0) {
        Write-Host "Detected the following .NET Framework versions:" -ForegroundColor Green
        foreach ($version in $dotNetVersions) {
            Write-Host "  - $version" -ForegroundColor White
        }
    } else {
        Write-Host "No .NET Framework versions detected. This is unusual and may indicate an issue." -ForegroundColor Yellow
    }
    
    return $dotNetVersions
}

# Function to detect modern .NET (.NET Core 5+ and .NET 6/7/8) installations
function Get-InstalledModernDotNetVersions {
    Write-Host "Detecting installed modern .NET versions (.NET 5/6/7/8)..." -ForegroundColor Cyan
    
    $modernDotNetVersions = @()
    
    try {
        # Check if dotnet CLI is available
        $dotnetCliPath = Get-Command dotnet -ErrorAction SilentlyContinue
        
        if ($dotnetCliPath) {
            # Get global installed .NET runtimes
            $dotnetInfo = & dotnet --list-runtimes
            
            foreach ($line in $dotnetInfo) {
                if ($line -match "Microsoft\.NETCore\.App\s+(\d+\.\d+\.\d+)") {
                    $version = $matches[1]
                    $majorVersion = $version.Split('.')[0]
                    
                    # Only add .NET 5+ versions
                    if ([int]$majorVersion -ge 5) {
                        $modernDotNetVersions += ".NET $majorVersion ($version)"
                    }
                }
                
                if ($line -match "Microsoft\.AspNetCore\.App\s+(\d+\.\d+\.\d+)") {
                    $version = $matches[1]
                    $majorVersion = $version.Split('.')[0]
                    
                    # Only add ASP.NET 5+ versions
                    if ([int]$majorVersion -ge 5) {
                        $modernDotNetVersions += "ASP.NET Core $majorVersion ($version)"
                    }
                }
            }
        } else {
            # Alternative detection method using registry
            # .NET Core shared framework directory detection
            $programFiles = @("${env:ProgramFiles}", "${env:ProgramFiles(x86)}")
            foreach ($pf in $programFiles) {
                $dotnetPath = Join-Path $pf "dotnet\shared\Microsoft.NETCore.App"
                
                if (Test-Path $dotnetPath) {
                    $versionDirs = Get-ChildItem $dotnetPath -Directory
                    
                    foreach ($dir in $versionDirs) {
                        $version = $dir.Name
                        $majorVersion = $version.Split('.')[0]
                        
                        # Only add .NET 5+ versions
                        if ([int]$majorVersion -ge 5) {
                            $modernDotNetVersions += ".NET $majorVersion ($version)"
                        }
                    }
                }
                
                # ASP.NET Core shared framework
                $aspNetPath = Join-Path $pf "dotnet\shared\Microsoft.AspNetCore.App"
                
                if (Test-Path $aspNetPath) {
                    $versionDirs = Get-ChildItem $aspNetPath -Directory
                    
                    foreach ($dir in $versionDirs) {
                        $version = $dir.Name
                        $majorVersion = $version.Split('.')[0]
                        
                        # Only add ASP.NET 5+ versions
                        if ([int]$majorVersion -ge 5) {
                            $modernDotNetVersions += "ASP.NET Core $majorVersion ($version)"
                        }
                    }
                }
            }
        }
        
        # Display detected versions
        if ($modernDotNetVersions.Count -gt 0) {
            Write-Host "Detected the following modern .NET versions:" -ForegroundColor Green
            foreach ($version in ($modernDotNetVersions | Sort-Object -Unique)) {
                Write-Host "  - $version" -ForegroundColor White
            }
        } else {
            Write-Host "No modern .NET versions (5/6/7/8) detected." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error detecting modern .NET versions: $($Error[0].Message)" -ForegroundColor Red
    }
    
    return $modernDotNetVersions
}

# Function to download and install/update modern .NET
function Install-ModernDotNet {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("6", "7", "8")]
        [string]$Version,
        
        [Parameter(Mandatory=$false)]
        [string]$SpecificVersion = "",
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeAspNet = $false,
        
        [Parameter(Mandatory=$false)]
        [switch]$InstallSDK = $false
    )
    
    Write-Host "Setting up .NET $Version installation..." -ForegroundColor Cyan
    
    # Determine download URLs based on version
    $downloadBaseUrl = "https://dotnet.microsoft.com/download/dotnet"
    $downloadUrl = ""
    if ($InstallSDK) {
        $dotnetType = "sdk"
    } else {
        $dotnetType = "runtime"
    }
    
    try {
        # Temporary directory for downloads
        $tempDir = Join-Path $env:TEMP "DotNetInstall"
        if (-not (Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }
        
        # First, try to use the direct installer script approach
        Write-Host "Downloading .NET installer script..." -ForegroundColor Yellow
        $installerScript = Join-Path $tempDir "dotnet-install.ps1"
        
        # Download the dotnet-install.ps1 script
        $installerScriptUrl = "https://dot.net/v1/dotnet-install.ps1"
        Invoke-WebRequest -Uri $installerScriptUrl -OutFile $installerScript
        
        # Prepare arguments for the installer
        $installerArgs = @{
            Channel = "LTS"
        }
        
        if ($Version -eq "8") {
            $installerArgs.Channel = "8.0"
        } elseif ($Version -eq "7") {
            $installerArgs.Channel = "7.0"
        } elseif ($Version -eq "6") {
            $installerArgs.Channel = "6.0"
        }
        
        if ($SpecificVersion) {
            $installerArgs.Remove("Channel")
            $installerArgs.Version = $SpecificVersion
        }
        
        if ($InstallSDK) {
            Write-Host "Installing .NET $Version SDK..." -ForegroundColor Yellow
            & $installerScript -InstallDir "$env:ProgramFiles\dotnet" @installerArgs
        } else {
            Write-Host "Installing .NET $Version Runtime..." -ForegroundColor Yellow
            & $installerScript -InstallDir "$env:ProgramFiles\dotnet" -Runtime dotnet @installerArgs
            
            if ($IncludeAspNet) {
                Write-Host "Installing ASP.NET Core $Version Runtime..." -ForegroundColor Yellow
                & $installerScript -InstallDir "$env:ProgramFiles\dotnet" -Runtime aspnetcore @installerArgs
            }
        }
        
        # Verify installation
        Write-Host "Verifying installation..." -ForegroundColor Yellow
        $refreshEnv = $true
        
        # Add .NET to PATH if it's not there
        $dotnetPath = "$env:ProgramFiles\dotnet"
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        
        if (-not $currentPath.Contains($dotnetPath)) {
            [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$dotnetPath", "Machine")
            $env:PATH = "$env:PATH;$dotnetPath"
        }
        
        # Check if installation was successful
        $dotnetCliPath = Get-Command dotnet -ErrorAction SilentlyContinue
        
        if ($dotnetCliPath) {
            # Refresh environment
            if ($refreshEnv) {
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            }
            
            # Verify .NET version
            $dotnetVersion = & dotnet --list-runtimes
            $installSuccess = $false
            
            foreach ($line in $dotnetVersion) {
                # Check for runtime with specific version if provided
                if ($SpecificVersion -and $line -match $SpecificVersion) {
                    $installSuccess = $true
                    break
                }
                # Otherwise check for major version
                elseif ($line -match "$Version\.\d+\.\d+") {
                    $installSuccess = $true
                    break
                }
            }
            
            if ($installSuccess) {
                Write-Host ".NET $Version installation completed successfully." -ForegroundColor Green
                return $true
            } else {
                Write-Host ".NET $Version installation verification failed. The .NET CLI is available but the requested version was not found." -ForegroundColor Yellow
                return $false
            }
        } else {
            Write-Host ".NET installation verification failed. The .NET CLI is not available in the PATH." -ForegroundColor Red
            return $false
        }
    } catch {
        $errorMessage = $($_.Exception.Message)
        Write-Host "Error installing .NET $Version $errorMessage" -ForegroundColor Red
        
        # Fallback to browser download for manual installation if automatic installation fails
        Write-Host "Automatic installation failed. Please download and install .NET $Version manually from:" -ForegroundColor Yellow
        if ($Version -eq "8") {
            Write-Host "https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Cyan
        } elseif ($Version -eq "7") {
            Write-Host "https://dotnet.microsoft.com/download/dotnet/7.0" -ForegroundColor Cyan
        } elseif ($Version -eq "6") {
            Write-Host "https://dotnet.microsoft.com/download/dotnet/6.0" -ForegroundColor Cyan
        }
        
        return $false
    }
}

# Function to install pending Windows updates with special focus on .NET updates
function Install-PendingWindowsUpdates {
    param (
        [switch]$DotNetOnly,
        [switch]$DotNetFirst,
        [switch]$IncludePreviewUpdates = $false
    )
    
    Write-Host "Searching for pending Windows updates..." -ForegroundColor Cyan
    
    try {
        # Check if PSWindowsUpdate module is installed
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Host "PSWindowsUpdate module is not installed. Attempting to install..." -ForegroundColor Yellow
            Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
        }
        
        # Import PSWindowsUpdate module
        Import-Module PSWindowsUpdate
        
        # Get installed .NET versions for reference
        $installedDotNetVersions = Get-InstalledDotNetVersions
        
        # Get all pending updates
        Write-Host "Retrieving pending updates..." -ForegroundColor Yellow
        
        # Include preview updates if specified
        if ($IncludePreviewUpdates) {
            $AllUpdates = Get-WUList -IncludeNonInstallable | Where-Object { $_.IsHidden -eq $false }
        } else {
            $AllUpdates = Get-WUList | Where-Object { $_.IsHidden -eq $false }
        }
        
        $PendingUpdates = $AllUpdates | Where-Object { $_.IsInstalled -eq $false }
        
        if (-not $PendingUpdates) {
            Write-Host "No pending updates found." -ForegroundColor Green
            return @{
                Success = $true
                RebootRequired = $false
            }
        }
        
        # Filter and categorize updates
        $DotNetUpdates = $PendingUpdates | Where-Object { 
            $_.Title -match "\.NET" -or 
            $_.Title -match "Microsoft \.NET Framework" -or 
            $_.Categories -match "\.NET" -or 
            $_.Categories -match "Microsoft \.NET Framework" 
        }
        
        $OtherUpdates = $PendingUpdates | Where-Object { 
            $_.Title -notmatch "\.NET" -and 
            $_.Title -notmatch "Microsoft \.NET Framework" -and 
            $_.Categories -notmatch "\.NET" -and 
            $_.Categories -notmatch "Microsoft \.NET Framework" 
        }
        
        # Display update information
        if ($DotNetUpdates.Count -gt 0) {
            Write-Host "Found $($DotNetUpdates.Count) pending .NET Framework updates:" -ForegroundColor Cyan
            $index = 1
            foreach ($update in $DotNetUpdates) {
                $updateSize = [math]::Round($update.Size / 1MB, 2)
                Write-Host "$index. $($update.KB) - $($update.Title) ($updateSize MB)" -ForegroundColor White
                $index++
            }
        } else {
            Write-Host "No pending .NET Framework updates found." -ForegroundColor Yellow
        }
        
        if (-not $DotNetOnly -and $OtherUpdates.Count -gt 0) {
            Write-Host "`nFound $($OtherUpdates.Count) other pending updates:" -ForegroundColor Cyan
            $index = 1
            foreach ($update in $OtherUpdates) {
                Write-Host "$index. $($update.KB) - $($update.Title)" -ForegroundColor White
                $index++
            }
        }
        
        # Install updates based on options
        if ($DotNetOnly) {
            if ($DotNetUpdates.Count -gt 0) {
                Write-Host "`nInstalling .NET Framework updates only..." -ForegroundColor Yellow
                $DotNetUpdates | Install-WindowsUpdate -AcceptAll -IgnoreReboot -Install -Verbose
            } else {
                Write-Host "No .NET Framework updates to install." -ForegroundColor Yellow
            }
        } 
        elseif ($DotNetFirst) {
            if ($DotNetUpdates.Count -gt 0) {
                Write-Host "`nInstalling .NET Framework updates first..." -ForegroundColor Yellow
                $DotNetUpdates | Install-WindowsUpdate -AcceptAll -IgnoreReboot -Install -Verbose
                
                Write-Host "`nChecking for .NET installation status..." -ForegroundColor Cyan
                # Give a moment for updates to finalize before proceeding
                Start-Sleep -Seconds 5
            }
            
            if ($OtherUpdates.Count -gt 0) {
                Write-Host "`nInstalling other updates..." -ForegroundColor Yellow
                $OtherUpdates | Install-WindowsUpdate -AcceptAll -IgnoreReboot -Install -Verbose
            }
        } 
        else {
            # Install all updates together
            Write-Host "`nInstalling all updates..." -ForegroundColor Yellow
            $PendingUpdates | Install-WindowsUpdate -AcceptAll -IgnoreReboot -Install -Verbose
        }
        
        # Check .NET updates specifically
        if ($DotNetUpdates.Count -gt 0) {
            Write-Host "`nVerifying .NET Framework updates installation..." -ForegroundColor Cyan
            foreach ($update in $DotNetUpdates) {
                $kb = $update.KB
                if (Test-DotNetUpdateInstalled -KB $kb) {
                    Write-Host "  $kb - Successfully installed" -ForegroundColor Green
                } else {
                    Write-Host "  $kb - Installation may have failed or requires a reboot" -ForegroundColor Yellow
                }
            }
        }
        
        # Check if a reboot is required after installing updates
        Write-Host "`nChecking if reboot is required..." -ForegroundColor Yellow
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
            DotNetUpdatesCount = $DotNetUpdates.Count
        }
    } catch {
        $errorMessage = $($Error[0].Message)
        Write-Host "Error installing updates: $errorMessage" -ForegroundColor Red
        
        # Try to provide more specific details if it's a .NET-related error
        if ($($Error[0].Exception.Message) -match "\.NET") {
            Write-Host "This appears to be a .NET-specific error. Try running Windows Update troubleshooter or manually checking for updates from Microsoft." -ForegroundColor Yellow
        }
        return @{
            Success = $false
            RebootRequired = $false
        }
    }
}

# Function to fix common .NET update issues
function Repair-DotNetUpdateIssues {
    Write-Host "Attempting to repair common .NET Framework update issues..." -ForegroundColor Cyan
    
    # Stopping potentially interfering services
    Write-Host "Stopping Windows Update services..." -ForegroundColor Yellow
    Stop-Service -Name wuauserv -Force
    Stop-Service -Name bits -Force
    Stop-Service -Name cryptsvc -Force
    
    # Clear Windows Update cache
    Write-Host "Clearing Windows Update cache..." -ForegroundColor Yellow
    Remove-Item "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
    
    # Reset Windows Update components
    Write-Host "Resetting Windows Update components..." -ForegroundColor Yellow
    & "$env:SystemRoot\System32\wuauclt.exe" /resetauthorization /detectnow
    
    # Reset .NET Framework installation state
    Write-Host "Resetting .NET Framework installation state..." -ForegroundColor Yellow
    
    # Try to reset .NET Framework - this may be system-specific
    try {
        # For .NET Framework 4.x
        if (Test-Path "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319") {
            Write-Host "Running .NET Framework 4.x repair..." -ForegroundColor Yellow
            Start-Process "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\SetupCache\Setup.exe" -ArgumentList "/repair /quiet /norestart" -Wait -NoNewWindow
        }
    } catch {
        Write-Host "Warning: .NET Framework repair operation failed: $($Error[0].Message)" -ForegroundColor Yellow
    }
    
    # Restart services
    Write-Host "Restarting Windows Update services..." -ForegroundColor Yellow
    Start-Service -Name cryptsvc
    Start-Service -Name bits
    Start-Service -Name wuauserv
    
    Write-Host ".NET Framework repair operations completed." -ForegroundColor Green
}

# Function to handle installation and updates for .NET 8
function Install-DotNet8 {
    param (
        [string]$SpecificVersion = "8.0.13",
        [switch]$IncludeAspNet = $false,
        [switch]$InstallSDK = $false
    )
    
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host "  .NET 8 Installation and Update" -ForegroundColor Cyan
    Write-Host "======================================================" -ForegroundColor Cyan
    
    # First detect if .NET 8 is already installed
    $modernDotNetVersions = Get-InstalledModernDotNetVersions
    $dotNet8Installed = $false
    $dotNet8Version = $null

    foreach ($version in $modernDotNetVersions) {
        if ($version -match "8\.") {
            $dotNet8Installed = $true
            $dotNet8Version = $version
            break
        }
    }

    # Install or update based on current status
    if ($dotNet8Installed) {
        # Check if specific version is requested and different from installed
        if ($SpecificVersion -and $dotNet8Version -ne $SpecificVersion) {
            Write-Host ".NET 8 is already installed (version $dotNet8Version), but will be updated to version $SpecificVersion" -ForegroundColor Yellow
            return Install-ModernDotNet -Version "8" -SpecificVersion $SpecificVersion -IncludeAspNet:$IncludeAspNet -InstallSDK:$InstallSDK
        } else {
            Write-Host ".NET 8 is already installed (version $dotNet8Version)" -ForegroundColor Green
            # Ask if user wants to reinstall
            $reinstall = Read-Host "Do you want to reinstall/repair .NET 8? (Y/N)"
            if ($reinstall -eq "Y" -or $reinstall -eq "y") {
                return Install-ModernDotNet -Version "8" -SpecificVersion $SpecificVersion -IncludeAspNet:$IncludeAspNet -InstallSDK:$InstallSDK
            } else {
                return $true # Already installed and user doesn't want to reinstall
            }
        }
    } else {
        Write-Host ".NET 8 is not installed. Installing version $SpecificVersion..." -ForegroundColor Yellow
        return Install-ModernDotNet -Version "8" -SpecificVersion $SpecificVersion -IncludeAspNet:$IncludeAspNet -InstallSDK:$InstallSDK
    }
}

# Function to check for and install .NET runtime host updates (KB updates)
function Install-DotNetRuntimeHostUpdates {
    param (
        [Parameter(Mandatory=$false)]
        [switch]$BypassWSUS = $true
    )
    
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host "Checking for .NET Runtime Host Updates (KB updates)..." -ForegroundColor Cyan
    Write-Host "======================================================" -ForegroundColor Cyan
    
    # This function specifically looks for KB updates for .NET that come through Windows Update
    try {
        # Import or install PSWindowsUpdate module
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Host "PSWindowsUpdate module not found. Installing..." -ForegroundColor Yellow
            Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
        }
        
        Import-Module PSWindowsUpdate -ErrorAction Stop
        
        # If bypassing WSUS is enabled, temporarily modify registry settings
        if ($BypassWSUS) {
            $wsusModified = Set-WindowsUpdatePolicy -DisableWsus $true
            if (-not $wsusModified) {
                Write-Host "Failed to modify Windows Update settings. Continuing but updates may fail." -ForegroundColor Yellow
            } else {
                Write-Host "Temporarily disabled WSUS to allow direct Microsoft Update access." -ForegroundColor Green
            }
        }
        
        # Check specifically for .NET runtime host updates (will have KB numbers)
        Write-Host "Searching for .NET Runtime Host Updates..." -ForegroundColor Cyan
        
        # Use both .NET and .NET Core in the search patterns
        $dotNetUpdates = Get-WindowsUpdate -MicrosoftUpdate -FilterByName "*.NET*" -AcceptAll | 
                         Where-Object { $_.Title -match "KB\d+" -and ($_.Title -match "\.NET \d" -or $_.Title -match "\.NET Core") }
        
        if ($dotNetUpdates.Count -gt 0) {
            Write-Host "Found $($dotNetUpdates.Count) .NET Runtime Host Updates:" -ForegroundColor Green
            
            # Display the updates with KB numbers
            foreach ($update in $dotNetUpdates) {
                # Extract the KB number using regex
                if ($update.Title -match "(KB\d+)") {
                    $kbNumber = $matches[1]
                    Write-Host "  - $($update.Title) [$kbNumber]" -ForegroundColor Yellow
                } else {
                    Write-Host "  - $($update.Title)" -ForegroundColor Yellow
                }
            }
            
            # Prompt user to install
            $installUpdates = Read-Host "Do you want to install these .NET Runtime Host Updates? (Y/N)"
            
            if ($installUpdates -eq "Y" -or $installUpdates -eq "y") {
                Write-Host "Installing .NET Runtime Host Updates..." -ForegroundColor Cyan
                
                # Use the existing FilterByName approach for .NET updates
                Install-WindowsUpdate -MicrosoftUpdate -FilterByName "*.NET*" -AcceptAll -IgnoreReboot
                
                Write-Host ".NET Runtime Host Updates installation completed." -ForegroundColor Green
                $result = $true
            } else {
                Write-Host "Installation of .NET Runtime Host Updates skipped by user." -ForegroundColor Yellow
                $result = $false
            }
        } else {
            Write-Host "No .NET Runtime Host Updates found." -ForegroundColor Yellow
            $result = $true # Return true because there's no error
        }
        
        # Restore WSUS settings if they were modified
        if ($BypassWSUS -and $wsusModified) {
            $restored = Set-WindowsUpdatePolicy -DisableWsus $false
            if ($restored) {
                Write-Host "Windows Update settings restored to original configuration." -ForegroundColor Green
            } else {
                Write-Host "Failed to restore Windows Update settings. Check them manually." -ForegroundColor Red
            }
        }
        
        return $result
    } catch {
        $errorMessage = $($Error[0].Message)
        Write-Host "Error checking for .NET Runtime Host Updates: $errorMessage" -ForegroundColor Red
        
        # Attempt to restore WSUS settings on error if they were modified
        if ($BypassWSUS -and $wsusModified) {
            Set-WindowsUpdatePolicy -DisableWsus $false
        }
        
        return $false
    }
}

# Function to handle installation and updates for .NET 8
function Install-DotNet8 {
    param (
        [Parameter(Mandatory=$false)]
        [string]$SpecificVersion = "8.0.13",
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeAspNet = $false,
        
        [Parameter(Mandatory=$false)]
        [switch]$InstallSDK = $false,
        
        [Parameter(Mandatory=$false)]
        [switch]$CheckForRuntimeHostUpdates = $true
    )
    
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host "              .NET 8 Installation/Update              " -ForegroundColor Cyan
    Write-Host "======================================================" -ForegroundColor Cyan
    
    # Check if .NET 8 is already installed
    $dotNetVersions = Get-InstalledModernDotNetVersions
    $dotNet8Installed = $false
    $dotNet8Version = $null

    foreach ($version in $dotNetVersions) {
        if ($version -match "8\.") {
            $dotNet8Installed = $true
            $dotNet8Version = $version
            break
        }
    }

    # Install or update based on current status
    if ($dotNet8Installed) {
        # Check if specific version is requested and different from installed
        if ($SpecificVersion -and $dotNet8Version -ne $SpecificVersion) {
            Write-Host ".NET 8 is already installed (version $dotNet8Version), but will be updated to version $SpecificVersion" -ForegroundColor Yellow
            $installResult = Install-ModernDotNet -Version "8" -SpecificVersion $SpecificVersion -IncludeAspNet:$IncludeAspNet -InstallSDK:$InstallSDK
        } else {
            Write-Host ".NET 8 is already installed (version $dotNet8Version)" -ForegroundColor Green
            # Ask if user wants to reinstall
            $reinstall = Read-Host "Do you want to reinstall/repair .NET 8? (Y/N)"
            if ($reinstall -eq "Y" -or $reinstall -eq "y") {
                $installResult = Install-ModernDotNet -Version "8" -SpecificVersion $SpecificVersion -IncludeAspNet:$IncludeAspNet -InstallSDK:$InstallSDK
            } else {
                $installResult = $true # Already installed and user doesn't want to reinstall
            }
        }
    } else {
        Write-Host ".NET 8 is not installed. Installing version $SpecificVersion..." -ForegroundColor Yellow
        $installResult = Install-ModernDotNet -Version "8" -SpecificVersion $SpecificVersion -IncludeAspNet:$IncludeAspNet -InstallSDK:$InstallSDK
    }
    
    # If installation was successful and user wants to check for runtime host updates
    if ($installResult -and $CheckForRuntimeHostUpdates) {
        Write-Host "`nChecking for any available .NET 8 Runtime Host Updates (KB updates)..." -ForegroundColor Cyan
        Write-Host "These are security and servicing updates delivered through Windows Update." -ForegroundColor Cyan
        
        $updateResult = Install-DotNetRuntimeHostUpdates
        
        return $installResult -and $updateResult
    }
    
    return $installResult
}

# Main script execution
try {
    Clear-Host
    
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host "   .NET Framework and Modern .NET Update Utility      " -ForegroundColor Cyan
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Display installed .NET Framework versions
    $netFrameworkVersions = Get-InstalledDotNetFrameworkVersions
    
    # Display installed modern .NET versions
    $modernDotNetVersions = Get-InstalledModernDotNetVersions
    
    Write-Host "Please select an installation option:" -ForegroundColor Green
    Write-Host "  1: Install .NET Framework updates only" -ForegroundColor Yellow
    Write-Host "  2: Install .NET Framework updates first, then other updates" -ForegroundColor Yellow
    Write-Host "  3: Install all Windows updates (default)" -ForegroundColor Yellow
    Write-Host "  4: Repair .NET Framework update issues, then install updates" -ForegroundColor Yellow
    Write-Host "  5: Install or update .NET 8.0.13 (modern .NET)" -ForegroundColor Yellow
    Write-Host "  6: Install or update specific .NET version (6.0, 7.0, or 8.0)" -ForegroundColor Yellow
    Write-Host "  7: Check and install .NET Runtime Host Updates (KB updates)" -ForegroundColor Yellow
    
    $option = Read-Host "Choose an option (1-7)"
    
    # Set variables based on selected option
    switch ($option) {
        "1" {
            $onlyNetFramework = $true
            $netFrameworkFirst = $false
            $repair = $false
            $modernDotNet = $false
            $runtimeHostUpdates = $false
        }
        "2" {
            $onlyNetFramework = $false
            $netFrameworkFirst = $true
            $repair = $false
            $modernDotNet = $false
            $runtimeHostUpdates = $false
        }
        "3" {
            $onlyNetFramework = $false
            $netFrameworkFirst = $false
            $repair = $false
            $modernDotNet = $false
            $runtimeHostUpdates = $false
        }
        "4" {
            $onlyNetFramework = $false
            $netFrameworkFirst = $false
            $repair = $true
            $modernDotNet = $false
            $runtimeHostUpdates = $false
        }
        "5" {
            $onlyNetFramework = $false
            $netFrameworkFirst = $false
            $repair = $false
            $modernDotNet = "8"
            $specificVersion = "8.0.13"
            $runtimeHostUpdates = $false
        }
        "6" {
            $onlyNetFramework = $false
            $netFrameworkFirst = $false
            $repair = $false
            $modernDotNet = "custom"
            $runtimeHostUpdates = $false
        }
        "7" {
            $onlyNetFramework = $false
            $netFrameworkFirst = $false
            $repair = $false
            $modernDotNet = $false
            $runtimeHostUpdates = $true
        }
        default {
            $onlyNetFramework = $false
            $netFrameworkFirst = $false
            $repair = $false
            $modernDotNet = $false
            $runtimeHostUpdates = $false
        }
    }
    
    # For options 1-4, ask about preview updates
    if ($option -eq "1" -or $option -eq "2" -or $option -eq "3" -or $option -eq "4") {
        Write-Host "Include preview updates?" -ForegroundColor Yellow
        $includePreview = Read-Host "Y/N (default: N)"
        $includePreviewUpdates = ($includePreview -eq "Y" -or $includePreview -eq "y")
    }
    
    # For option 6, ask for specific .NET version details
    if ($modernDotNet -eq "custom") {
        Write-Host "`nWhich .NET version would you like to install?" -ForegroundColor Yellow
        Write-Host "  1: .NET 6.0 (LTS)" -ForegroundColor Green
        Write-Host "  2: .NET 7.0" -ForegroundColor Green
        Write-Host "  3: .NET 8.0 (LTS)" -ForegroundColor Green
        
        $versionChoice = Read-Host "Choose a version (1-3)"
        
        switch ($versionChoice) {
            "1" { $modernDotNet = "6" }
            "2" { $modernDotNet = "7" }
            "3" { $modernDotNet = "8" }
            default { $modernDotNet = "8" }
        }
        
        # Ask if they want to include ASP.NET Core
        Write-Host "`nInclude ASP.NET Core components?" -ForegroundColor Yellow
        $includeAspNetResp = Read-Host "Y/N (default: N)"
        $includeAspNet = ($includeAspNetResp -eq "Y" -or $includeAspNetResp -eq "y")
        
        # Ask if they want to install the SDK instead of just Runtime
        Write-Host "`nInstall SDK instead of Runtime?" -ForegroundColor Yellow
        $installSDKResp = Read-Host "Y/N (default: N)"
        $installSDK = ($installSDKResp -eq "Y" -or $installSDKResp -eq "y")
        
        # Ask for specific version
        Write-Host "`nSpecify a version number? (e.g., 8.0.13, 6.0.28)" -ForegroundColor Yellow
        Write-Host "Leave blank for latest version." -ForegroundColor Gray
        $specificVersion = Read-Host "Version number"
    }
    
    # Repair .NET Framework if requested
    if ($repair) {
        Write-Host "Repairing .NET Framework..." -ForegroundColor Cyan
        Repair-DotNetFramework
    }
    
    # Handle .NET installations
    if ($runtimeHostUpdates) {
        # Just check for and install runtime host updates
        Write-Host "`nChecking for .NET Runtime Host Updates (KB updates)..." -ForegroundColor Cyan
        $modifyWSUS = Set-WindowsUpdatePolicy -DisableWsus $true
        Install-DotNetRuntimeHostUpdates
        Set-WindowsUpdatePolicy -DisableWsus $false
    }
    elseif ($modernDotNet -eq "8" -and $specificVersion) {
        # Install/update .NET 8 with a specific version
        Install-DotNet8 -SpecificVersion $specificVersion -IncludeAspNet:$includeAspNet -InstallSDK:$installSDK
    }
    elseif ($modernDotNet -and $modernDotNet -ne "custom") {
        # Install modern .NET with user-provided parameters
        if ($specificVersion) {
            Install-ModernDotNet -Version $modernDotNet -SpecificVersion $specificVersion -IncludeAspNet:$includeAspNet -InstallSDK:$installSDK
        } else {
            Install-ModernDotNet -Version $modernDotNet -IncludeAspNet:$includeAspNet -InstallSDK:$installSDK
        }
    }
    else {
        # For Windows Update related options (1-4)
        # Disable WSUS temporarily to allow direct access to Microsoft Update servers
        $modifyWSUS = Set-WindowsUpdatePolicy -DisableWsus $true
        
        if ($modifyWSUS) {
            # Install updates based on selected options
            $result = Install-PendingUpdates -InstallNetFrameworkUpdatesFirst $netFrameworkFirst -OnlyInstallNetFrameworkUpdates $onlyNetFramework -IncludePreviewUpdates $includePreviewUpdates
            
            # Display results
            if ($result.NetFrameworkUpdatesCount -gt 0 -or $result.AllUpdatesCount -gt 0) {
                Write-Host "Update Summary:" -ForegroundColor Green
                if ($result.NetFrameworkUpdatesCount -gt 0) {
                    Write-Host "  .NET Framework Updates: $($result.NetFrameworkUpdatesCount) installed" -ForegroundColor Green
                }
                if ($result.AllUpdatesCount -gt 0) {
                    Write-Host "  Total Updates: $($result.AllUpdatesCount) installed" -ForegroundColor Green
                }
            } else {
                Write-Host "No updates were installed." -ForegroundColor Yellow
            }
            
            # Reenable WSUS
            Set-WindowsUpdatePolicy -DisableWsus $false
        } else {
            Write-Host "Failed to modify Windows Update settings. Update process aborted." -ForegroundColor Red
        }
    }
} catch {
    $errorMessage = $($Error[0].Message)
    Write-Host "An error occurred during the update process: $errorMessage" -ForegroundColor Red
    
    # Attempt to restore WSUS settings on error
    Set-WindowsUpdatePolicy -DisableWsus $false
}

Write-Host "`nScript execution completed. Check the output above for results and any errors." -ForegroundColor Green
Write-Host "If you still have issues with .NET updates, visit https://www.catalog.update.microsoft.com" -ForegroundColor Yellow
