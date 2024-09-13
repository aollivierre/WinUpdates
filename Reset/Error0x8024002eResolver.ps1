# Define the path to the registry key
$regPath = "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate"

# Check if the key exists
if (Test-Path $regPath) {
    $keyValue = Get-ItemPropertyValue -Path $regPath -Name "DisableWindowsUpdateAccess" -ErrorAction SilentlyContinue

    # If the key's value is 1, then change it to 0
    if ($keyValue -eq 1) {
        Set-ItemProperty -Path $regPath -Name "DisableWindowsUpdateAccess" -Value 0
        Write-Output "Changed DisableWindowsUpdateAccess value to 0"
    }
    
    # Optionally, delete the entire key
    # Remove-Item -Path $regPath -Recurse
    # Write-Output "Deleted the WindowsUpdate registry key"
} else {
    Write-Output "The registry key does not exist."
}


# Note: The lines that would delete the entire key HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate are commented out for safety reasons. If you want to delete the key as per the solution, you can uncomment those lines. Before running scripts that modify the registry, make sure to back up your registry or take necessary precautions.
