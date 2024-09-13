# Specify the provider name
$providerName = 'Microsoft-Windows-WindowsUpdateClient'

# Initialize the last event time
$lastEventTime = [datetime]::MinValue

while($true) {
    # Get the events from the specified provider
    $events = Get-WinEvent -FilterHashtable @{ProviderName=$providerName; StartTime=$lastEventTime} -ErrorAction SilentlyContinue

    if($null -ne $events) {
        # Reverse the order of the events
        [System.Array]::Reverse($events)

        # Filter and format the events
        foreach($event in $events) {
            $message = $event.Message
            $timeCreated = $event.TimeCreated

            # Update the last event time
            if($timeCreated -gt $lastEventTime) {
                $lastEventTime = $timeCreated
            }

            # Prepare the output string
            $output = "Time Created: $timeCreated, Message: $message"

            if($message -match 'error' -or $message -match 'fail' -or $message -match 'failure') {
                # Highlight this event
                Write-Host $output -ForegroundColor Red
            } else {
                # Print this event normally
                Write-Host $output
            }

            # Write to a log file
            $output | Out-File -Append -FilePath "C:\Code\CB\WinUpdates\CNA\wu.log"
        }

        # Add 1 second to the last event time to avoid duplicate entries
        $lastEventTime = $lastEventTime.AddSeconds(1)
    }

    # Wait for 5 seconds
    Start-Sleep -Seconds 5
}
