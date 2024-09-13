# Function to print colored messages
function Print-ColorMessage {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$true)]
        [ConsoleColor]$Color
    )

    Write-Host $Message -ForegroundColor $Color
}

# Check WUServer key value
$regPath1 = "HKLM:\SOFTWARE\Policies\Microsoft\windows\WindowsUpdate"
$WUServerValue = Get-ItemPropertyValue -Path $regPath1 -Name "WUServer" -ErrorAction SilentlyContinue

if ($WUServerValue) {
    Print-ColorMessage -Message "WUServer is currently set to: $WUServerValue" -Color Yellow
} else {
    Print-ColorMessage -Message "WUServer key does not exist or there was an error fetching its value." -Color Red
}

# Check current UseWUServer key value
$regPath2 = "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"
$UseWUServerCurrentValue = Get-ItemPropertyValue -Path $regPath2 -Name "UseWUServer" -ErrorAction SilentlyContinue

Print-ColorMessage -Message "UseWUServer is currently set to: $UseWUServerCurrentValue" -Color Yellow

# Modify UseWUServer key value
try {
    Set-ItemProperty -Path $regPath2 -Name "UseWUServer" -Value 0 -ErrorAction Stop
    
    # Check updated UseWUServer key value
    $UseWUServerUpdatedValue = Get-ItemPropertyValue -Path $regPath2 -Name "UseWUServer" -ErrorAction SilentlyContinue
    Print-ColorMessage -Message "Updated UseWUServer value to: $UseWUServerUpdatedValue" -Color Green

    # Restart Windows Update Service
    #Restart-Service -Name wuauserv -Force
    Print-ColorMessage -Message "Windows Update service restarted." -Color Green
}
catch {
    Print-ColorMessage -Message "There was an error updating UseWUServer or restarting the Windows Update service." -Color Red
}