# Setup PowerShell Profile and Environment Variables for use with a standard user and a Domain Admin account
# Version 1.4 - Copyright DM Tech - 2020
#
# DM's PowerShell profile setup wizard
# 
#         --- Important! ---
# 
# This script should be running in an elevated PowerShell session logged into the machine with your Domain Admin account
# Creation of the credential object will fail for any account other than the current user
# 
# Additionally, make sure you have an existing profile for your standard user account (log into your machine at least once)
# 
#  This script will:
# 
#  - Set the environment variables:
#        $Env:DevPath for System
#        $Env:UPNSuffix for System
#  - Create subfolders in DevPath for Profile and Modules
#  - Copy a common PowerShell profile to launch the shared profile
#  - Download and set up the PSStoredCredential function
#  - Setup Remote Server Admin Tools with the PSAdminTools Launcher and PowerShell 7

# Check for administrative rights
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning -Message "This script requires elevation"
    break
}

#######################################################################################################################
## Start Profile Templates ##

# This is a copy of: https://github.com/DTMaguire/PowerShell/blob/master/Profile/Microsoft.PowerShell_profile.ps1
# Placed here for convenience instead of setting up Git or creating a release for a simple block of text

$PSCommonTemplate = @'
# This is the default profile loaded by PowerShell upon launch.
# It's normally located under: C:\Users\(UserName)\Documents\WindowsPowerShell
# - or for PowerShell Core (v6+): C:\Users\(UserName)\Documents\PowerShell

# This file is just used for setting the user-scope environment variable and launching the main script
# Because I'm using multiple accounts, I just copy this into the location above for each one
# Customisations are then handled in the shared script
# I'm using this method instead of a global profile as to not impact any other user accounts

# UPN of Admin account for connecting to Office 365 with stored credentials

'@

$PSCommonTemplateAppend = @'

# Call the shared script from a common directory - put a shared profile in this location:
. "$Env:DevPath\Profile\Shared-PowerShell_Profile.ps1"

'@

## End Profile Templates ##
#######################################################################################################################

function SetEnvDev {
    $Script:SetDevPath = Read-Host -Prompt "Enter a full path for the DevPath environment variable to store your scripts (defaults to 'C:\Scripts\PowerShell')"
    if ([string]::IsNullOrWhiteSpace($SetDevPath)) {
        $Script:SetDevPath = 'C:\Scripts\PowerShell'
    }
    [System.Environment]::SetEnvironmentVariable('DevPath', $SetDevPath, [System.EnvironmentVariableTarget]::Machine)
}

function SetEnvUPN {
    $Script:UPNSuffix = (Read-Host -Prompt "Enter the UPN suffix (public domain) for cloud services")
    [System.Environment]::SetEnvironmentVariable('UPNSuffix', $UPNSuffix, [System.EnvironmentVariableTarget]::Machine)
}

Write-Host -ForegroundColor 'Magenta' @'

 DM's PowerShell profile setup wizard
 
         --- Important! ---
 
 This script should be running in an elevated PowerShell session logged into the machine with your Domain Admin account
 Creation of the credential object will fail for any account other than the current user
 
 Additionally, make sure you have an existing profile for your standard user account (log into your machine at least once)
 
 This script will:
 
  - Set the environment variables:
        $Env:DevPath for System
        $Env:UPNSuffix for System
  - Create subfolders in DevPath for Profile and Modules
  - Copy a common PowerShell profile to launch the shared profile
  - Download and set up the PSStoredCredential function
  - Setup Remote Server Admin Tools
  - Setup PSAdminTools and PowerShell 7

'@

# Set up the DevPath
do {
    if (($null -eq $Env:DevPath) -or (Read-Host -Prompt "`nDevPath set to: `'$Env:DevPath`' - change? (y/N)") -eq 'y') {
        SetEnvDev
    }
    else {
        $Script:SetDevPath = $Env:DevPath
    }

    if (!(Test-Path -Path $SetDevPath)) {
        Write-Host -ForegroundColor 'Cyan' "`nCreating: `'$SetDevPath`'`n"
        New-Item -ItemType 'Directory' -Path $SetDevPath -Force | Out-Null
    }

    try {
        Set-Location $SetDevPath
    }
    catch {
        Write-Error -Message "Unable to create or set location to `'$SetDevPath`'"
    }

} until ($SetDevPath)

# Set the user variables
do {

    if (($null -eq $Env:UPNSuffix) -or ((Read-Host -Prompt "`nUPNSuffix set to: `'$Env:UPNSuffix`' - change? (y/N)") -eq 'y')) {
        SetEnvUPN
    }
    else {
        $Script:UPNSuffix = $Env:UPNSuffix
    }

    $Script:UserAccount = ($Env:Username).Split('.')[1]
    if (($null -eq $UserAccount) -or (Read-Host -Prompt "`nSet username of your standard user account to `'$UserAccount`'? (Y/n)") -eq 'n') {
        $Script:UserAccount = (Read-Host "`nEnter the username of your standard user account")
    }

    $Script:AdminUPN = ($Env:Username + '@' + $UPNSuffix).ToLower()

} until ((Read-Host -Prompt "`nPlease confirm the AdminUPN is correct: `'$AdminUPN`' (y/N)") -eq 'y')

# Check if the standard user is logged on before proceeding
quser.exe 2>&1 | Select-Object -Skip 1 | ForEach-Object {
    $CurrentLine = $_.Trim() -Replace '\s+',' ' -replace '>','' -Split '\s'
    if ($UserAccount -match $CurrentLine[0]) {
        Write-Host "`n"
        Write-Warning "There appears to be an active user session for `'$UserAccount`' - please log it off and restart the script"
        exit
    }
}

# Create the Modules directory
if (!(Test-Path -Path "$SetDevPath\Modules")) {
    New-Item -ItemType 'Directory' -Name 'Modules' -Force
}

# Create the Profile directory
$ProfilePath = "$SetDevPath\Profile"
if (!(Test-Path -Path $ProfilePath)) {
    New-Item -ItemType 'Directory' -Name 'Profile' -Force
}

# Set up the web client to download files
$WebClient = New-Object System.Net.WebClient
$WebClient.Proxy.Credentials = ([System.Net.CredentialCache]::DefaultNetworkCredentials)

# Create a common profile from the template
$PSCommonPath = "$ProfilePath\Microsoft.PowerShell_profile.ps1"
New-Item -ItemType File $PSCommonPath -Value $PSCommonTemplate -Force
Add-Content -Path $PSCommonPath -Value '$env:AdminUPN = ' -NoNewline
Add-Content -Path $PSCommonPath -Value "`'$AdminUPN`'"
Add-Content -Path $PSCommonPath -Value $PSCommonTemplateAppend

if ((Test-Path -Path "$ProfilePath\Shared-PowerShell_Profile.ps1" -PathType Leaf) -eq $true) {
    Write-Host -ForegroundColor 'Cyan' "`nOverwriting existing file: $ProfilePath\Shared-PowerShell_Profile.ps1`n"
}
$SharedProfileURL = 'https://raw.githubusercontent.com/DTMaguire/PowerShell/master/Profile/Shared-PowerShell_Profile.ps1'
$WebClient.DownloadFile($SharedProfileURL,"$ProfilePath\Shared-PowerShell_Profile.ps1")

# Track down the 'Documents' folder location via the registry as it might have moved to somewhere like OneDrive
$SIDs = (Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList').Name.Replace('HKEY_LOCAL_MACHINE','HKLM:')
$ProfileImagePath = (ForEach-Object -InputObject $SIDs {(Get-ItemProperty $_ | Where-Object {$_.ProfileImagePath -like "*\$UserAccount"})}).ProfileImagePath

New-PSDrive HKU Registry HKEY_USERS
reg.exe load "HKU\$UserAccount" "$ProfileImagePath\NTUSER.DAT"

$ShellFolders = ('HKU:\' + $UserAccount + '\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders')

# The '-replace' is a trick to catch any returned values that include an environment variable as PowerShell immediately evaluates these
# This means something like '%USERPROFILE%\Documents' read from the user's registry hive is turned into the path to the Admin's documents instead
# This doesn't do anything for absolute paths since there is no match and the exection continues 
$UserDocuments = (Get-ItemPropertyValue $ShellFolders -Name 'Personal') -replace "$Env:Username","$UserAccount"
$UserDesktop = (Get-ItemPropertyValue $ShellFolders -Name 'Desktop') -replace "$Env:Username","$UserAccount"

reg.exe unload "HKU\$UserAccount"
Remove-PSDrive HKU

$AdminDocuments = (Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name 'Personal')

$ProfileDestinations = @($AdminDocuments,$UserDocuments)
$PSDirectories = @('PowerShell','WindowsPowerShell')

foreach ($Destination in $ProfileDestinations) {
    foreach ($PSDirectory in $PSDirectories) {
        
        $PSProfilePath = (Join-Path -Path $Destination -ChildPath $PSDirectory)

        if (!(Test-Path -PathType Container $PSProfilePath)) {
            Write-Host -ForegroundColor 'Cyan' "`nCreating: $PSProfilePath"
            New-Item -Path $Destination -Name $PSDirectory -ItemType Directory -Force
        }

        Write-Host -ForegroundColor 'Cyan' "`nCopying `'Microsoft.PowerShell_profile.ps1`' to: $PSProfilePath"
        Copy-Item $PSCommonPath -Destination $PSProfilePath -Force
    }
}

Write-Host "`nFinished copying common profile files"

function Set-SecurityProtocols() {
    Write-Host -ForegroundColor 'White' "`nSecurity protocol issue, updating settings"
    Write-Host "Original setting: $([System.Net.ServicePointManager]::SecurityProtocol)" 
    $AvailableProtocols = [string]::join(', ', [Enum]::GetNames([System.Net.SecurityProtocolType])) 
    Write-Host "Available: $AvailableProtocols"

    # Use whatever protocols are available that the server supports 
    try { 
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] $AvailableProtocols
    }
    catch { 
        [System.Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12" 
    }
}

if (!((Read-Host -Prompt "`nSetup stored credentials function now? (Y/n)") -eq 'N')) {

    Set-Location $ProfilePath
    $StoredFunctionURL = 'https://github.com/cunninghamp/PowerShell-Stored-Credentials/archive/v1.0.0.zip'
    $ZipFile = 'PowerShell-Stored-Credentials-1.0.0.zip'

    try {
        $WebClient.DownloadFile($StoredFunctionURL,"$ProfilePath\$ZipFile")
        Write-Host -ForegroundColor 'Green' "`n$ZipFile downloaded with default network settings`n"
    }
    catch {
        # Try again with different protocols...
        try {
            Set-SecurityProtocols
            $WebClient.DownloadFile($StoredFunctionURL,"$ProfilePath\$ZipFile")
            Write-Host -ForegroundColor 'Green' "`n$ZipFile downloaded with updated network settings`n"   
        }
        catch {
            Write-Warning -Message "`nUnable to download `'$ZipFile`' from GitHub - save the file to your profile path and re-run this script"
        }
    }

    if (Test-Path -Path "$ProfilePath\$ZipFile" -PathType Leaf) {
        Write-Host "Unpacking zip archive"
        Expand-Archive -Path $ZipFile
        Start-Sleep 1
        Copy-Item ".\PowerShell-Stored-Credentials-1.0.0\PowerShell-Stored-Credentials-1.0.0\Functions-PSStoredCredentials.ps1" -Destination $ProfilePath
        Start-Sleep 1
        Remove-Item -Recurse -Path '.\PowerShell-Stored-Credentials-1.0.0' -Confirm:$false -Force
        Remove-Item -Path $ZipFile -Confirm:$false -Force
    }
    else {
        Write-Warning "`nUnable to expand archive - you can download the file manually and extract .ps1 file to $ProfilePath`n"
    }

    Write-Host -ForegroundColor 'White' "`nPrompting for credentials to save - make sure the username is: `'$AdminUPN`'"
    Start-Sleep 1
    $Credential = Get-Credential -Message "Enter your Domain Admin account password" -UserName $AdminUPN
    $KeyPath = $AdminDocuments + '\PowerShell'
    $Credential.Password | ConvertFrom-SecureString | Out-File "$($KeyPath)\$($Credential.Username).cred" -Force
}

if (!((Read-Host -Prompt "`nSetup PSAdminTools and PowerShell 7 now? (Y/n)") -eq 'N')) {

    $AdminTools = @(Get-WindowsCapability -Name RSAT* -Online | Where-Object State -ne 'Installed')
    $ToolsPath = (Split-Path $SetDevPath -Parent) + '\AdminTools'

    foreach ($Tool in $AdminTools) {
        Write-Progress -Activity "Installing" -Status ($Tool.DisplayName) -PercentComplete (($AdminTools.IndexOf($Tool) / $AdminTools.Count) * 100)
        Add-WindowsCapability -Online -Name $Tool.Name | Out-Null
    }
    
    $Script:PS7 = [bool](Get-CimInstance -ClassName Win32_Product -Filter "Name='PowerShell 7-x64'")

    # Try to install PowerShell 7, but don't care too much if it fails
    if (!($PS7)) {
        choco install powershell-core -y
    }
    $Script:PS7 = [bool](Get-CimInstance -ClassName Win32_Product -Filter "Name='PowerShell 7-x64'")

    $PSAdminToolsURL = 'https://raw.githubusercontent.com/DTMaguire/PowerShell/master/PSAdminTools.ps1'
    $WebClient.DownloadFile($PSAdminToolsURL,"$SetDevPath\PSAdminTools.ps1")

    $ExchOnlineURL = 'https://raw.githubusercontent.com/DTMaguire/PowerShell/master/Profile/Connect-ExchOnline.ps1'
    $WebClient.DownloadFile($ExchOnlineURL,"$ProfilePath\Connect-ExchOnline.ps1")

    $ShortcutLocation = Join-Path -Path $UserDesktop 'PSAdminTools Launcher.lnk'
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutLocation)
    $Shortcut.TargetPath = 'C:\Windows\System32\runas.exe'
    
    if ($PS7) {
        # PowerShell 7: 
        $Shortcut.Arguments = '/user:' + "$Env:USERDOMAIN\$Env:USERNAME" + ' /savecred "C:\Program Files\PowerShell\7\pwsh.exe -NoProfile -File %DEVPATH%\PSAdminTools.ps1"'
    }
    else {
        # PowerShell 5: 
        $Shortcut.Arguments = '/user:' + "$Env:USERDOMAIN\$Env:USERNAME" + ' /savecred "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -File %DEVPATH%\PSAdminTools.ps1"'
    }

    $Shortcut.WorkingDirectory = '%DEVPATH%'
    $Shortcut.IconLocation = '%SystemRoot%\System32\BitLockerWizard.exe,0'
    $Shortcut.Save()

    # If the AdminTools directory doesn't exist, create it and copy some shortcuts as a demo
    if (!(Test-Path $ToolsPath)) {
        New-Item -Path (Split-Path $SetDevPath -Parent) -Name 'AdminTools' -ItemType Directory -Force
    }
    
    Copy-Item -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Computer Management.lnk' -Destination $ToolsPath
    Copy-Item -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Registry Editor.lnk' -Destination $ToolsPath
    Copy-Item -Path "$Env:APPDATA\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk" -Destination "$ToolsPath\PowerShell 5.lnk"

    if ($PS7) {
        Copy-Item -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\PowerShell\PowerShell 7 (x64).lnk' -Destination "$ToolsPath\PowerShell 7.lnk"
    }
    
    # Try out some optional components
    try {
        Copy-Item -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Active Directory Administrative Center.lnk' -Destination $ToolsPath
        Copy-Item -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Active Directory Users and Computers.lnk' -Destination $ToolsPath
        Copy-Item -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\DHCP.lnk' -Destination $ToolsPath
        Copy-Item -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\DNS.LNK' -Destination $ToolsPath
        Copy-Item -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Group Policy Management.lnk' -Destination $ToolsPath
        Copy-Item -Path 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Administrative Tools\Server Manager.lnk' -Destination $ToolsPath
    }
    catch {
        Write-Host -ForegroundColor Yellow "Oh well, I tried..."
    }
}

$PSTemplate = [Uri]'https://github.com/DTMaguire/PowerShell/tree/master/Profile'
Write-Host -ForegroundColor 'Green' "`nInitial profile setup complete! See: $PSTemplate for example scripts to add to your own profile"
Set-Location $SetDevPath
