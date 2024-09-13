#############################################################################################################
#
#   Tool:           Intune Win32 Deployer
#   Author:         Abdullah Ollivierre
#   Website:        https://github.com/aollivierre
#   Twitter:        https://x.com/ollivierre
#   LinkedIn:       https://www.linkedin.com/in/aollivierre
#
#   Description:    https://github.com/aollivierre
#
#############################################################################################################

<#
    .SYNOPSIS
    Packages any custom app for MEM (Intune) deployment.
    Uploads the packaged into the target Intune tenant.

    .NOTES
    For details on IntuneWin32App go here: https://github.com/aollivierre

#>


# Set environment variable globally for all users
[System.Environment]::SetEnvironmentVariable('EnvironmentMode', 'dev', 'Machine')

# Retrieve the environment mode (default to 'prod' if not set)
$mode = $env:EnvironmentMode

# Toggle based on the environment mode
switch ($mode) {
    'dev' {
        Write-Host "Running in development mode" -ForegroundColor Yellow
        # Your development logic here
    }
    'prod' {
        Write-Host "Running in production mode" -ForegroundColor Green
        # Your production logic here
    }
    default {
        Write-Host "Unknown mode. Defaulting to production." -ForegroundColor Red
        # Default to production
    }
}

$mode = $env:EnvironmentMode

#region FIRING UP MODULE STARTER
#################################################################################################
#                                                                                               #
#                                 FIRING UP MODULE STARTER                                      #
#                                                                                               #
#################################################################################################

# Define a hashtable for splatting
$moduleStarterParams = @{
    Mode                   = 'dev'
    SkipPSGalleryModules   = $true
    SkipCheckandElevate    = $true
    SkipPowerShell7Install = $true
    SkipEnhancedModules    = $true
    SkipGitRepos           = $true
}

# Call the function using the splat
Invoke-ModuleStarter @moduleStarterParams

#endregion FIRING UP MODULE STARTER


#################################################################################################################################
################################################# START VARIABLES ###############################################################
#################################################################################################################################

#First, load secrets and create a credential object:
# Assuming secrets.json is in the same directory as your script
$secretsPath = Join-Path -Path $PSScriptRoot -ChildPath "secrets.json"

# Load the secrets from the JSON file
$secrets = Get-Content -Path $secretsPath -Raw | ConvertFrom-Json

# Read configuration from the JSON file
# Assign values from JSON to variables

# Read configuration from the JSON file
$configPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
$env:MYMODULE_CONFIG_PATH = $configPath

$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

#  Variables from JSON file
$tenantId = $secrets.tenantId
$clientId = $secrets.clientId

$certPath = Join-Path -Path $PSScriptRoot -ChildPath 'graphcert.pfx'
$CertPassword = $secrets.CertPassword
$siteObjectId = $secrets.SiteObjectId
$documentDriveName = $secrets.DocumentDriveName

#################################################################################################################################
################################################# END VARIABLES #################################################################
#################################################################################################################################

##########################################################################################################################
############################################STARTING THE MAIN FUNCTION LOGIC HERE#########################################
##########################################################################################################################


################################################################################################################################
################################################ START GRAPH CONNECTING ########################################################
################################################################################################################################
$accessToken = Connect-GraphWithCert -tenantId $tenantId -clientId $clientId -certPath $certPath -certPassword $certPassword

Log-Params -Params @{accessToken = $accessToken }

Get-TenantDetails
#################################################################################################################################
################################################# END Connecting to Graph #######################################################
#################################################################################################################################

#################################################################################################################################
################################################# START VPN Export #############################################################
#################################################################################################################################
# Ensure the VPNExport folder exists
# $ExportsFolderPath = Ensure-ExportsFolder -BasePath $PSScriptRoot

$exportsFolderName = "CustomExports"
$exportSubFolderName = "CustomWindowsUpdateLogs"

$ExportsFolderPath = Ensure-ExportsFolder -BasePath $PSScriptRoot -ExportsFolderName $ExportsFolderName -ExportSubFolderName $ExportSubFolderName

Write-EnhancedLog -Message "Exports folder path: $ExportsFolderPath" -Level "INFO"

# Log parameters
Log-Params @{
    BasePath          = $PSScriptRoot
    ExportsFolderPath = $ExportsFolderPath
}

# Call the function to export VPN connections
Export-VPNConnectionsToXML -ExportFolder $ExportsFolderPath
#################################################################################################################################
################################################# END VPN Export ###############################################################
#################################################################################################################################


try {
    # Get an access token for the Microsoft Graph API
    # Set up headers for API requests
    $headers = @{
        "Authorization" = "Bearer $($accessToken)"
        "Content-Type"  = "application/json"
    }

    # Get the ID of the SharePoint document drive
    $documentDriveId = Get-SharePointDocumentDriveId -SiteObjectId $siteObjectId -DocumentDriveName $documentDriveName -Headers $headers

    Log-Params -Params @{document_drive_id = $documentDriveId }

    # Get the computer name and detailed info
    $computerName = $env:COMPUTERNAME
    $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem | Format-List | Out-String
    $allScanResults = @()

    $detectedFolderPath = "WindowsUpdateLogs"

    # Generate a report file containing the paths of the files found
    Write-EnhancedLog -Message "Generating report..."
    $reportFileName = "ExportVPN_${computerName}_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $reportFilePath = Join-Path -Path $env:TEMP -ChildPath $reportFileName
    # $CSVFilePath = "$scriptPath\exports\CSV\$Filename.csv"

    # Add computer info and scan results to the report file
    $computerInfo | Set-Content -Path $reportFilePath
    $allScanResults | Add-Content -Path $reportFilePath

    # Create the "Infected" folder in SharePoint if it doesn't exist
    New-SharePointFolder -DocumentDriveId $documentDriveId -ParentFolderPath $detectedFolderPath -FolderName $computerName -Headers $headers

    $detectedtargetFolderPath = "$detectedFolderPath/$computerName"
    Upload-FileToSharePoint -DocumentDriveId $documentDriveId -FilePath $reportFilePath -FolderName $detectedtargetFolderPath -Headers $headers
    # Upload-FileToSharePoint -DocumentDriveId $documentDriveId -FilePath $CSVFilePath -FolderName $detectedtargetFolderPath -Headers $headers

}
catch {
    Write-EnhancedLog -Message "An error occurred: $_" -Level "ERROR"
}

# Stop-Transcript

# Create a folder in SharePoint named after the computer
$computerName = $env:COMPUTERNAME
$parentFolderPath = "VPN"  # Change this to the desired parent folder path in SharePoint
New-SharePointFolder -DocumentDriveId $documentDriveId -ParentFolderPath $parentFolderPath -FolderName $computerName -Headers $headers

# Upload the transcript log to the new SharePoint folder
$targetFolderPath = "$parentFolderPath/$computerName"
# $LocalFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "Exports"
$LocalFolderPath = $ExportsFolderPath


# Get all files in the folder
$FilesToUpload = Get-ChildItem -Path $LocalFolderPath -File -Recurse

foreach ($File in $FilesToUpload) {
    Upload-FileToSharePoint -DocumentDriveId $documentDriveId -FilePath $File.FullName -FolderName $targetFolderPath -Headers $headers
}