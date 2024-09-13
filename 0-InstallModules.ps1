[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$moduleExists = Get-Module -ListAvailable -Name PSWindowsUpdate
if (-not $moduleExists) {
    Install-Module -Name PSWindowsUpdate -Scope AllUsers -Force -Verbose
}
Import-Module PSWindowsUpdate
Get-Command -Module PSWindowsUpdate