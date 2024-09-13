# List of log names for Windows Logs and other specified logs
$logNames = @('Microsoft-Windows-WindowsUpdateClient/Operational')
# You can extend the list as needed: @('Application', 'Security', 'Setup', 'System', 'Microsoft-Windows-WindowsUpdateClient/Operational', 'Microsoft-Windows-Bits-Client/Operational')

Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Write-Host "Exiting real-time log monitoring..." -ForegroundColor Green
    $global:exitLoop = $true
}

$exitLoop = $false
while (-not $exitLoop) {
    foreach ($logName in $logNames) {
        try {
            Get-WinEvent -FilterHashtable @{LogName=$logName} -MaxEvents 1 -Wait | ForEach-Object {
                $event = $_
                $message = $event.Message
                $timeCreated = $event.TimeCreated

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
        } catch {
            # Handle any errors silently and continue
        }
    }
}

