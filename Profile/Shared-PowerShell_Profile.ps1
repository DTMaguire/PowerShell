# Common profile script to be called by the default Microsoft.PowerShell_profile.ps1
# Copyright DM Tech 2020
#
# Prerequisites:
#   A system or user environment variable $Env:DevPath with the path to your scripts directory
#   A session variable $AdminUPN for the relevant domain/cloud service account
#
#### This file should be generated by the SetupPSProfile script and exists here as an example only ####

# Add the Modules folder in the $Env:DevPath to the PSModulePath for easy access to custom modules 
$Env:PSModulePath += (';' + "$Env:DevPath" + '\Modules')

# Some useful session variables
$Identity = ''

# Script input and output directories
$PSProfile = Join-Path $Env:DevPath -ChildPath 'Profile'
$PSInput = (Split-Path $Env:DevPath -Parent | Join-Path -ChildPath 'Input')
$PSOutput = (Split-Path $Env:DevPath -Parent | Join-Path -ChildPath 'Output')

# These can be used for matching a MAC or extracting it from a string like so:
# (arp -a | sls '10.0.0.40') -replace $RegexMACReplace,'$1'
$RegexMAC = '([\da-fA-F]{2}[\.:-]?){5}[\da-fA-F]{2}'
$RegexMACReplace = '^.*(' + $RegexMAC + ').*$'

# Shutup VSCode, I know the variables are unused!
$Identity + $RegexMACReplace + $PSInput + $PSOutput | Out-Null

#### Fancy stored credentials bit ####

# Set the $KeyPath variable to somewhere sensible as required by Functions-PSStoredCredentials.ps1 (per user)
$KeyPath = (Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name 'Personal') + '\PowerShell'

<#
    This checks if the $Env:AdminUPN environment variable exists for specifying an admin username for authentication
    If so, dot-source 'Functions-PSStoredCredentials.ps1' and load the .cred file into a PowerShell credential object
    For more info, see: 
    https://practical365.com/blog/saving-credentials-for-office-365-powershell-scripts-and-scheduled-tasks/
#>

# Test to see if admin credentials exist
if (Test-Path "${KeyPath}\${env:AdminUPN}.cred") {

    # Dot source the function to enable the Get-StoredCredential function from $KeyPath
    . $PSProfile\Functions-PSStoredCredentials.ps1

    # Get-StoredCredential uses the .cred file in $KeyPath generated by New-StoredCredential
    $AdminCredential = (Get-StoredCredential -UserName $Env:AdminUPN)
}

#### End fancy stored credentials ####

# Dot-source a libraries of common functions, including an overloaded Select-Object function
. $PSProfile\PSProfile_GeneralFunctions.ps1
. $PSProfile\PSProfile_NetworkFunctions.ps1

# Not all of the O365 module work with PSCore/7.0
if ($PSVersionTable.PSVersion.Major -lt 6) {
    . $PSProfile\PSProfile_O365Functions.ps1
}

# Proxy settings to allow access to web/remote stuff like Office 365 and the PowerShell Gallery (if required on your network)
#$WebClient = New-Object System.Net.WebClient
#$WebClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

# Assume Windows 10 and add the Chocolately profile
$ChocolateyProfile = "$Env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# Set the path and display a message
SetDevPath
Write-Host -ForegroundColor 'White' `
"Running as $Env:Username with profile path: $KeyPath `nDomain admin credentials loaded:" $([bool]$AdminCredential)"`n"
