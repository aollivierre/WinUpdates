
# write a powershell script to use PSWindowsUpdate module to check if the following KBs
# export to csv - create the folder for the CSV export dynamically if it does not exist with time stamp before exporting
# based on an input CSV search for all the KB article write to console time stamped and color coded and filter for the following
# Input CSV = C:\Code\GitHub\WinUpdates\Imports\Security Updates 2023-03-27-104343am.csv
# start transcript and stope transcript create the folder for the log export dynamically if it does not exist with time stamp before exporting



# Define input CSV file and output folder
$InputCSV = "C:\Code\WinUpdates\Imports\Security Updates 2023-03-27-104343am.csv"
$OutputFolder = "C:\Code\WinUpdates\Exports\$(Get-Date -Format 'yyyy-MM-dd-HHmmss')"

# Create output folder if it does not exist
if (!(Test-Path -Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

# Start transcript
$TranscriptLogFile = Join-Path -Path $OutputFolder -ChildPath "TranscriptLog_$(Get-Date -Format 'yyyy-MM-dd-HHmmss').txt"
Start-Transcript -Path $TranscriptLogFile

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
        KB = $KB.KB
        Title = $KB.Title
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
$CSVExportPath = Join-Path -Path $OutputFolder -ChildPath "Results_$(Get-Date -Format 'yyyy-MM-dd-HHmmss').csv"
$Results | Export-Csv -Path $CSVExportPath -NoTypeInformation



# Display the exported CSV file path and transcript log file path
Write-Host "CSV Exported to: $CSVExportPath" -ForegroundColor Cyan
Write-Host "Transcript Log saved at: $TranscriptLogFile" -ForegroundColor Cyan




# Install missing updates
$MissingUpdates = $Results | Where-Object { !$_.Installed }
if ($MissingUpdates) {
    Write-Host "Installing missing updates..." -ForegroundColor Yellow
    foreach ($Update in $MissingUpdates) {
        Write-Host "Installing $($Update.KB) - $($Update.Title)" -ForegroundColor Yellow
        Install-WindowsUpdate -KBArticleID $Update.KB -AcceptAll -Verbose
    }
    Write-Host "Missing updates installation completed." -ForegroundColor Green
} else {
    Write-Host "No missing updates found." -ForegroundColor Green
}

# Stop transcript
Stop-Transcript