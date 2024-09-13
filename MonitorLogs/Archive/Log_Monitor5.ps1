$logNames = @('Microsoft-Windows-WindowsUpdateClient/Operational')
# ... extend the list as needed ...

$action = {
    $event_1 = $eventArgs.EventRecord
    $logName = $event_1.LogName
    $message = $event_1.Message
    $timeCreated = $event_1.TimeCreated

    # Prepare the output string
    $output = "Log: $logName, Time Created: $timeCreated, Message: $message"

    if ($message -match 'error' -or $message -match 'fail' -or $message -match 'failure') {
        # Highlight this event
        Write-Host $output -ForegroundColor Red
    } else {
        # Print this event normally
        Write-Host $output
    }
}

$subscribers = @()

# Create event subscribers for each log
foreach ($logName in $logNames) {
    $subscribers += Register-WmiEvent -Query "SELECT * FROM __InstanceCreationEvent WITHIN 5 WHERE TargetInstance ISA 'Win32_NTLogEvent' AND TargetInstance.LogFile='$logName'" -Action $action
}

Write-Host "Real-time log monitoring started. Press Ctrl+C to exit." -ForegroundColor Cyan
try {
    Wait-Event
} finally {
    $subscribers | ForEach-Object { Unregister-Event -SubscriptionId $_.SubscriptionId }
    Write-Host "Real-time log monitoring stopped." -ForegroundColor Green
}