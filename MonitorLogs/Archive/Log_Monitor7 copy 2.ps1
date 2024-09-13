# Function that contains the monitoring logic for a single provider
function Monitor-Provider {
    param ($providerName)

    $lastEventTime = [datetime]::MinValue
    $initialReadDone = $false

    while($true) {
        $events = Get-WinEvent -FilterHashtable @{ProviderName=$providerName; StartTime=$lastEventTime} -ErrorAction SilentlyContinue

        # ... [rest of the code to fetch events and display]

        # Return results to the main thread instead of Write-Host
        if ($output) {
            $output
        }

        # Wait for 5 seconds
        Start-Sleep -Seconds 5
    }
}

# Start a job for each provider
$jobs = @()
foreach ($providerName in $providerNames) {
    $jobs += Monitor-Provider -providerName $providerName -AsJob
}

# Monitor jobs for results
while ($true) {
    foreach ($job in $jobs) {
        $result = Receive-Job -Job $job -Keep
        if ($result) {
            Write-Host $result
        }
    }

    # Wait before checking again
    Start-Sleep -Seconds 5
}
