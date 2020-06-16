# Connect to Exchange Online, optionally the Security & Compliance Center
# Uses $AdminCredential set in the PowerShell profile via the Get-StoredCredential function
#Requires -Modules ExchangeOnlineManagement

# Connect to Exchange Online using the V2 module
Connect-ExchangeOnline -Credential $AdminCredential -ShowProgress $true

<# 
# Connect to Exchange Online
$ExchSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $AdminCredential -Authentication "Basic" -AllowRedirection
Import-PSSession $ExchSession -DisableNameChecking -AllowClobber
 #>

# Connect to Security & Compliance Center
#$SccSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.compliance.protection.outlook.com/powershell-liveid/ -Credential $AdminCredential -Authentication "Basic" -AllowRedirection
#Import-PSSession $SccSession -Prefix SCC