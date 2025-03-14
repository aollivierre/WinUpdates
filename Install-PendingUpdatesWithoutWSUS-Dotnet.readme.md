# Install-PendingUpdatesWithoutWSUS-Dotnet

## Overview
This PowerShell script is designed to address Windows Update issues in WSUS-managed environments, with a specific focus on both .NET Framework updates and modern .NET (5/6/7/8) installations and updates. It temporarily disables WSUS settings to allow direct connections to Microsoft Update servers, installs pending updates, and then restores the original WSUS configuration.

## Problem Addressed
In environments using Windows Server Update Services (WSUS), .NET updates may fail to install properly for several reasons:
- Required updates may not be approved or synchronized in the WSUS catalog
- WSUS configuration may block direct access to Microsoft update servers
- .NET Framework updates have specific dependencies that may not be met
- Modern .NET versions (.NET 5/6/7/8) require separate installation processes that can be blocked by WSUS

This script solves these issues by:
1. Temporarily bypassing WSUS, allowing direct access to all available updates from Microsoft for .NET Framework
2. Providing direct installation capabilities for modern .NET versions (including .NET 8.0.13)

## Key Features
- **Temporary WSUS Bypass**: Safely disables WSUS settings and restores them after completion
- **.NET Framework Focus**: Specifically identifies and prioritizes .NET Framework updates
- **.NET Version Detection**: Automatically detects installed .NET Framework and modern .NET versions
- **Modern .NET Installation**: Direct installation of modern .NET (5/6/7/8) versions, including:
  - Specific .NET 8.0.13 installation option
  - Support for selecting specific versions and components
  - Options to install Runtime or SDK versions
  - Support for ASP.NET Core components
- **Multiple Installation Options**:
  - Install only .NET Framework updates
  - Install .NET Framework updates first, then other updates
  - Install all Windows updates
  - Repair .NET Framework update issues before installation
  - Install or update .NET 8.0.13 specifically
  - Install or update any modern .NET version (6.0, 7.0, or 8.0)
  - Check and install .NET Runtime Host Updates (KB updates) specifically
- **Preview Updates Option**: Ability to include preview updates if needed
- **.NET Update Verification**: Verifies successful installation of .NET updates
- **Repair Functionality**: Troubleshoots and fixes common .NET update issues
- **Comprehensive Logging**: Clear, color-coded console output

## Prerequisites
- Windows PowerShell 5.1 or higher
- Administrative privileges
- Internet access to Microsoft Update servers and .NET download sites
- PowerShell execution policy that allows running scripts
- Dependencies:
  - PSWindowsUpdate module (will be automatically installed if not present)
  - For modern .NET installation, temporary internet access to download .NET installers

## Usage Instructions
1. Run the script as Administrator
2. Select from the following installation options:
   - Option 1: Install .NET Framework updates only
   - Option 2: Install .NET Framework updates first, then other updates
   - Option 3: Install all Windows updates (default)
   - Option 4: Repair .NET Framework update issues, then install updates
   - Option 5: Install or update .NET 8.0.13 (modern .NET)
   - Option 6: Install or update specific .NET version
   - Option 7: Check and install .NET Runtime Host Updates (KB updates)
3. Based on your selection:
   - For Windows Update options (1-4): Choose whether to include preview updates
   - For modern .NET options (5-6): Follow the prompts to customize the installation
   - For Runtime Host Updates (7): The script will search for and display available KB updates

### Modern .NET Installation Options
When selecting Options 5 or 6, you'll be presented with additional choices:
- For Option 5:
  - The script will automatically handle installation/updating of .NET 8.0.13
- For Option 6:
  - Select which .NET version to install (6.0, 7.0, or 8.0)
  - Choose whether to include ASP.NET Core components
  - Choose whether to install the SDK instead of just the Runtime
  - Optionally specify a particular version number

## Technical Details

### How WSUS Bypassing Works
The script modifies the following registry settings to temporarily bypass WSUS:
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\UseWUServer` → Set to 0
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\DoNotConnectToWindowsUpdateInternetLocations` → Set to 0
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\DisableWindowsUpdateAccess` → Set to 0

These changes allow the system to connect directly to Microsoft Update servers instead of the configured WSUS server. All original settings are backed up and restored after updates are installed.

### .NET Framework vs. Modern .NET
It's essential to understand the difference between .NET Framework and modern .NET:

1. **.NET Framework**:
   - Built into Windows
   - Updated through Windows Update
   - Versions include 3.5, 4.5, 4.6, 4.7, 4.8
   - Legacy technology, primarily for older applications
   - **Installation Method**: Windows Update or Windows Features

2. **Modern .NET (formerly .NET Core)**:
   - Installed separately from Windows
   - Cross-platform (.NET 5+)
   - Updated through separate installers, not Windows Update
   - Versions include 5.0, 6.0, 7.0, 8.0
   - Current technology for new development
   - **Installation Method**: Custom installer (not MSI), downloaded directly from Microsoft

This script handles both types of .NET updates/installations appropriately.

### Modern .NET Installation Technical Details

When you select options 5 or 6 to install modern .NET, the process is completely independent from Windows Update and WSUS:

1. **Independence from Windows Update**:
   - The modern .NET installation bypasses Windows Update completely
   - It does NOT require the PSWindowsUpdate module
   - It does NOT need to modify any WSUS settings or registry keys
   - It works even in environments where Windows Update is locked down by WSUS policies

2. **Installation Technology**:
   - Does NOT use Windows Installer (MSI) technology
   - Downloads Microsoft's official installer script (`dotnet-install.ps1`)
   - This script downloads compressed ZIP packages from Microsoft's CDN
   - Extracts these packages to Program Files\dotnet
   - Sets up necessary environment variables
   - All network traffic goes directly to Microsoft's download servers, not update servers

3. **Installation Method Comparison**:
   - **This script uses the PowerShell script method**, not the EXE installer method
   - **Website Download Method**: When downloading manually from the .NET website, you get an EXE installer (e.g., `dotnet-sdk-8.0.407-win-x64.exe`) with a graphical interface
   - **Script Method**: This script uses Microsoft's `dotnet-install.ps1` which performs a silent, automated installation without a GUI
   - Both methods are officially supported by Microsoft, but the script method is better suited for automation

4. **Network Requirements**:
   - Requires internet access to `dot.net` and `download.visualstudio.microsoft.com` domains
   - Typically downloads between 50-200 MB depending on the .NET version and components selected
   - HTTP/HTTPS traffic on standard ports (80/443)

5. **Silent Installation**:
   - The installation is non-interactive
   - Doesn't require user input once started
   - Doesn't display any GUI

6. **Side-by-Side Installation**:
   - Multiple versions of modern .NET can coexist on the same system
   - Installing a new version doesn't remove older versions
   - Applications can target specific versions

This approach ensures that modern .NET can be installed regardless of your Windows Update configuration, as long as you have access to the internet and sufficient permissions to install applications.

### Important: Modern .NET Updates vs. Runtime Host Updates

There's a critical distinction to understand about modern .NET updates:

1. **Initial Installation and Major Version Updates**:
   - The full .NET runtime and SDK installations are **not** distributed through Windows Update
   - These require direct installation using either:
     - The EXE installer from the .NET website
     - The PowerShell script method (what this script uses)
   - This is why options 5 and 6 in our script are necessary

2. **Runtime Host Updates and Security Patches**:
   - Once .NET is installed, Microsoft distributes certain servicing updates through Windows Update
   - These appear with KB numbers (e.g., "KB5052976 - .NET 8.0.13 Update for x64 Client")
   - These updates only apply to already installed .NET runtimes
   - They do not install the full .NET runtime if it's not already present
   - In WSUS environments, these updates may still be blocked if not approved
   - **Option 7 in our script specifically handles these KB-based updates**

3. **When to Use This Script vs. Windows Update**:
   - Use this script when:
     - .NET is not yet installed on the system
     - A new major/minor version is needed
     - Runtime host updates are failing through WSUS
   - Windows Update is sufficient when:
     - .NET is already properly installed
     - You only need small servicing updates
     - Your WSUS environment properly approves these updates

4. **Dual Update Paths** (Microsoft's Strategy):
   - Initial installation: Direct from Microsoft (not Windows Update)
   - Servicing updates: Can come through Windows Update with KB numbers
   - Security patches: Can come through Windows Update with KB numbers

5. **Complete Solution with This Script**:
   - Our script now addresses both parts of the .NET update strategy:
     - Options 5-6: Install/update the core .NET runtime (outside Windows Update)
     - Option 7: Install KB-based runtime host updates (through Windows Update)
   - Modern .NET installations (options 5-6) automatically check for runtime host updates after installation
   - This ensures you get both the core runtime and any available security patches in one operation

This hybrid approach can cause confusion, but understanding which updates come through which channels helps clarify when this script is needed versus when standard Windows Update is sufficient.

### PSWindowsUpdate Module Dependency
This script uses the PSWindowsUpdate module to interact with Windows Update. The script will:
1. Check if the module is installed
2. Attempt to install it automatically if not found
3. Import the module for use

For the script to function properly, it requires:
- Internet access to download the module if not present
- Access to the PowerShell Gallery
- Permissions to install PowerShell modules

## Common Issues and Troubleshooting
- **Module Installation Fails**: Ensure you have internet access and can reach the PowerShell Gallery
- **Updates Still Fail**: Try the repair option (Option 4) which clears update caches and resets components
- **Specific .NET Update Needed**: Use the Microsoft Update Catalog link provided at the end of script execution
- **Modern .NET Installation Fails**: If automatic installation fails, the script will provide a direct download link for manual installation

## Manual .NET Updates
If automatic updates continue to fail:
- For .NET Framework: https://www.catalog.update.microsoft.com
- For modern .NET (5/6/7/8): https://dotnet.microsoft.com/download

## Disclaimer
Always back up important data before installing updates. While this script attempts to safely modify and restore system settings, use at your own risk in production environments.

## License
This script is provided "as is" without warranty of any kind.
