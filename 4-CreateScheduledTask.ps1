$TaskName = "Update Office Vulnerability Patches CVE-2023-23397"
$TaskDescription = "Updates Microsoft Office products to remediate CVE-2023-23397 vulnerability."
# $ScriptPath = "\\fileserver\scripts\UpdateOfficeVulnerabilityPatchesCVE-2023-23397.ps1"
$ScriptPath = "\\GLB-APP01\Patch\CVE_2023_23397\3-UpdateOfficeVulnerabilityPatches.ps1"

$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $ScriptPath"
$Trigger = New-ScheduledTaskTrigger -AtLogon
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0

$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Description $TaskDescription

Register-ScheduledTask -TaskName $TaskName -InputObject $Task
