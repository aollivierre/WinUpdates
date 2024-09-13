# # # Example usage
# # $privateFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "private"
# # $PsExec64Path = Join-Path -Path $privateFolderPath -ChildPath "PsExec64.exe"
# # $ScriptToRunAsSystem = $MyInvocation.MyCommand.Path

# # Ensure-RunningAsSystem -PsExec64Path $PsExec64Path -ScriptPath $ScriptToRunAsSystem -TargetFolder $privateFolderPath


# # Create a time-stamped folder in the temp directory
# $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
# $tempFolder = [System.IO.Path]::Combine($env:TEMP, "Ensure-RunningAsSystem_$timestamp")

# # Ensure the temp folder exists
# if (-not (Test-Path -Path $tempFolder)) {
#     New-Item -Path $tempFolder -ItemType Directory | Out-Null
# }

# # Use the time-stamped temp folder for your paths
# $privateFolderPath = Join-Path -Path $tempFolder -ChildPath "private"
# $PsExec64Path = Join-Path -Path $privateFolderPath -ChildPath "PsExec64.exe"

# # If running as a web script, we won't have $MyInvocation.MyCommand.Path, so fallback to manual definition first download the script to a local machine and then execute it.
# if (-not $MyInvocation.MyCommand.Path) {

#     Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aollivierre/WinUpdates/main/PR4B_TriggerWindowsUpdates-v4/install.ps1" -OutFile "$env:TEMP\install.ps1"
#     & "$env:TEMP\install.ps1"

# }
# else {
#     # If running in a regular context, use the actual path
#     $ScriptToRunAsSystem = $MyInvocation.MyCommand.Path
# }

# # Ensure the folder exists before continuing
# if (-not (Test-Path -Path $privateFolderPath)) {
#     New-Item -Path $privateFolderPath -ItemType Directory | Out-Null
# }

# # Call the function using the new paths
# $EnsureRunningAsSystemParams = @{
#     PsExec64Path = $PsExec64Path
#     ScriptPath   = $ScriptToRunAsSystem
#     TargetFolder = $privateFolderPath
# }
    
# Ensure-RunningAsSystem @EnsureRunningAsSystemParams




# Create a time-stamped folder in the temp directory
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$tempFolder = [System.IO.Path]::Combine($env:TEMP, "Ensure-RunningAsSystem_$timestamp")

# Ensure the temp folder exists
if (-not (Test-Path -Path $tempFolder)) {
    New-Item -Path $tempFolder -ItemType Directory | Out-Null
}

# Use the time-stamped temp folder for your paths
$privateFolderPath = Join-Path -Path $tempFolder -ChildPath "private"
$PsExec64Path = Join-Path -Path $privateFolderPath -ChildPath "PsExec64.exe"

# Check if running as a web script (no $MyInvocation.MyCommand.Path)
if (-not $MyInvocation.MyCommand.Path) {
    Write-Host "Running as web script, downloading and executing locally..."

    # Download the script to a local machine
    $localScriptPath = Join-Path -Path $env:TEMP -ChildPath "install.ps1"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aollivierre/WinUpdates/main/PR4B_TriggerWindowsUpdates-v4/install.ps1" -OutFile $localScriptPath

    # Execute the script locally
    & $localScriptPath

    Exit # Exit after running the script locally
}
else {
    # If running in a regular context, use the actual path of the script
    $ScriptToRunAsSystem = $MyInvocation.MyCommand.Path
}

# Ensure the private folder exists before continuing
if (-not (Test-Path -Path $privateFolderPath)) {
    New-Item -Path $privateFolderPath -ItemType Directory | Out-Null
}

# Call the function to run as SYSTEM
$EnsureRunningAsSystemParams = @{
    PsExec64Path = $PsExec64Path
    ScriptPath   = $ScriptToRunAsSystem
    TargetFolder = $privateFolderPath
}

# If not running as a web script, run as SYSTEM using PsExec
Write-Host "Running as SYSTEM..."
Ensure-RunningAsSystem @EnsureRunningAsSystemParams





# Wait-Debugger




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
    SkipGitRepos           = $true
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
$JobName = "WindowsUpdates"
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


    #################################################################################################################################
    ################################################# START VARIABLES ###############################################################
    #################################################################################################################################

    # Read configuration from the JSON file
    # Assign values from JSON to variables

    # Read configuration from the JSON file
    # $configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
    # $env:MYMODULE_CONFIG_PATH = $configPath

    # $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

    # Read configuration from the JSON file
    # $configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
    # $env:MYMODULE_CONFIG_PATH = $configPath

    # $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

    # Assign values from JSON to variables
    # $PackageName = $config.PackageName
    # $PackageUniqueGUID = $config.PackageUniqueGUID
    # $Version = $config.Version
    # $PackageExecutionContext = $config.PackageExecutionContext
    # $RepetitionInterval = $config.RepetitionInterval
    # $ScriptMode = $config.ScriptMode

    #################################################################################################################################
    ################################################# END VARIABLES #################################################################
    #################################################################################################################################


    # ################################################################################################################################
    # ############### CALLING AS SYSTEM to simulate Intune deployment as SYSTEM (Uncomment for debugging) ############################
    # ################################################################################################################################

    # Example usage
    # $privateFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "private"
    # $PsExec64Path = Join-Path -Path $privateFolderPath -ChildPath "PsExec64.exe"
    # $ScriptToRunAsSystem = $MyInvocation.MyCommand.Path

    # Ensure-RunningAsSystem -PsExec64Path $PsExec64Path -ScriptPath $ScriptToRunAsSystem -TargetFolder $privateFolderPath


    # Create a time-stamped folder in the temp directory
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $tempFolder = [System.IO.Path]::Combine($env:TEMP, "Ensure-RunningAsSystem_$timestamp")

    # Ensure the temp folder exists
    if (-not (Test-Path -Path $tempFolder)) {
        New-Item -Path $tempFolder -ItemType Directory | Out-Null
    }

    # Use the time-stamped temp folder for your paths
    $privateFolderPath = Join-Path -Path $tempFolder -ChildPath "private"
    $PsExec64Path = Join-Path -Path $privateFolderPath -ChildPath "PsExec64.exe"

    # Check if running as a web script (no $MyInvocation.MyCommand.Path)
    if (-not $MyInvocation.MyCommand.Path) {
        Write-Host "Running as web script, downloading and executing locally..."

        # Download the script to a local machine
        $localScriptPath = Join-Path -Path $env:TEMP -ChildPath "install.ps1"
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/aollivierre/WinUpdates/main/PR4B_TriggerWindowsUpdates-v4/install.ps1" -OutFile $localScriptPath

        # Execute the script locally
        & $localScriptPath

        Exit # Exit after running the script locally
    }
    else {
        # If running in a regular context, use the actual path of the script
        $ScriptToRunAsSystem = $MyInvocation.MyCommand.Path
    }

    # Ensure the private folder exists before continuing
    if (-not (Test-Path -Path $privateFolderPath)) {
        New-Item -Path $privateFolderPath -ItemType Directory | Out-Null
    }

    # Call the function to run as SYSTEM
    $EnsureRunningAsSystemParams = @{
        PsExec64Path = $PsExec64Path
        ScriptPath   = $ScriptToRunAsSystem
        TargetFolder = $privateFolderPath
    }

    # If not running as a web script, run as SYSTEM using PsExec
    Write-Host "Running as SYSTEM..."
    Ensure-RunningAsSystem @EnsureRunningAsSystemParams


    # Wait-Debugger


    # ################################################################################################################################
    # ################################################ END CALLING AS SYSTEM (Uncomment for debugging) ###############################
    # ################################################################################################################################
    
    
    #################################################################################################################################
    ################################################# END LOGGING ###################################################################
    #################################################################################################################################



    ###########################################################################################################################
    #############################################STARTING THE MAIN SCHEDULED TASK LOGIC HERE###################################
    ###########################################################################################################################



    # # Define the parameters using a hashtable
    $taskParams = @{
        ConfigPath = "$PSScriptroot\config.psd1"
        FileName   = "HiddenScript.vbs"
        Scriptroot = "$PSScriptroot"
    }

    # Call the function with the splatted parameters
    CreateAndRegisterScheduledTask @taskParams
    


    # Wait-Debugger
    

 
    #endregion Script Logic
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