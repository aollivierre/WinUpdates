@{
    # General Configuration
    PackageName             = 'PR4B - Install Pending Windows Updates'
    PackageUniqueGUID       = 'f19844c1-d77a-4d59-883f-8fec027a3458'
    Version                 = '1.0'
    ScriptMode              = 'Remediation'                  # "Remediation" or "PackageName", depending on your use case
    PackageExecutionContext = 'SYSTEM'                         # Execution context, e.g., "USER" or "SYSTEM"
    RepetitionInterval      = 'PT15M'                        # Interval for repeating the task (e.g., every 15 minutes)
    DataFolder              = 'Data'                         # Folder name for data storage

    # Paths Configuration
    PathLocalSystem         = "C:\Program Files\_MEM"  # C:\_MEM
    PathLocalUser           = 'C:\Program Files\_MEM'  # or uncomment "$ENV:LOCALAPPDATA\_MEM" in CreateAndExecuteScheduledTask.ps1
    TaskNameFormat          = "{0} - {1}"                    # Format for task name
    TaskDescriptionFormat   = "PR4B - Install Pending Windows Updates {0}"                  # Format for task description
    ScriptPaths             = @{
        Remediation = 'remediation.ps1'              # Path for remediation script
        PackageName = 'PR4B_InstallPendingWindowsupdates.ps1' # Path for package script, using the package name
    }

    # Task Action Configuration
    UsePSADT                = $false                          # Whether to use PowerShell Application Deployment Toolkit
    ToolkitExecutablePath   = 'Deploy-Application.exe'
    ServiceUIExecutablePath = 'ServiceUI.exe'
    DeploymentType          = 'install'
    ProcessName             = 'explorer.exe'
    WscriptPath             = 'C:\Windows\System32\wscript.exe'

    # Task Trigger Configuration
    StartTimeOffsetMinutes  = 1                              # Start time offset for scheduled task
    TriggerType             = 'Logon'                        # "Daily", "Logon", or "AtStartup"
    LogonUserId             = 'administrator'                # Specify user ID for logon, if required
    # StartBoundary           = "2024-08-16T12:00:00"  # Example start boundary time (optional)
    Delay                   = "PT1M"                 # Example delay (optional, in ISO 8601 duration format)

    # Task Principal Configuration
    PrincipalUserId         = 'NT AUTHORITY\SYSTEM'          # User ID for task principal
    LogonType               = 'ServiceAccount'               # Logon type for task principal
    RunLevel                = 'Highest'                      # Run level for task principal

    # Task Registration Configuration
    RunOnDemand             = $false                         # Whether to run the task on demand
    Repeat                  = $false                          # Whether to repeat the task
    TaskExecutionContext    = 'User'                         # Execution context for the task
    TaskFolderPath          = "Intune-PR4B"                            # Folder path for the task default is "\"
    TaskUserGroup           = 'Users'                        # User group for the task registration
    TaskRegistrationFlags   = 6                              # Flags for task registration
    TaskLogonType           = 4                              # Logon type for task registration

    # ScheduleOnly Option
    ScheduleOnly            = $true                          # Whether to only schedule the task without immediate execution
}