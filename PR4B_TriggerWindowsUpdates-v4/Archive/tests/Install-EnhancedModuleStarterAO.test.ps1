function CheckAndElevate {
    <#
    .SYNOPSIS
    Checks if the script is running with administrative privileges and optionally elevates it if not.

    .DESCRIPTION
    The CheckAndElevate function checks whether the current PowerShell session is running with administrative privileges. 
    It can either return the administrative status or attempt to elevate the script if it is not running as an administrator.

    .PARAMETER ElevateIfNotAdmin
    If set to $true, the function will attempt to elevate the script if it is not running with administrative privileges. 
    If set to $false, the function will simply return the administrative status without taking any action.

    .EXAMPLE
    CheckAndElevate -ElevateIfNotAdmin $true

    Checks the current session for administrative privileges and elevates if necessary.

    .EXAMPLE
    $isAdmin = CheckAndElevate -ElevateIfNotAdmin $false
    if (-not $isAdmin) {
        Write-Host "The script is not running with administrative privileges."
    }

    Checks the current session for administrative privileges and returns the status without elevating.
    
    .NOTES
    If the script is elevated, it will restart with administrative privileges. Ensure that any state or data required after elevation is managed appropriately.
    #>

    [CmdletBinding()]
    param (
        [bool]$ElevateIfNotAdmin = $true
    )

    Begin {
        Write-EnhancedModuleStarterLog -Message "Starting CheckAndElevate function" -Level "NOTICE"

        # Use .NET classes for efficiency
        try {
            $isAdmin = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
            Write-EnhancedModuleStarterLog -Message "Checking for administrative privileges..." -Level "INFO"
        }
        catch {
            Write-EnhancedModuleStarterLog -Message "Error determining administrative status: $($_.Exception.Message)" -Level "ERROR"
            Handle-Error -ErrorRecord $_
            throw $_
        }
    }

    Process {
        if (-not $isAdmin) {
            if ($ElevateIfNotAdmin) {
                try {
                    Write-EnhancedModuleStarterLog -Message "The script is not running with administrative privileges. Attempting to elevate..." -Level "WARNING"

                    $powerShellPath = Get-PowerShellPath
                    $startProcessParams = @{
                        FilePath     = $powerShellPath
                        ArgumentList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
                        Verb         = "RunAs"
                    }
                    Start-Process @startProcessParams

                    Write-EnhancedModuleStarterLog -Message "Script re-launched with administrative privileges. Exiting current session." -Level "INFO"
                    exit
                }
                catch {
                    Write-EnhancedModuleStarterLog -Message "Failed to elevate privileges: $($_.Exception.Message)" -Level "ERROR"
                    Handle-Error -ErrorRecord $_
                    throw $_
                }
            }
            else {
                Write-EnhancedModuleStarterLog -Message "The script is not running with administrative privileges and will continue without elevation." -Level "INFO"
            }
        }
        else {
            Write-EnhancedModuleStarterLog -Message "Script is already running with administrative privileges." -Level "INFO"
        }
    }

    End {
        Write-EnhancedModuleStarterLog -Message "Exiting CheckAndElevate function" -Level "NOTICE"
        return $isAdmin
    }
}

function Get-ParentScriptName {
    [CmdletBinding()]
    param ()

    try {
        # Get the current call stack
        $callStack = Get-PSCallStack

        # If there is a call stack, return the top-most script name
        if ($callStack.Count -gt 0) {
            foreach ($frame in $callStack) {
                if ($frame.ScriptName) {
                    $parentScriptName = $frame.ScriptName
                    # Write-EnhancedModuleStarterLog -Message "Found script in call stack: $parentScriptName" -Level "INFO"
                }
            }

            if (-not [string]::IsNullOrEmpty($parentScriptName)) {
                $parentScriptName = [System.IO.Path]::GetFileNameWithoutExtension($parentScriptName)
                return $parentScriptName
            }
        }

        # If no script name was found, return 'UnknownScript'
        # Write-EnhancedModuleStarterLog -Message "No script name found in the call stack." -Level "WARNING"
        return "UnknownScript"
    }
    catch {
        # Write-EnhancedModuleStarterLog -Message "An error occurred while retrieving the parent script name: $_" -Level "ERROR"
        return "UnknownScript"
    }
}

function Write-EnhancedModuleStarterLog {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    # Get the PowerShell call stack to determine the actual calling function
    $callStack = Get-PSCallStack
    $callerFunction = if ($callStack.Count -ge 2) { $callStack[1].Command } else { '<Unknown>' }

    # Get the parent script name
    $parentScriptName = Get-ParentScriptName

    # Prepare the formatted message with the actual calling function information
    $formattedMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] [$parentScriptName.$callerFunction] $Message"

    # Display the log message based on the log level using Write-Host
    switch ($Level.ToUpper()) {
        "DEBUG" { Write-Host $formattedMessage -ForegroundColor DarkGray }
        "INFO" { Write-Host $formattedMessage -ForegroundColor Green }
        "NOTICE" { Write-Host $formattedMessage -ForegroundColor Cyan }
        "WARNING" { Write-Host $formattedMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $formattedMessage -ForegroundColor Red }
        "CRITICAL" { Write-Host $formattedMessage -ForegroundColor Magenta }
        default { Write-Host $formattedMessage -ForegroundColor White }
    }

    # Append to log file
    $logFilePath = [System.IO.Path]::Combine($env:TEMP, 'Module-Starter.log')
    $formattedMessage | Out-File -FilePath $logFilePath -Append -Encoding utf8
}

function Reset-ModulePaths {
    [CmdletBinding()]
    param ()

    begin {
        # Initialization block, typically used for setup tasks
        Write-EnhancedModuleStarterLog -Message "Initializing Reset-ModulePaths function..." -Level "DEBUG"
    }

    process {
        try {
            # Log the start of the process
            Write-EnhancedModuleStarterLog -Message "Resetting module paths to default values..." -Level "INFO"

            # Get the current user's Documents path
            $userModulesPath = [System.IO.Path]::Combine($env:USERPROFILE, 'Documents\WindowsPowerShell\Modules')

            # Define the default module paths
            $defaultModulePaths = @(
                "C:\Program Files\WindowsPowerShell\Modules",
                $userModulesPath,
                "C:\Windows\System32\WindowsPowerShell\v1.0\Modules"
            )

            # Attempt to reset the PSModulePath environment variable
            $env:PSModulePath = [string]::Join(';', $defaultModulePaths)
            Write-EnhancedModuleStarterLog "PSModulePath successfully set to: $($env:PSModulePath -split ';' | Out-String)" -Level "INFO"

            # Optionally persist the change for the current user
            [Environment]::SetEnvironmentVariable("PSModulePath", $env:PSModulePath, [EnvironmentVariableTarget]::User)
            Write-EnhancedModuleStarterLog -Message "PSModulePath environment variable set for the current user." -Level "INFO"
        }
        catch {
            # Capture and log any errors that occur during the process
            $errorMessage = $_.Exception.Message
            Write-EnhancedModuleStarterLog -Message "Error resetting module paths: $errorMessage" -Level "ERROR"

            # Optionally, you could throw the error to halt the script
            throw $_
        }
    }

    end {
        # Finalization block, typically used for cleanup tasks
        Write-EnhancedModuleStarterLog -Message "Reset-ModulePaths function completed." -Level "DEBUG"
    }
}

function Handle-Error {
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $fullErrorDetails = Get-Error -InputObject $ErrorRecord | Out-String
        }
        else {
            $fullErrorDetails = $ErrorRecord.Exception | Format-List * -Force | Out-String
        }

        Write-EnhancedModuleStarterLog -Message "Exception Message: $($ErrorRecord.Exception.Message)" -Level "ERROR"
        Write-EnhancedModuleStarterLog -Message "Full Exception: $fullErrorDetails" -Level "ERROR"
    }
    catch {
        # Fallback error handling in case of an unexpected error in the try block
        Write-EnhancedModuleStarterLog -Message "An error occurred while handling another error. Original Exception: $($ErrorRecord.Exception.Message)" -Level "CRITICAL"
        Write-EnhancedModuleStarterLog -Message "Handler Exception: $($_.Exception.Message)" -Level "CRITICAL"
        Write-EnhancedModuleStarterLog -Message "Handler Full Exception: $($_ | Out-String)" -Level "CRITICAL"
    }
}

function Remove-OldVersions {
    <#
    .SYNOPSIS
    Removes older versions of a specified PowerShell module.

    .DESCRIPTION
    The Remove-OldVersions function removes all but the latest version of the specified PowerShell module. It ensures that only the most recent version is retained.

    .PARAMETER ModuleName
    The name of the module for which older versions will be removed.

    .EXAMPLE
    Remove-OldVersions -ModuleName "Pester"
    Removes all but the latest version of the Pester module.

    .NOTES
    This function requires administrative access to manage modules and assumes that the CheckAndElevate function is defined elsewhere in the script.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    begin {
        Write-EnhancedModuleStarterLog -Message "Starting Remove-OldVersions function for module: $ModuleName" -Level "INFO"
        # Log-Params -Params $PSCmdlet.MyInvocation.BoundParameters
    }

    process {
        # Get all versions except the latest one
        $allVersions = Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version
        $latestVersion = $allVersions | Select-Object -Last 1
        $olderVersions = $allVersions | Where-Object { $_.Version -ne $latestVersion.Version }

        foreach ($version in $olderVersions) {
            try {
                Write-EnhancedModuleStarterLog -Message "Removing older version $($version.Version) of $ModuleName..." -Level "INFO"
                $modulePath = $version.ModuleBase

                Write-EnhancedModuleStarterLog -Message "Starting takeown and icacls for $modulePath" -Level "INFO"
                Write-EnhancedModuleStarterLog -Message "Checking and elevating to admin if needed" -Level "INFO"
                CheckAndElevate -ElevateIfNotAdmin $true
                & takeown.exe /F $modulePath /A /R
                & icacls.exe $modulePath /reset
                & icacls.exe $modulePath /grant "*S-1-5-32-544:F" /inheritance:d /T
                Remove-Item -Path $modulePath -Recurse -Force -Confirm:$false

                Write-EnhancedModuleStarterLog -Message "Removed $($version.Version) successfully." -Level "INFO"
            }
            catch {
                Write-EnhancedModuleStarterLog -Message "Failed to remove version $($version.Version) of $ModuleName at $modulePath. Error: $_" -Level "ERROR"
                Handle-Error -ErrorRecord $_
            }
        }
    }

    end {
        Write-EnhancedModuleStarterLog -Message "Remove-OldVersions function execution completed for module: $ModuleName" -Level "INFO"
    }
}           


function Install-ModuleInPS5 {
    <#
    .SYNOPSIS
    Installs a PowerShell module in PowerShell 5 and validates the installation.

    .DESCRIPTION
    The Install-ModuleInPS5 function installs a specified PowerShell module using PowerShell 5. It ensures that the module is installed in the correct environment and logs the entire process. It handles errors gracefully and validates the installation after completion.

    .PARAMETER ModuleName
    The name of the PowerShell module to install in PowerShell 5.

    .EXAMPLE
    $params = @{
        ModuleName = "Az"
    }
    Install-ModuleInPS5 @params
    Installs the specified PowerShell module using PowerShell 5 and logs the process.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Provide the name of the module to install.")]
        [ValidateNotNullOrEmpty()]
        [string]$ModuleName
    )

    Begin {
        Write-EnhancedModuleStarterLog -Message "Starting Install-ModuleInPS5 function" -Level "Notice"
        # Log-Params -Params $PSCmdlet.MyInvocation.BoundParameters

        Reset-ModulePaths

        CheckAndElevate -ElevateIfNotAdmin $true

        # Path to PowerShell 5
        $ps5Path = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

        # Validate if PowerShell 5 exists
        if (-not (Test-Path $ps5Path)) {
            throw "PowerShell 5 executable not found: $ps5Path"
        }
    }

    Process {
        try {
            Write-EnhancedModuleStarterLog -Message "Preparing to install module: $ModuleName in PowerShell 5" -Level "INFO"

            # PowerShell 5 command to install the module
            $ps5Command = "Install-Module -Name $ModuleName -Scope Allusers -SkipPublisherCheck -Force -Confirm:`$false"

            # Log the parameters being passed to Start-Process
            Write-EnhancedModuleStarterLog -Message "Starting installation of module $ModuleName in PowerShell 5" -Level "INFO"

            # Use Start-Process to launch PowerShell 5 and install the module
            $process = Start-Process -FilePath $ps5Path -ArgumentList "-Command", $ps5Command `
                -Wait -NoNewWindow -PassThru

            # Check if the process succeeded
            if ($process.ExitCode -eq 0) {
                Write-EnhancedModuleStarterLog -Message "Module '$ModuleName' installed successfully in PS5" -Level "INFO"
            }
            else {
                Write-EnhancedModuleStarterLog -Message "Error occurred during module installation. Exit Code: $($process.ExitCode)" -Level "ERROR"
            }
        }
        catch {
            Write-EnhancedModuleStarterLog -Message "Error installing module: $($_.Exception.Message)" -Level "ERROR"
            Handle-Error -ErrorRecord $_
            throw
        }
        Finally {
            # Always log exit and cleanup actions
            Write-EnhancedModuleStarterLog -Message "Exiting Install-ModuleInPS5 function" -Level "Notice"
        }
    }

    End {
        Write-EnhancedModuleStarterLog -Message "Validating module installation in PS5" -Level "INFO"
        
        # Validate the module installation by checking if the module is available in PS5
        $ps5ValidateCommand = "Get-Module -ListAvailable -Name $ModuleName"
        $moduleInstalled = Start-Process -FilePath $ps5Path -ArgumentList "-Command", $ps5ValidateCommand `
            -NoNewWindow -PassThru -Wait

        if ($moduleInstalled.ExitCode -eq 0) {
            Write-EnhancedModuleStarterLog -Message "Module $ModuleName validated successfully in PS5" -Level "INFO"
        }
        else {
            Write-EnhancedModuleStarterLog -Message "Module $ModuleName validation failed in PS5" -Level "ERROR"
            throw "Module $ModuleName installation could not be validated in PS5"
        }
    }
}

function Check-ModuleVersionStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$ModuleNames
    )

    #the following modules PowerShellGet and PackageManagement has to be either automatically imported or manually imported into C:\windows\System32\WindowsPowerShell\v1.0\Modules

    Import-Module -Name PowerShellGet -ErrorAction SilentlyContinue

    $results = [System.Collections.Generic.List[PSObject]]::new()  # Initialize a List to hold the results

    foreach ($ModuleName in $ModuleNames) {
        try {

            Write-EnhancedModuleStarterLog -Message "Checking module $ModuleName"
            $installedModule = Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version -Descending | Select-Object -First 1
            # $installedModule = Check-SystemWideModule -ModuleName 'Pester'
            $latestModule = Find-Module -Name $ModuleName -ErrorAction SilentlyContinue

            if ($installedModule -and $latestModule) {
                if ($installedModule.Version -lt $latestModule.Version) {
                    $results.Add([PSCustomObject]@{
                            ModuleName       = $ModuleName
                            Status           = "Outdated"
                            InstalledVersion = $installedModule.Version
                            LatestVersion    = $latestModule.Version
                        })
                }
                else {
                    $results.Add([PSCustomObject]@{
                            ModuleName       = $ModuleName
                            Status           = "Up-to-date"
                            InstalledVersion = $installedModule.Version
                            LatestVersion    = $installedModule.Version
                        })
                }
            }
            elseif (-not $installedModule) {
                $results.Add([PSCustomObject]@{
                        ModuleName       = $ModuleName
                        Status           = "Not Installed"
                        InstalledVersion = $null
                        LatestVersion    = $null
                    })
            }
            else {
                $results.Add([PSCustomObject]@{
                        ModuleName       = $ModuleName
                        Status           = "Not Found in Gallery"
                        InstalledVersion = $null
                        LatestVersion    = $null
                    })
            }
        }
        catch {
            Write-Error "An error occurred checking module '$ModuleName': $_"
        }
    }

    return $results
}

function Update-ModuleIfOldOrMissing {
    <#
    .SYNOPSIS
    Updates or installs a specified PowerShell module if it is outdated or missing.

    .DESCRIPTION
    The Update-ModuleIfOldOrMissing function checks the status of a specified PowerShell module and updates it if it is outdated. If the module is not installed, it installs the latest version. It also removes older versions after the update.

    .PARAMETER ModuleName
    The name of the module to be checked and updated or installed.

    .EXAMPLE
    Update-ModuleIfOldOrMissing -ModuleName "Pester"
    Checks and updates the Pester module if it is outdated or installs it if not present.

    .NOTES
    This function requires administrative access to manage modules and assumes that the CheckAndElevate, Check-ModuleVersionStatus, and Remove-OldVersions functions are defined elsewhere in the script.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    begin {
        Write-EnhancedModuleStarterLog -Message "Starting Update-ModuleIfOldOrMissing function for module: $ModuleName" -Level "Notice"
        # Log-Params -Params $PSCmdlet.MyInvocation.BoundParameters
    }

    process {
        $moduleStatus = Check-ModuleVersionStatus -ModuleNames @($ModuleName)
        foreach ($status in $moduleStatus) {
            switch ($status.Status) {
                "Outdated" {
                    Write-EnhancedModuleStarterLog -Message "Updating $ModuleName from version $($status.InstalledVersion) to $($status.LatestVersion)." -Level "WARNING"

                    # Remove older versions
                    Remove-OldVersions -ModuleName $ModuleName

                    # Install the latest version of the module
                    # Install-Module -Name $ModuleName -Force -SkipPublisherCheck -Scope AllUsers

                    

                    # Invoke-InPowerShell5 -ScriptPath $PSScriptRoot
                    # Invoke-InPowerShell5

                    $params = @{
                        ModuleName = "$ModuleName"
                    }
                    Install-ModuleInPS5 @params

                    # Install-ModuleWithPowerShell5Fallback -ModuleName $ModuleName

                    Write-EnhancedModuleStarterLog -Message "$ModuleName has been updated to the latest version." -Level "INFO"
                }
                "Up-to-date" {
                    Write-EnhancedModuleStarterLog -Message "$ModuleName version $($status.InstalledVersion) is up-to-date. No update necessary." -Level "INFO"
                    Remove-OldVersions -ModuleName $ModuleName
                }
                "Not Installed" {
                    Write-EnhancedModuleStarterLog -Message "$ModuleName is not installed. Installing the latest version..." -Level "WARNING"
                    # Install-Module -Name $ModuleName -Force -SkipPublisherCheck -Scope AllUsers

                    # $DBG


                    $params = @{
                        ModuleName = "$ModuleName"
                    }
                    Install-ModuleInPS5 @params

                    # Invoke-InPowerShell5
                    # Install-ModuleWithPowerShell5Fallback -ModuleName $ModuleName
                    Write-EnhancedModuleStarterLog -Message "$ModuleName has been installed." -Level "INFO"
                }
                "Not Found in Gallery" {
                    Write-EnhancedModuleStarterLog -Message "Unable to find '$ModuleName' in the PowerShell Gallery." -Level "ERROR"
                }
            }
        }
    }

    end {
        Write-EnhancedModuleStarterLog -Message "Update-ModuleIfOldOrMissing function execution completed for module: $ModuleName" -Level "Notice"
    }
}


Update-ModuleIfOldOrMissing -ModuleName 'PSFramework'
Update-ModuleIfOldOrMissing -ModuleName 'EnhancedModuleStarterAO'