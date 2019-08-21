# PowerShell script to update the proxyAddresses attribute in AD.
# Useful in AD/Office 365 DirSync environments without the Exchange tools installed.
#
# This script needs a CSV file of the SamAccountNames of users to be updated. These can be obtained with something like:
#   Import-Module ActiveDirectory
#   Get-ADUser -Filter * (or some relevant filter) | Export-Csv -NoTypeInformation (filename.csv)
# Be sure to upate -Path on line 15 to the path of (filename.csv) and the domain on line 16.
#
# PowerShell *requires* that the CSV file contains the header information so keep that in mind when messing about in Excel!
#
# Written by DTM - 20/09/18

Import-Module ActiveDirectory

$users = Import-Csv -Path D:\Scripts\Output\AD_Active_SANs.csv
$domain = "@domaingoeshere.com.au"

Foreach ($u in $users) {

  $user = Get-ADUser -Identity $u.SamAccountName
  $first = $user.GivenName
  $last = $user.Surname
  $firstl = ($first + $last.Substring(0,1)).ToLower()

  Set-ADUser -Identity $user -Add @{proxyAddresses = "smtp:" + $firstl + $domain}

  Write-Host "Updating user " -ForegroundColor White -NoNewLine
  Write-Host $first $last -ForegroundColor Green -NoNewLine
  Write-Host " with proxyAddresses attribute: " -ForegroundColor White -NoNewLine
  Write-Host "smtp:$($firstl + $domain)" -ForegroundColor Cyan
}
