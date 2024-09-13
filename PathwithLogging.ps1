function AppendCSVLog {
    param (
        [string]$Message,
        [string]$CSVFilePath
    )

    $csvData = [PSCustomObject]@{
        TimeStamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        Message = $Message
    }

    $csvData | Export-Csv -Path $CSVFilePath -Append -NoTypeInformation -Force
}

function Write-EventLogMessage {
    param (
        [string]$Message,
        [string]$LogName = 'PowerShellScriptLog'
    )

    $source = 'PowerShell Script'
    if (-not (Get-WinEvent -LogName $LogName -ErrorAction SilentlyContinue)) {
        New-EventLog -LogName $LogName -Source $source
    }

    Write-EventLog -LogName $LogName -Source $source -EntryType Information -EventId 1 -Message $Message
}

function Write-Log {
    param (
        [string]$Message,
        [string]$CSVFilePath
    )

    Write-Output $Message
    AppendCSVLog -Message $Message -CSVFilePath $CSVFilePath
    Write-EventLogMessage -Message $Message
}

# ... (rest of the script)

# Replace all Write-Output statements with Write-Log, for example:
Write-Log -Message "$installedproduct $installedversion installed." -CSVFilePath $csvLogFile
# Do this for all Write-Output statements

# ... (rest of the script)

