# Function to monitor a single provider
function Monitor-Provider {
    param ($providerName)

    $lastEventTime = [datetime]::MinValue
    $initialReadDone = $false

    while($true) {
        $events = Get-WinEvent -FilterHashtable @{ProviderName=$providerName; StartTime=$lastEventTime} -ErrorAction SilentlyContinue

        if ($null -ne $events) {
            # Reverse the order of the events
            [System.Array]::Reverse($events)

            foreach ($event in $events) {
                $message = $event.Message
                $timeCreated = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm")

                if ($event.TimeCreated -gt $lastEventTime) {
                    $lastEventTime = $event.TimeCreated
                }

                $output = "Provider: $providerName, Time Created: $timeCreated, Message: $message"
                $output | Out-File -Append -FilePath "C:\Code\bitlocker.log"

                # Return results to the main thread
                $output
            }

            $lastEventTime = $lastEventTime.AddSeconds(1)
        } elseif (-not $initialReadDone) {
            $outputStart = "Listening to new events for provider: $providerName"
            $outputStart | Out-File -Append -FilePath "C:\Code\bitlocker.log"
            $outputStart
            $initialReadDone = $true
        }

        Start-Sleep -Seconds 5
    }
}

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

# Start a job for each provider
$jobs = @()
foreach ($providerName in $providerNames) {
    Write-Host "Monitoring events for provider: $providerName" -ForegroundColor Cyan
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

    Start-Sleep -Seconds 5
}
