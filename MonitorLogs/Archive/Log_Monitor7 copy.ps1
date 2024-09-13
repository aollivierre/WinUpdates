# Event Tracing for Windows (ETW) Providers: Some providers, known as Event Tracing for Windows (ETW) providers, can generate events that are not viewable in the Event Viewer GUI but can be accessed programmatically. If 'Microsoft-Windows-WindowsUpdateClient' is an ETW provider, this could explain the discrepancy.


# Get a list of all provider names that contain 'BitLocker' in their name
$providerNames = Get-WinEvent -ListProvider * -ErrorAction SilentlyContinue | 
                 Where-Object { $_.Name -like '*BitLocker*' } | 
                 Select-Object -ExpandProperty Name

# If no providers found, exit
if (-not $providerNames) {
    Write-Host "No providers found with 'BitLocker' in their name." -ForegroundColor Red
    return
}

# List all provider names found
Write-Host "Providers found with 'BitLocker' in their name:" -ForegroundColor Green
$providerNames | ForEach-Object { Write-Host $_ }

# Display the total number of providers found
$totalProviders = $providerNames.Count
Write-Host "`nTotal number of providers found: $totalProviders`n" -ForegroundColor Green

# Loop through each provider name
foreach ($providerName in $providerNames) {
    Write-Host "Monitoring events for provider: $providerName" -ForegroundColor Cyan

    # Initialize the last event time
    $lastEventTime = [datetime]::MinValue
    $initialReadDone = $false

    while($true) {
        # Get the events from the current provider
        $events = Get-WinEvent -FilterHashtable @{ProviderName=$providerName; StartTime=$lastEventTime} -ErrorAction SilentlyContinue

        if($null -ne $events) {
            # Reverse the order of the events
            [System.Array]::Reverse($events)

            # Filter and format the events
            foreach($event in $events) {
                $message = $event.Message
                $timeCreated = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm")

                # Update the last event time
                if($event.TimeCreated -gt $lastEventTime) {
                    $lastEventTime = $event.TimeCreated
                }

                # Prepare the output string
                $output = "Provider: $providerName, Time Created: $timeCreated, Message: $message"

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
                $output | Out-File -Append -FilePath "C:\Code\bitlocker.log"
            }

            # Add 1 second to the last event time to avoid duplicate entries
            $lastEventTime = $lastEventTime.AddSeconds(1)
        } elseif (-not $initialReadDone) {
            # No more initial events found, announce listening for new events
            Write-Host "Listening to new events for provider: $providerName" -ForegroundColor Cyan
            $outputStart = "Listening to new events for provider $providerName at: " + (Get-Date).ToString("yyyy-MM-dd HH:mm")
            $outputStart | Out-File -Append -FilePath "C:\Code\bitlocker.log"

            # Mark that the initial reading is done
            $initialReadDone = $true
        }

        # Wait for 5 seconds
        Start-Sleep -Seconds 5
    }
}
