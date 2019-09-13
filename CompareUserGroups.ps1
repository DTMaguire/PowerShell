# PowerShell script to export a collection of common groups for a list of users and generate a count for each
# Version 1.0 - Copyright DM Tech 2019

#Requires -Modules ActiveDirectory

$AccountsArray = @()
$GroupsArray = @()

$AWSUsers = Get-Content -Path "D:\Scripts\Output\AWS-OldUsers.txt"

Write-Host -ForegroundColor 'White' "`nImporting the following users:`n"
Write-Output $AWSUsers
Write-Host -ForegroundColor 'Green' "`n`nTotal users: " $AWSUsers.Count "`n"

foreach ($User in $AWSUsers) {
    $UserAcc = (Get-ADUser -LDAPFilter "(displayName=*$User*)" -Properties Name,SamAccountName,UserPrincipalName,Memberof)

    foreach ($Acc in $UserAcc) {
        $AccountsArray += $Acc
        $Groups = ($Acc | Select-Object -ExpandProperty Memberof | Get-ADGroup) # -Properties Members | Select-Object -Property SamAccountName,Members)
        foreach ($Group in $Groups) {
            $GroupsArray += $Group
        }
    }

}

Write-Host -ForegroundColor 'White' "`nAccount name matches found:"
$AccountsArray | Format-Table -Property Name,SamAccountName
Write-Host -ForegroundColor 'Green' "Total accounts matched: " $AccountsArray.Count "`n`n"

Write-Host -ForegroundColor 'Cyan' $GroupsArray.Count "groups in common - listing in order of occurrence (prepare to scroll...):`n"
Start-Sleep 2
$Output = ($GroupsArray.SamAccountName | Group-Object | Sort-Object -Descending -Property Count | Select-Object -Property Count,Name)
Write-Output $Output
$Output | Export-Csv -NoTypeInformation -Path "D:\Scripts\Output\AWS-Groups.csv"
Invoke-Item "D:\Scripts\Output\AWS-Groups.csv"

# Idea - expand to create a custom object instead of an array of Groups?
# User account names could then be created as table entries with a 'Y' against any group they belong to, otherwise 'N'