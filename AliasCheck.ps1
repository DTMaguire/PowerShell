# PowerShell script to compare user Alias/UPN/Email addresses from the directory and write to CSV
# Generally you want all of the attributes to match to avoid confusion for users
#
# Version 1.0 - Copyright DM Tech 2019

#Requires -Modules ActiveDirectory

Write-Host -ForegroundColor 'Cyan' "`nBuilding a list of accounts, please wait a moment...`n"
$UserList = (Get-ADUser -Filter 'Enabled -eq $True' | Select-Object -ExpandProperty SamAccountName | Get-RemoteMailbox -Filter * -Erroraction 'SilentlyContinue' | Select-Object Name,SamAccountName,Alias,UserPrincipalName,PrimarySMTPAddress)
$MismatchedUsers = @()
$OutCSV = "D:\Scripts\Output\MismatchedEnabledAliases.csv"

foreach ($User in $UserList) {
    $AliasCheck = $User.UserPrincipalName -replace '(@[A-Za-z.]+)',''
    $SMTPCheck = $User.PrimarySMTPAddress -replace '(@[A-Za-z.]+)',''
    if ($User.Alias -ne $AliasCheck -or $User.Alias -ne $SMTPCheck) {
        $MismatchedUsers += $User
        Write-Host -ForegroundColor 'Magenta' "`nAlias/UPN/SMTP mismatch for: $($User.Alias) - $AliasCheck - $SMTPCheck `n"
        Start-Sleep 2
    } else {
        Write-Host -ForegroundColor 'Green' "Alias/UPN/SMTP matches for: $($User.Alias) - $AliasCheck - $SMTPCheck"
        Start-Sleep -Milliseconds 20
    }
}

Write-Host -ForegroundColor 'Cyan' "`n`nList of enabled accounts with mismatches:"
Start-Sleep 1
Write-Output $MismatchedUsers
Write-Host -ForegroundColor 'Cyan' "`nAccounts with mismatches:" $MismatchedUsers.Count
Write-Host -ForegroundColor 'Cyan' "`nTotal accounts checked:" $UserList.Count
Write-Host -ForegroundColor 'White' "`nWriting to file:" $OutCSV
$MismatchedUsers | Export-Csv -NoTypeInformation -Path $OutCSV