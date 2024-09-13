# write a powershell script to use PSWindowsUpdate module to check if the following KBs
# export to csv - create the folder for the CSV export dynamically if it does not exist with time stamp before exporting
# based on an input CSV search for all the KB article write to console time stamped and color coded and filter for the following
# Input CSV = C:\Code\GitHub\WinUpdates\Imports\Security Updates 2023-03-27-104343am.csv
# start transcript and stop transcript create the folder for the log export dynamically if it does not exist with time stamp before exporting



# Set input CSV file path
$InputCSV = "C:\Code\WinUpdates\Imports\Security Updates 2023-03-27-104343am.csv"

# Set output CSV file path
$TimeStamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$OutputFolderPath = "C:\Code\WinUpdates\Exports\$TimeStamp"
# $OutputCSV = "$OutputFolderPath\CheckedUpdates.csv"

# Set transcript log path
$TranscriptFolderPath = "C:\Code\WinUpdates\Exports\$TimeStamp\Logs"
$TranscriptLog = "$TranscriptFolderPath\UpdateCheckLog.txt"

# Create folders if they don't exist
if (!(Test-Path $OutputFolderPath)) { New-Item -ItemType Directory -Path $OutputFolderPath }
if (!(Test-Path $TranscriptFolderPath)) { New-Item -ItemType Directory -Path $TranscriptFolderPath }

# Start transcript
# Start-Transcript -Path $TranscriptLog

# Start transcript
# $TranscriptLogFile = Join-Path -Path $OutputFolder -ChildPath "TranscriptLog_$(Get-Date -Format 'yyyy-MM-dd-HHmmss').txt"
# Start-Transcript -Path $TranscriptLogFile

# Import PSWindowsUpdate module
Import-Module PSWindowsUpdate

# Load KB article numbers from the input CSV file
$KBArticles = Import-Csv -Path $InputCSV

# Get installed updates
# $InstalledUpdates = Get-WUList -IsInstalled -IsHidden
$InstalledUpdates = Get-WUList -IsInstalled

# Check if the KB articles are installed and output the results
$Results = @()
foreach ($KB in $KBArticles) {
    $IsInstalled = $InstalledUpdates | Where-Object { $_.KB -eq $KB.Article }
    $Result = [PSCustomObject]@{
        KB = $KB.Article
        Title = $KB.Product
        Installed = if ($IsInstalled) { $true } else { $false }
    }
    $Results += $Result
    
    # Output the result to the console with timestamp and color coding
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($IsInstalled) {
        Write-Host "$TimeStamp - [Installed] $($Result.KB) - $($Result.Title)" -ForegroundColor Green
    } else {
        Write-Host "$TimeStamp - [Not Installed] $($Result.KB) - $($Result.Title)" -ForegroundColor Red
    }
}

# Export results to a CSV file with a timestamp
$CSVExportPath = Join-Path -Path $OutputFolderPath -ChildPath "Results_$(Get-Date -Format 'yyyy-MM-dd-HHmmss').csv"
$Results | Export-Csv -Path $CSVExportPath -NoTypeInformation



# Now run the Get-WURebootStatus command to determine if any of the Windows updates require a reboot. 
# The command returns either True or False value to indicate the reboot status
Write-Host "$TimeStamp - Checking if a Reboot is required" -ForegroundColor Yellow
Get-WURebootStatus

# Stop transcript
# Stop-Transcript

# Display the exported CSV file path and transcript log file path
Write-Host "CSV Exported to: $CSVExportPath" -ForegroundColor Cyan
Write-Host "Transcript Log saved at: $TranscriptLogFile" -ForegroundColor Cyan

