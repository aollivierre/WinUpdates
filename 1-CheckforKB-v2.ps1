# Set environment variable globally for all users
[System.Environment]::SetEnvironmentVariable('EnvironmentMode', 'prod', 'Machine')

# Retrieve the environment mode (default to 'prod' if not set)
$mode = $env:EnvironmentMode

#region FIRING UP MODULE STARTER
#################################################################################################
#                                                                                               #
#                                 FIRING UP MODULE STARTER                                      #
#                                                                                               #
#################################################################################################

Invoke-Expression (Invoke-RestMethod "https://raw.githubusercontent.com/aollivierre/module-starter/main/Install-EnhancedModuleStarterAO.ps1")

# Wait-Debugger

# Define a hashtable for splatting
$moduleStarterParams = @{
    Mode                   = 'prod'
    SkipPSGalleryModules   = $false
    SkipCheckandElevate    = $false
    SkipPowerShell7Install = $false
    SkipEnhancedModules    = $false
    SkipGitRepos           = $false
}

# Call the function using the splat
Invoke-ModuleStarter @moduleStarterParams


# Wait-Debugger

#endregion FIRING UP MODULE STARTER

# Toggle based on the environment mode
switch ($mode) {
    'dev' {
        Write-EnhancedLog -Message "Running in development mode" -Level 'WARNING'
        # Your development logic here
    }
    'prod' {
        Write-EnhancedLog -Message "Running in production mode" -ForegroundColor Green
        # Your production logic here
    }
    default {
        Write-EnhancedLog -Message "Unknown mode. Defaulting to production." -ForegroundColor Red
        # Default to production
    }
}

#region HANDLE PSF MODERN LOGGING
#################################################################################################
#                                                                                               #
#                            HANDLE PSF MODERN LOGGING                                          #
#                                                                                               #
#################################################################################################
Set-PSFConfig -Fullname 'PSFramework.Logging.FileSystem.ModernLog' -Value $true -PassThru | Register-PSFConfig -Scope SystemDefault

# Define the base logs path and job name
$JobName = "AAD_Migration"
$parentScriptName = Get-ParentScriptName
Write-EnhancedLog -Message "Parent Script Name: $parentScriptName"

# Call the Get-PSFCSVLogFilePath function to generate the dynamic log file path
$paramGetPSFCSVLogFilePath = @{
    LogsPath         = 'C:\Logs\PSF'
    JobName          = $jobName
    parentScriptName = $parentScriptName
}

$csvLogFilePath = Get-PSFCSVLogFilePath @paramGetPSFCSVLogFilePath

$instanceName = "$parentScriptName-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Configure the PSFramework logging provider to use CSV format
$paramSetPSFLoggingProvider = @{
    Name            = 'logfile'
    InstanceName    = $instanceName  # Use a unique instance name
    FilePath        = $csvLogFilePath  # Use the dynamically generated file path
    Enabled         = $true
    FileType        = 'CSV'
    EnableException = $true
}
Set-PSFLoggingProvider @paramSetPSFLoggingProvider
#endregion HANDLE PSF MODERN LOGGING


#region HANDLE Transript LOGGING
#################################################################################################
#                                                                                               #
#                            HANDLE Transript LOGGING                                           #
#                                                                                               #
#################################################################################################
# Start the script with error handling
try {
    # Generate the transcript file path
    $GetTranscriptFilePathParams = @{
        TranscriptsPath  = "C:\Logs\Transcript"
        JobName          = $jobName
        parentScriptName = $parentScriptName
    }
    $transcriptPath = Get-TranscriptFilePath @GetTranscriptFilePathParams
    
    # Start the transcript
    Write-EnhancedLog -Message "Starting transcript at: $transcriptPath"
    Start-Transcript -Path $transcriptPath
}
catch {
    Write-EnhancedLog -Message "An error occurred during script execution: $_" -Level 'ERROR'
    if ($transcriptPath) {
        Stop-Transcript
        Write-EnhancedLog -Message "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -ForegroundColor Red
    }

    # Stop PSF Logging

    # Ensure the log is written before proceeding
    Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

    Handle-Error -ErrorRecord $_
    throw $_  # Re-throw the error after logging it
}
#endregion HANDLE Transript LOGGING

try {
    #region Script Logic
    #################################################################################################
    #                                                                                               #
    #                                    Script Logic                                               #
    #                                                                                               #
    #################################################################################################


    Import-Module PSWindowsUpdate
    # Get-WUList
    # Wait-Debugger

    function Check-WindowsUpdates {
        <#
        .SYNOPSIS
        Checks for installed and pending Windows Updates and logs the results.
    
        .DESCRIPTION
        The Check-WindowsUpdates function checks for installed and pending Windows Updates based on either specific KB articles or all updates. It logs the results, checks if a reboot is required, and handles errors gracefully.
    
        .PARAMETER KBArticles
        A list of specific KB articles to check for installation status.
    
        .PARAMETER CheckAllUpdates
        A switch to check all installed and pending updates.
    
        .EXAMPLE
        $params = @{
            KBArticles     = @('KB1234567', 'KB2345678')
        }
        Check-WindowsUpdates @params
        Checks if the specified KB articles are installed and logs the results.
        #>
    
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $false, HelpMessage = "Provide a list of KB articles to check.")]
            [string[]]$KBArticles,
    
            [Parameter(Mandatory = $false, HelpMessage = "Switch to check all installed and pending updates.")]
            [switch]$CheckAllUpdates
        )
    
        Begin {
            Write-EnhancedLog -Message "Starting Check-WindowsUpdates function" -Level "Notice"
            Log-Params -Params $PSCmdlet.MyInvocation.BoundParameters
    
            # Validate parameters
            if (-not $KBArticles -and -not $CheckAllUpdates) {
                throw "Either KBArticles or CheckAllUpdates switch must be provided."
            }
        }
    
        Process {
            try {
                # Retrieve installed updates
                Write-EnhancedLog -Message "Retrieving installed updates." -Level "INFO"
                $InstalledUpdates = Get-WUList -IsInstalled
    
                # Retrieve all updates and filter pending ones
                Write-EnhancedLog -Message "Retrieving all updates (to check for pending)." -Level "INFO"
                $AllUpdates = Get-WUList
                $PendingUpdates = $AllUpdates | Where-Object { $_.IsInstalled -eq $false }

                # Wait-Debugger
    
                # Create efficient list for results
                $Results = [System.Collections.Generic.List[PSCustomObject]]::new()
    
                if ($KBArticles) {
                    # Check specific KB articles in both installed and pending updates
                    foreach ($KB in $KBArticles) {
                        $IsInstalled = $InstalledUpdates | Where-Object { $_.KB -eq $KB }
                        $IsPending = $PendingUpdates | Where-Object { $_.KB -eq $KB }
    
                        $Result = [PSCustomObject]@{
                            KB        = $KB
                            Installed = if ($IsInstalled) { $true } else { $false }
                            Pending   = if ($IsPending) { $true } else { $false }
                        }
                        $Results.Add($Result)
    
                        # Log the result
                        if ($IsInstalled) {
                            Write-EnhancedLog -Message "[Installed] KB: $($Result.KB)" -Level "INFO"
                        }
                        elseif ($IsPending) {
                            Write-EnhancedLog -Message "[Pending] KB: $($Result.KB)" -Level "WARNING"
                        }
                        else {
                            Write-EnhancedLog -Message "[Not Installed or Pending] KB: $($Result.KB)" -Level "ERROR"
                        }
                    }
                }
                elseif ($CheckAllUpdates.IsPresent) {
                    # Log all installed and pending updates
                    foreach ($Update in $InstalledUpdates) {
                        $Result = [PSCustomObject]@{
                            KB        = $Update.KB
                            Installed = $true
                            Pending   = $false
                        }
                        $Results.Add($Result)
    
                        Write-EnhancedLog -Message "[Installed] KB: $($Update.KB), Title: $($Update.Title)" -Level "INFO"
                    }
    
                    foreach ($Update in $PendingUpdates) {
                        $Result = [PSCustomObject]@{
                            KB        = $Update.KB
                            Installed = $false
                            Pending   = $true
                        }
                        $Results.Add($Result)
    
                        Write-EnhancedLog -Message "[Pending] KB: $($Update.KB), Title: $($Update.Title)" -Level "WARNING"
                    }
                }
            }
            catch {
                Write-EnhancedLog -Message "Error checking for updates: $($_.Exception.Message)" -Level "ERROR"
                Handle-Error -ErrorRecord $_
                throw
            }
            finally {
                Write-EnhancedLog -Message "Exiting Check-WindowsUpdates function" -Level "Notice"
            }
        }
    
        End {
            try {
                Write-EnhancedLog -Message "Checking for reboot requirements." -Level "INFO"
                $RebootStatus = Get-WURebootStatus
                $RebootRequired = $RebootStatus.RebootRequired
    
                # Log reboot status
                if ($RebootRequired -eq $true) {
                    Write-EnhancedLog -Message "A reboot is required." -Level "CRITICAL"
                }
                else {
                    Write-EnhancedLog -Message "No reboot required." -Level "INFO"
                }
            }
            catch {
                Write-EnhancedLog -Message "Error checking reboot status: $($_.Exception.Message)" -Level "ERROR"
                Handle-Error -ErrorRecord $_
                throw
            }
            finally {
                Write-EnhancedLog -Message "Windows Update check completed." -Level "Notice"
            }
        }
    }
    
    # Example usage
    # $params = @{
    #     KBArticles     = @('KB1234567', 'KB2345678')
    # }
    # Check-WindowsUpdates @params
    
    # To check all installed and pending updates:
    Check-WindowsUpdates -CheckAllUpdates
    
    
    
    

    # Wait-Debugger
    

 
    #endregion
}
catch {
    Write-EnhancedLog -Message "An error occurred during script execution: $_" -Level 'ERROR'
    if ($transcriptPath) {
        Stop-Transcript
        Write-EnhancedLog -Message "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -ForegroundColor Red
    }

    # Stop PSF Logging

    # Ensure the log is written before proceeding
    Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

    Handle-Error -ErrorRecord $_
    throw $_  # Re-throw the error after logging it
} 
finally {
    # Ensure that the transcript is stopped even if an error occurs
    if ($transcriptPath) {
        Stop-Transcript
        Write-EnhancedLog -Message "Transcript stopped." -ForegroundColor Cyan
        # Stop logging in the finally block

    }
    else {
        Write-EnhancedLog -Message "Transcript was not started due to an earlier error." -ForegroundColor Red
    }
    # 

    
    # Ensure the log is written before proceeding
    Wait-PSFMessage

    # Stop logging in the finally block by disabling the provider
    Set-PSFLoggingProvider -Name 'logfile' -InstanceName $instanceName -Enabled $false

}