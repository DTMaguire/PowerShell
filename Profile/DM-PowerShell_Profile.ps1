# Profile script called by Microsoft.PowerShell_profile.ps1
Set-Location -Path 'D:\Scripts\PowerShell'

# Shell variables
$Shell = $Host.UI.RawUI
#$Shell.WindowTitle=""
$KeyPath = "$Home\Documents\WindowsPowerShell"

# Run the following sript to enable the Get-StoredCredential cmdlet from the KeyPath
. ".\Profile\Functions-PSStoredCredentials.ps1"

$BSize = $Shell.BufferSize
$BSize.Width=120
$BSize.Height=3000
$Shell.BufferSize = $BSize

$WSize = $Shell.WindowSize
$WSize.Width=120
$WSize.Height=40
$Shell.WindowSize = $WSize

# Proxy settings to allow access to PowerShell Gallery
$WebClient = New-Object System.Net.WebClient
$WebClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

# Show a custom message
Write-Host -ForegroundColor 'White' "Running as $env:Username with profile path: $KeyPath `n"

# Change the Shell Color
#$shell.BackgroundColor = “Gray”
#$shell.ForegroundColor = “Black”

#To start with a clean Shell
# Clear-Host