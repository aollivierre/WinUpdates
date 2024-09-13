# List of provider names for Windows Logs and other specified logs
$providerNames = @('Application', 'Security', 'Setup', 'System', 'Microsoft-Windows-WindowsUpdateClient/Operational', 'Microsoft-Windows-Bits-Client/Operational')

foreach ($providerName in $providerNames) {
    # Get the events from the current provider
    $events = Get-WinEvent -LogName $providerName -ErrorAction SilentlyContinue
    
    # Reverse the order of the events
    [System.Array]::Reverse($events)

    # Filter and format the events
    foreach ($event in $events) {
        $message = $event.Message
        $timeCreated = $event.TimeCreated

        # Prepare the output string
        $output = "Log: $providerName, Time Created: $timeCreated, Message: $message"

        if ($message -match 'error' -or $message -match 'fail' -or $message -match 'failure') {
            # Highlight this event
            Write-Host $output -ForegroundColor Red
        } else {
            # Print this event normally
            Write-Host $output
        }
    }
}
