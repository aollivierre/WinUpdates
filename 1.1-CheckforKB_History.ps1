# Set input CSV file path
$InputCSV = "C:\Code\WinUpdates\Imports\Security Updates 2023-03-27-104343am.csv"

# Set output CSV file path
$TimeStamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$OutputFolderPath = "C:\Code\WinUpdates\Exports\$TimeStamp"
$OutputCSV = "$OutputFolderPath\CheckedUpdates.csv"

# Set transcript log path
$TranscriptFolderPath = "C:\Code\WinUpdates\Exports\$TimeStamp\Logs"
$TranscriptLog = "$TranscriptFolderPath\UpdateCheckLog.txt"

# Create folders if they don't exist
if (!(Test-Path $OutputFolderPath)) { New-Item -ItemType Directory -Path $OutputFolderPath }
if (!(Test-Path $TranscriptFolderPath)) { New-Item -ItemType Directory -Path $TranscriptFolderPath }

# Start transcript
Start-Transcript -Path $TranscriptLog

# Import PSWindowsUpdate module
if (!(Get-Module -Name PSWindowsUpdate)) { Install-Module -Name PSWindowsUpdate }


# Get update history within the last 30 days, limited to 100 entries
$UpdateHistory = Get-WUHistory -MaxDate (Get-Date).AddDays(-30) -Last 100


# Get update history
# $UpdateHistory = Get-WUHistory

# Read input CSV
$KBArticles = Import-Csv -Path $InputCSV

# Check for installed updates
$Results = @()
foreach ($KB in $KBArticles) {
    $IsInstalled = $UpdateHistory | Where-Object { $_.KB -eq $KB.Article }
    if ($IsInstalled) {
        $Results += [PSCustomObject]@{
            KB = $KB.Article
            Title = $IsInstalled.Title
            Installed = $true
            Status = $IsInstalled.Status
        }
        Write-Host "Installed: $($KB.Article) - $($IsInstalled.Title)" -ForegroundColor Green
    } else {
        $Results += [PSCustomObject]@{
            KB = $KB.Article
            Title = $KB.Title
            Installed = $false
            Status = 'Not found'
        }
        Write-Host "Not Installed: $($KB.Article) - $($KB.Title)" -ForegroundColor Red
    }
}

# Export results to CSV
$Results | Export-Csv -Path $OutputCSV -NoTypeInformation

# Stop transcript
Stop-Transcript

# Open output CSV in Notepad
# Start-Process -FilePath "notepad.exe" -ArgumentList $OutputCSV

