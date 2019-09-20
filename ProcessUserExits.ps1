# PowerShell script to export groups for a list of old users, remove them from the groups and disable their accounts
# Version 1.0 - Copyright DM Tech 2019

#Requires -Modules ActiveDirectory

$AccountsArray = @()

$OutputDir = "D:\Scripts\Output\UserExits"

$OldUsers = (Import-Csv -Path "D:\Scripts\Output\SR-1093.csv")

$DispNames = (($OldUsers.DisplayName).Trim() | Sort-Object)

Write-Host -ForegroundColor 'White' "`nImporting the following users:`n"
Write-Output $DispNames
Write-Host -ForegroundColor 'Green' "`n`nTotal users: " $DispNames.Count "`n"

foreach ($Name in $DispNames) {
    $UserAcc = (Get-ADUser -Filter {Name -eq $Name} -Properties * | Select-Object Name, SamAccountName, UserPrincipalName, Memberof, Enabled)

    foreach ($Acc in $UserAcc) {
        $AccountsArray += $Acc
    }
}

Write-Host -ForegroundColor 'White' "`nAccount name matches found:"
$AccountsArray | Format-Table -Property Name, SamAccountName, Enabled

Write-Host -ForegroundColor 'Green' "Total accounts matched: " $AccountsArray.Count "`n`n"

foreach ($Account in $AccountsArray) {

    Write-Host -ForegroundColor 'Cyan' "`nUser: $($Account.Name)"
    Write-Host -ForegroundColor 'White' "`nGroup membership:`n"
    $Groups = ($Account | Select-Object -ExpandProperty Memberof | Get-ADGroup | Sort-Object | Select-Object -ExpandProperty SamAccountName)
    
    Start-Sleep -Milliseconds 250

    if ($null -eq $Groups) {
        Write-Host -ForegroundColor 'Magenta' "No group memberships found.`n"
    } else {
        $Groups | Out-String
        Write-Host -ForegroundColor 'White' "Removing from groups...`n"
        foreach ($Group in $Groups) {
            Remove-ADGroupMember -Identity $Group -Member $Account.SamAccountName -Confirm:$false #-WhatIf
        }
    }

    Start-Sleep -Milliseconds 250
    Write-Host -ForegroundColor 'White' "Disabling account...`n"
    Disable-ADAccount -Identity $Account.SamAccountName -Confirm:$false #-WhatIf

    Start-Sleep -Milliseconds 250
    $FilePath = Join-Path -Path $OutputDir -ChildPath "UserExit_$($Account.SamAccountName)_Groups.txt"
    Write-Host -ForegroundColor 'Green' "Saving to: $FilePath`n"
    
    Start-Sleep -Milliseconds 250
    $Groups | Out-File $FilePath -Force
}
