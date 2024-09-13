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
                $output | Out-File -Append -FilePath "C:\Code\Update.log"

                # Return results to the main thread
                $output
            }

            $lastEventTime = $lastEventTime.AddSeconds(1)
        } 

        Start-Sleep -Seconds 5
    }
}

# Get a list of all provider names that contain 'Update' in their name
$providerNames = Get-WinEvent -ListProvider * -ErrorAction SilentlyContinue | 
                 Where-Object { $_.Name -like '*Update*' } | 
                 Select-Object -ExpandProperty Name

if (-not $providerNames) {
    Write-Host "No providers found with 'Update' in their name." -ForegroundColor Red
    return
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

    Start-Sleep -Seconds 5
}
