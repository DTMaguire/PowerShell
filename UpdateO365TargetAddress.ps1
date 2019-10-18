# PowerShell script to update missing Exchange attributes for a list of exported users
# Run in the on-premise Exchange Management Shell for the time being...
#
# Version 2.0 - Copyright DM Tech 2019

#Requires -Modules ActiveDirectory

do {
    $PrimaryDomain = (Read-Host -Prompt "`nEnter primary email domain").ToLower()
    $TargetDomain = Read-Host -Prompt "Enter remote routing domain (usually ends with `"mail.onmicrosoft.com`")"
    Write-Host -ForegroundColor 'White' "`nPrimary domain:" $PrimaryDomain
    Write-Host -ForegroundColor 'White' "Target domain:" $TargetDomain
    $Check = Read-Host -Prompt "`nIs this correct? Y to confirm, Q to quit or anything else to re-enter"
    if ($Check -eq 'q') {
        exit
    }
} until ($Check -eq 'y')

Write-Host -ForegroundColor 'Cyan' "`nBuilding a list of accounts, please wait a moment...`n"
$UserList = (Get-ADUser -Filter 'Enabled -eq $True' -Properties * | Where-Object {$_.Surname -ne $null -and $_.ProxyAddresses -ne $null -and ($_.TargetAddress -eq $null -or $_.targetAddress -like "*$($PrimaryDomain)")} | Select-Object Name,SamAccountName,UserPrincipalName,ProxyAddresses,TargetAddress)

Write-Host -ForegroundColor 'White' "`nFound the following users:`n"
Write-Output $UserList
Write-Host -ForegroundColor 'White' "`nTotal users:" ($UserList | Measure-Object).Count

foreach ($User in $UserList) {

    #$UserAccount = (Get-ADUser -Filter {UserPrincipalName -eq $UPN} -Properties * | Select-Object Name,SamAccountName,UserPrincipalName,ProxyAddresses,TargetAddress)
    Write-Host -ForegroundColor 'White' "`nUsername:" $User.Name
    $UserSAM = $User.SamAccountName
    Write-Host -ForegroundColor 'White' "User SAM:" $UserSAM
    $UPN = $User.UserPrincipalName
    Write-Host -ForegroundColor 'White' "User Principal Name:" $UPN
    Write-Host -ForegroundColor 'White' "Proxy addresses:" 
    Write-Output $User.ProxyAddresses
    $Target = $UPN -replace $PrimaryDomain,$TargetDomain
    Write-Host -ForegroundColor 'Cyan' "`nSetting target address:" $Target
    #$Alias = $UPN -replace '(@[A-Za-z.]+)',''
    #Set-ADUser -Identity $UserSAM -Replace @{ msExchRecipientDisplayType="-2147483642";msExchRecipientTypeDetails="2147483648";msExchRemoteRecipientType="4";targetAddress="$Target" }

    if ($null -eq $User.targetAddress) {
        Enable-RemoteMailbox $UPN -RemoteRoutingAddress $Target -Whatif
    } else {
        Set-RemoteMailbox $UPN -RemoteRoutingAddress $Target -EmailAddressPolicyEnabled $true -Whatif
    }

    Start-Sleep 1
}