# Event Tracing for Windows (ETW) Providers: Some providers, known as Event Tracing for Windows (ETW) providers, can generate events that are not viewable in the Event Viewer GUI but can be accessed programmatically. If 'Microsoft-Windows-WindowsUpdateClient' is an ETW provider, this could explain the discrepancy.


Get-WinEvent -ListProvider * -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*policy*' } | Select-Object Name

# Specify the name (could be a LogName or ProviderName)
$name = "Security"

# Check if it's a LogName
$logExists = $null -ne (Get-WinEvent -ListLog $name -ErrorAction SilentlyContinue)

# Check if it's a ProviderName
$providerExists = $null -ne (Get-WinEvent -ListProvider $name -ErrorAction SilentlyContinue)

# If neither exists, exit with an error message
if (-not $logExists -and -not $providerExists) {
    Write-Host "The specified name doesn't match a Log or a Provider." -ForegroundColor Red
    exit
}

# Initialize the last event time to 24 hours ago for a more practical start point
$lastEventTime = (Get-Date).AddHours(-24)
$initialReadDone = $false

while($true) {
    # Fetch events based on whether the name is a LogName or ProviderName
    if ($logExists) {
        $events = Get-WinEvent -FilterHashtable @{LogName=$name; StartTime=$lastEventTime} -ErrorAction SilentlyContinue
    } elseif ($providerExists) {
        $events = Get-WinEvent -FilterHashtable @{ProviderName=$name; StartTime=$lastEventTime} -ErrorAction SilentlyContinue
    }

    if($null -ne $events) {
        # Filter and format the events
        foreach($event in $events) {
            $message = $event.Message
            $timeCreated = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm")

            # Update the last event time
            if($event.TimeCreated -gt $lastEventTime) {
                $lastEventTime = $event.TimeCreated
            }

            # Prepare the output string
            $output = "Time Created: $timeCreated, Message: $message"

            if($message -match 'error' -or $message -match 'fail' -or $message -match 'failure') {
                # Highlight this event
                Write-Host $output -ForegroundColor Red
            } elseif($message -match 'warning') {
                # Highlight warnings
                Write-Host $output -ForegroundColor Yellow
            } elseif($message -match 'success') {
                # Highlight successful operations
                Write-Host $output -ForegroundColor Green
            } else {
                # Print this event normally
                Write-Host $output
            }

            # Write to a log file
            $output | Out-File -Append -FilePath "C:\Code\monitor.log"
        }

        # Add 1 second to the last event time to avoid duplicate entries
        $lastEventTime = $lastEventTime.AddSeconds(1)
    } elseif (-not $initialReadDone) {
        # No more initial events found, announce listening for new events
        Write-Host "Listening to new events..." -ForegroundColor Cyan
        $outputStart = "Listening to new events at: " + (Get-Date).ToString("yyyy-MM-dd HH:mm")
        $outputStart | Out-File -Append -FilePath "C:\Code\monitor.log"

        # Mark that the initial reading is done
        $initialReadDone = $true
    }

    # Wait for 5 seconds
    Start-Sleep -Seconds 5
}
