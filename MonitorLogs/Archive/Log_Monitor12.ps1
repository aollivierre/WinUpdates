# Check if the script is running with administrative privileges
function IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal] $identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

if (-not (IsAdmin)) {
    Write-Host "Script needs to be run as Administrator. Relaunching with admin privileges." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Prompt the user for the LogName or ProviderName
$name = Read-Host "Enter the value for LogName (e.g., 'Application' or specific provider name)"

# Determine if output should be written to the console
$consoleOutput = Read-Host "Do you want to write the logs to the console as well? (Y/N)"
$writeToConsole = $consoleOutput -eq 'Y' -or $consoleOutput -eq 'y'

if ($writeToConsole) {
    Write-Host "Logs will be displayed on the console." -ForegroundColor Green
} else {
    Write-Host "Logs will NOT be displayed on the console." -ForegroundColor Red
}

# Initialize file path
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = "C:\Code\monitor_$timestamp.log"

# Inform user about the log file location
Write-Host "Logs will be saved to $logPath" -ForegroundColor Cyan

# Check if it's a LogName or ProviderName
$logExists = $null -ne (Get-WinEvent -ListLog $name -ErrorAction SilentlyContinue)
$providerExists = $null -ne (Get-WinEvent -ListProvider $name -ErrorAction SilentlyContinue)

if (-not $logExists -and -not $providerExists) {
    Write-Host "The specified name doesn't match a Log or a Provider." -ForegroundColor Red
    exit
}

if ($logExists) {
    Write-Host "Operating in LogName mode." -ForegroundColor Cyan
} elseif ($providerExists) {
    Write-Host "Operating in ProviderName mode." -ForegroundColor Cyan
}

$lastEventTime = (Get-Date).AddHours(-24)
$initialReadDone = $false

while ($true) {
    if ($logExists) {
        $events = Get-WinEvent -FilterHashtable @{LogName=$name; StartTime=$lastEventTime} -ErrorAction SilentlyContinue
    } elseif ($providerExists) {
        $events = Get-WinEvent -FilterHashtable @{ProviderName=$name; StartTime=$lastEventTime} -ErrorAction SilentlyContinue
    }

    if ($events) {
        Write-Host "Found $($events.Count) new events..." -ForegroundColor Green
        foreach ($event in $events) {
            $message = $event.Message
            $timeCreated = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm")

            # Update the last event time
            if ($event.TimeCreated -gt $lastEventTime) {
                $lastEventTime = $event.TimeCreated
            }

            # Prepare the output string
            $output = "Time Created: $timeCreated, Message: $message"
            $output | Out-File -Append -FilePath $logPath

            if ($writeToConsole) {
                Write-Host $output
            }
        }

        $lastEventTime = $lastEventTime.AddSeconds(1)
    } elseif (-not $initialReadDone) {
        Write-Host "Completed initial read. Listening to new events... (This might take some time depending on event frequency)" -ForegroundColor Cyan
        "Listening to new events at $(Get-Date -Format "yyyy-MM-dd HH:mm")" | Out-File -Append -FilePath $logPath
        $initialReadDone = $true
    }

    Start-Sleep -Seconds 5
}
