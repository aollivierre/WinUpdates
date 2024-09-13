function Write-ColoredLog {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [ConsoleColor]$Color = [ConsoleColor]::White
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp - $Message" -ForegroundColor $Color
}

# Check and display WUServer and UseWUServer key value before changes
$regPath1 = "HKLM:\SOFTWARE\Policies\Microsoft\windows\WindowsUpdate"
$WUServerValue = Get-ItemPropertyValue -Path $regPath1 -Name "WUServer" -ErrorAction SilentlyContinue
$regPath2 = "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
$UseWUServerValue = Get-ItemPropertyValue -Path $regPath2 -Name "UseWUServer" -ErrorAction SilentlyContinue

Write-ColoredLog -Message "Initial WUServer value: $WUServerValue" -Color Yellow
Write-ColoredLog -Message "Initial UseWUServer value: $UseWUServerValue" -Color Yellow

# Remove specified registry keys
$keysToRemove = @('WUServer', 'TargetGroup', 'WUStatusServer', 'TargetGroupEnabled')
foreach ($key in $keysToRemove) {
    try {
        if (Get-ItemProperty -Path $regPath1 -Name $key -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $regPath1 -Name $key -Force
            Write-ColoredLog -Message "Removed property '$key' from '$regPath1'" -Color Green
        }
        else {
            Write-ColoredLog -Message "Property '$key' not found in '$regPath1'" -Color Red
        }
    }
    catch {
        Write-ColoredLog -Message "Error removing property '$key' from '$regPath1': $_" -Color Red
    }
}

# Modify specified registry keys
$propertiesToSet = @{
    'UseWUServer'                = 0;
    'NoAutoUpdate'               = 0;
    'DisableWindowsUpdateAccess' = 0;
}

foreach ($property in $propertiesToSet.Keys) {
    try {
        $path = if ($property -eq 'DisableWindowsUpdateAccess') { $regPath1 } else { $regPath2 }
        Set-ItemProperty -Path $path -Name $property -Value $propertiesToSet[$property] -Force
        Write-ColoredLog -Message "Set property '$property' to $($propertiesToSet[$property]) in '$path'" -Color Green
    }
    catch {
        Write-ColoredLog -Message "Error setting property '$property' in '$path': $_" -Color Red
    }
}

# Restart Windows Update Service
try {
    Restart-Service -Name wuauserv -Force
    Write-ColoredLog -Message "Restarted 'wuauserv' service" -Color Green
}
catch {
    Write-ColoredLog -Message "Error restarting 'wuauserv' service: $_" -Color Red
}

# Check and display WUServer and UseWUServer key value after changes
$WUServerValueAfter = Get-ItemPropertyValue -Path $regPath1 -Name "WUServer" -ErrorAction SilentlyContinue
$UseWUServerValueAfter = Get-ItemPropertyValue -Path $regPath2 -Name "UseWUServer" -ErrorAction SilentlyContinue

Write-ColoredLog -Message "Final WUServer value: $WUServerValueAfter" -Color Yellow
Write-ColoredLog -Message "Final UseWUServer value: $UseWUServerValueAfter" -Color Yellow