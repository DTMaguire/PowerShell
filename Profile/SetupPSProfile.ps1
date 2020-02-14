# Setup PowerShell Profile and Environment Variables for use with a standard user and a Domain Admin account
# Version 1.2 - Copyright DM Tech - 2020
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

#######################################################################################################################
## Start Profile Templates ##

# This is a copy of: https://github.com/DTMaguire/PowerShell/blob/master/Profile/Microsoft.PowerShell_profile.ps1
# Placed here for convenience instead of setting up Git or creating a release for a simple block of text

$PSCommonTemplate = @'
# This is the default profile loaded by PowerShell upon launch.
# It's normally located under: C:\Users\(UserName)\Documents\WindowsPowerShell
# - or for PowerShell Core (v6+): C:\Users\(UserName)\Documents\PowerShell

<#
 This file is just used for setting the user-scope environment variable and launching the main script.
 Because I'm using multiple accounts, I just copy this into the location above for each one.
 Customisations are then handled in the shared script.
 I'm using this method instead of a global profile as to not impact any other user accounts.
#>

# UPN of Admin account for connecting to Office 365 with stored credentials

'@

$PSCommonTemplateAppend = @'

# Call the shared script from a common directory - put a shared profile in this location:
. "$Env:DevPath\Profile\Shared-PowerShell_Profile.ps1"

'@

# This is a copy of: https://github.com/DTMaguire/PowerShell/blob/master/Profile/DM-PowerShell_Profile.ps1
# Again, placed here for convenience and can be edited as required

$PSSharedTemplate =  @'
# Common profile script to be called by the default Microsoft.PowerShell_profile.ps1
# Copyright DM Tech 2020
#
# Prerequisites:
#   A system or user environment variable $Env:DevPath with the path to your scripts directory
#   A system or user environment variable $Env:AdminUPN for the relevant domain/cloud service account

# Set the start location to the DevPath
Set-Location -Path "$Env:DevPath"

# Add the Modules folder in the $Env:DevPath to the PSModulePath for easy access to custom modules 
$Env:PSModulePath += (';' + "$Env:DevPath" + '\Modules')

#### Fancy stored credentials bit ####

# Set the $KeyPath variable to somewhere sensible as required by Functions-PSStoredCredentials.ps1 (per user)
$KeyPath = (Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' -Name 'Personal') + '\PowerShell'

<#
    This checks if the $Env:AdminUPN environment variable exists for specifying an admin username for authentication
    If so, dot-source 'Functions-PSStoredCredentials.ps1' and load the .cred file into a PowerShell credential object
    For more info, see: 
    https://practical365.com/blog/saving-credentials-for-office-365-powershell-scripts-and-scheduled-tasks/
#>

# Test to see if admin credentials exist
if (Test-Path "${KeyPath}\${env:AdminUPN}.cred") {

    # Dot source the function to enable the Get-StoredCredential function from $KeyPath
    . '.\Profile\Functions-PSStoredCredentials.ps1'

    # Get-StoredCredential uses the .cred file in $KeyPath generated by New-StoredCredential
    $AdminCredential = (Get-StoredCredential -UserName $Env:AdminUPN)
}

#### End fancy stored credentials ####

# Proxy settings to allow access to web/remote stuff like Office 365 and the PowerShell Gallery
#$WebClient = New-Object System.Net.WebClient
#$WebClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

# Assume Windows 10 and add the Chocolately profile
$ChocolateyProfile = "$Env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# Show a custom message
Write-Host -ForegroundColor 'White' `
"Running as $Env:Username with profile path: $KeyPath `nDomain admin credentials loaded:" $([bool]$AdminCredential)"`n"

'@

## End Profile Templates ##
#######################################################################################################################

function SetEnvDev {
    $Script:SetDevPath = Read-Host `
    -Prompt "Enter a full path for the DevPath environment variable to store your scripts (defaults to 'C:\Scripts\PowerShell')"
    if ([string]::IsNullOrWhiteSpace($SetDevPath)) {
        $Script:SetDevPath = 'C:\Scripts\PowerShell'
    }
    [System.Environment]::SetEnvironmentVariable('DevPath', $SetDevPath, [System.EnvironmentVariableTarget]::Machine)
}

function SetEnvUPN {
    $Script:UPNSuffix = (Read-Host -Prompt "Enter the UPN suffix (public domain) for cloud services")
    [System.Environment]::SetEnvironmentVariable('UPNSuffix', $UPNSuffix, [System.EnvironmentVariableTarget]::Machine)
}

Write-Host -ForegroundColor 'Magenta' @"

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

"@

# Set up the DevPath
do {
    if (($null -eq $Env:DevPath) -or (Read-Host -Prompt "`nDevPath set to: `'$Env:DevPath`' - change? (y/N)") -eq 'y') {
        SetEnvDev
    } else {
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
        Write-Error -Message `
            "Unable to create or set location to `'$SetDevPath`'"
    }

} until ($SetDevPath)

# Set the user variables
do {

    if (($null -eq $Env:UPNSuffix) -or ((Read-Host -Prompt "`nUPNSuffix set to: `'$Env:UPNSuffix`' - change? (y/N)") -eq 'y')) {
        SetEnvUPN
    } else {
        $Script:UPNSuffix = $Env:UPNSuffix
    }

    $Script:UserAccount = ($Env:Username).Split('.')[1]
    if ((Read-Host -Prompt "`nSet username of your standard user account to `'$UserAccount`'? (Y/n)") -eq 'n') {
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


if (!(Test-Path -Path "$SetDevPath\Modules")) {
    New-Item -ItemType 'Directory' -Name 'Modules' -Force
}

$ProfilePath = "$SetDevPath\Profile"

if (!(Test-Path -Path $ProfilePath)) {
    New-Item -ItemType 'Directory' -Name 'Profile' -Force
}

$PSCommonPath = "$ProfilePath\Microsoft.PowerShell_profile.ps1"

New-Item -ItemType File $PSCommonPath -Value $PSCommonTemplate -Force
Add-Content -Path $PSCommonPath -Value '$env:AdminUPN = ' -NoNewline
Add-Content -Path $PSCommonPath -Value "`'$AdminUPN`'"
Add-Content -Path $PSCommonPath -Value $PSCommonTemplateAppend

if ((Test-Path -Path "$ProfilePath\Shared-PowerShell_Profile.ps1" -PathType Leaf) -eq $true) {
    Write-Host -ForegroundColor 'Cyan' "`nOverwriting existing file: $ProfilePath\Shared-PowerShell_Profile.ps1`n"
}
New-Item -ItemType File "$ProfilePath\Shared-PowerShell_Profile.ps1" -Value $PSSharedTemplate -Force

# Track down the 'Documents' folder location via the registry as it might have moved to somewhere like OneDrive
$SIDs = (Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList').Name.Replace('HKEY_LOCAL_MACHINE','HKLM:')
$SID = (ForEach-Object -InputObject $SIDs {(Get-ItemProperty $_ | Where-Object {$_.ProfileImagePath -like "*\$UserAccount"})})

New-PSDrive HKU Registry HKEY_USERS
reg.exe load "HKU\$UserAccount" "$($SID.ProfileImagePath)\NTUSER.DAT"

$ShellFolders = ('HKU:\' + $UserAccount + '\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders')
$UserDocuments = (Get-ItemPropertyValue $ShellFolders -Name 'Personal')

reg.exe unload "HKU\$UserAccount"
Remove-PSDrive HKU

$AdminDocuments = (Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' -Name 'Personal')

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

Write-Host "`nFinished copying common profile files."

if (!((Read-Host -Prompt "`nSetup stored credentials function now? (Y/n)") -eq 'N')) {

    function Set-SecurityProtocols() {
        Write-Host -ForegroundColor 'White' "`nSecurity protocol issue, updating settings."
        Write-Host "Original setting: $([System.Net.ServicePointManager]::SecurityProtocol)" 
        $AvailableProtocols = [string]::join(', ', [Enum]::GetNames([System.Net.SecurityProtocolType])) 
        Write-Host "Available: $AvailableProtocols"

        # Use whatever protocols are available that the server supports 
        try { 
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType] $AvailableProtocols
        } catch { 
            [System.Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12" 
        } 
    } 

    Set-Location $ProfilePath
    $StoredFunctionURL = 'https://github.com/cunninghamp/PowerShell-Stored-Credentials/archive/v1.0.0.zip'
    $ZipFile = 'PowerShell-Stored-Credentials-1.0.0.zip'
    $WebClient = New-Object System.Net.WebClient
    $WebClient.Proxy.Credentials = ([System.Net.CredentialCache]::DefaultNetworkCredentials)

    try {
        $WebClient.DownloadFile($StoredFunctionURL,"$ProfilePath\$ZipFile")
        Write-Host -ForegroundColor 'Green' "`nFile downloaded with default network settings.`n"
    } catch {
        # Try again with different protocols...
        try {
            Set-SecurityProtocols
            $WebClient.DownloadFile($StoredFunctionURL,"$ProfilePath\$ZipFile")
            Write-Host -ForegroundColor 'Green' "`nFile downloaded with updated network settings.`n"   
        } catch {
            Write-Error -Message `
            "`nUnable to download `'$ZipFile`' from GitHub. Download the file to your profile path and re-run this script."
        }
    }

    if (Test-Path -Path "$ProfilePath\$ZipFile" -PathType Leaf) {
        Write-Host "Unpacking zip archive."
        Expand-Archive -Path $ZipFile
        Start-Sleep 1
        Copy-Item `
            ".\PowerShell-Stored-Credentials-1.0.0\PowerShell-Stored-Credentials-1.0.0\Functions-PSStoredCredentials.ps1" `
            -Destination $ProfilePath
        Start-Sleep 1
        Remove-Item -Recurse -Path '.\PowerShell-Stored-Credentials-1.0.0' -Confirm:$false -Force
        Remove-Item -Path $ZipFile -Confirm:$false -Force
    } else {
        Write-Warning `
            "`nUnable to expand archive - you can download the file manually and extract .ps1 file to $ProfilePath`n"
    }

    Write-Host -ForegroundColor 'White' `
        "`nPrompting for credentials to save - make sure the username is: `'$AdminUPN`'"
    Start-Sleep 1
    $Credential = Get-Credential -Message "Enter your Domain Admin account password" -UserName $AdminUPN
    $KeyPath = $AdminDocuments + '\PowerShell'
    $Credential.Password | ConvertFrom-SecureString | Out-File "$($KeyPath)\$($Credential.Username).cred" -Force
}

$PSTemplate = [Uri]'https://github.com/DTMaguire/PowerShell/tree/master/Profile'
Write-Host -ForegroundColor 'Green' `
    "`nInitial profile setup complete! See: $PSTemplate for example scripts to add to your own profile."
