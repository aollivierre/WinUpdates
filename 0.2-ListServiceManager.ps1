<#
.SYNOPSIS
    A short one-line action-based description, e.g. 'Tests if a function is valid'
.DESCRIPTION
    A longer description of the function, its purpose, common use cases, etc.
.NOTES
    Information or caveats about the function e.g. 'This function is not supported in Linux'
.LINK
    Specify a URI to a help page, this will show when Get-Help -Online is used.
.EXAMPLE
    Test-MyTestFunction -Verbose
    Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
#>

# PS C:\Code> Get-WUServiceManager

# ServiceID                            IsManaged IsDefault Name
# ---------                            --------- --------- ----
# 7971f918-a847-4430-9279-4a52d1efe18d False     True      Microsoft Update
# 8b24b027-1dee-babb-9a95-3517dfb9c552 False     False     DCat Flighting Prod
# 855e8a7c-ecb4-4ca3-b045-1dfa50104289 False     False     Windows Store (DCat Prod)
# 3da21691-e39d-4da6-8a4b-b43877bcb1b7 True      False     Windows Server Update Service
# 9482f4b4-e343-43b6-b170-9a65bc822c77 False     False     Windows Update


Get-WUServiceManager