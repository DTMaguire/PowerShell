# Small script to read in a list of account names and output a CSV with password and expiry information
# This turned into the UserExpCheck.ps1 script but works by reading in from a text file instead of prompting for input

$ExpAdmins = @(Get-Content -Path D:\Scripts\PowerShell\WIP\ExpADAdmins.txt)

ForEach ($Admin in $ExpAdmins) {
    Get-ADUser -Identity $Admin -Properties * | 
    Select-Object -Property Name,AccountExpirationDate,AccountLockoutTime,BadLogonCount,Enabled,LastBadPasswordAttempt,LastLogonDate,LockedOut,lockoutTime,PasswordExpired,PasswordLastSet,PasswordNeverExpires |
    Export-Csv -NTI -Append D:\Scripts\PowerShell\WIP\ExpAdmins_2019Q2.csv
    }
