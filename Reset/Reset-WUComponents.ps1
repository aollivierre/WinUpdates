# Run as Administrator
Stop-Service -Name wuauserv -Force
Stop-Service -Name cryptSvc -Force
Stop-Service -Name bits -Force
Stop-Service -Name msiserver -Force

# Renaming folders
Rename-Item -Path C:\Windows\SoftwareDistribution -NewName SoftwareDistribution.old -Force -ErrorAction SilentlyContinue
Rename-Item -Path C:\Windows\System32\catroot2 -NewName catroot2.old -Force -ErrorAction SilentlyContinue

# Re-registering DLLs for Windows Update
$dlls = @(
    "atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll", "jscript.dll", "vbscript.dll", "scrrun.dll",
    "msxml.dll", "msxml3.dll", "msxml6.dll", "actxprxy.dll", "softpub.dll", "wintrust.dll", "dssenh.dll", "rsaenh.dll", 
    "gpkcsp.dll", "sccbase.dll", "slbcsp.dll", "cryptdlg.dll", "oleaut32.dll", "ole32.dll", "shell32.dll", "initpki.dll", 
    "wuapi.dll", "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll", "wups2.dll", "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", 
    "wucltux.dll", "muweb.dll", "wuwebv.dll"
)

foreach ($dll in $dlls) {
    regsvr32.exe /s $dll
}

# Restarting services
Start-Service -Name wuauserv
Start-Service -Name cryptSvc
Start-Service -Name bits
Start-Service -Name msiserver

Write-Host "Windows Update components have been reset!" -ForegroundColor Green