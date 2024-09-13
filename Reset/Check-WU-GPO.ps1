# Check if the user has administrative privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "You need to run this script as an Administrator!"
    exit
}

# Define the registry path and key
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
$regName = "NoAutoUpdate"

# Check if the key exists and remove it to set the policy to 'Not Configured'
if (Test-Path $regPath) {
    if (Get-ItemProperty -Path $regPath | Get-Member -MemberType Properties -Name $regName) {
        Remove-ItemProperty -Path $regPath -Name $regName
        Write-Host "Configure Automatic Updates set to 'Not Configured'" -ForegroundColor Green
    } else {
        Write-Host "Configure Automatic Updates is already 'Not Configured'" -ForegroundColor Yellow
    }
} else {
    Write-Host "Configure Automatic Updates is already 'Not Configured'" -ForegroundColor Yellow
}

# Force refresh of Group Policy
gpupdate /force