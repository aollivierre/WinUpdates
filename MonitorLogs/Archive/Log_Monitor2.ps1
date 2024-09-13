# Specify the provider name
# $providerName = 'Microsoft-Windows-DNS-Server-Service'
# $providerName = @('Microsoft-Windows-WindowsUpdateClient/Operational')
# $providerName = 'Microsoft-Windows-WindowsUpdateClient/Operational'
$providerName = 'Microsoft-Windows-WindowsUpdateClient'


# Get the events from the specified provider
$events = Get-WinEvent -ProviderName $providerName

# Reverse the order of the events
[System.Array]::Reverse($events)

# Filter and format the events
foreach($event in $events) {
    $message = $event.Message
    $timeCreated = $event.TimeCreated

    # Prepare the output string
    $output = "Time Created: $timeCreated, Message: $message"

    if($message -match 'error' -or $message -match 'fail' -or $message -match 'failure') {
        # Highlight this event
        Write-Host $output -ForegroundColor Red
    } else {
        # Print this event normally
        Write-Host $output
    }
}
