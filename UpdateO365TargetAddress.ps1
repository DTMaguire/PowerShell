# PowerShell script to update missing Exchange attributes for users with remote mailboxes
# It fixes issues with on-prem to O365 mail routing
# Run in the on-premise Exchange Management Shell for the time being...
#
# Version 2.0 - Copyright DM Tech 2019

#Requires -Modules ActiveDirectory
$ExchFQDN = [System.Net.Dns]::GetHostByName('sydawsexchange').HostName
$ExchSessionCreated = $false

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

if (Get-PSSession | Where-Object {$_.ComputerName -eq $ExchFQDN -and $_.State -eq "Opened"}) {
    Write-Host -ForegroundColor 'White' "`nDetected active on-premise Exchange session..."
} else {
    Write-Host -ForegroundColor 'White' "`nOn-premise Exchange session starting..."
    Import-PSSession (New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri `
        "http://$ExchFQDN/powershell/") -AllowClobber -CommandName "*RemoteMailbox" | Out-Null
    $ExchSessionCreated = $true
}

Write-Host -ForegroundColor 'Cyan' "`nBuilding a list of accounts, please wait a moment...`n"
$UserList = (Get-ADUser -Filter `
    {Name -notlike "Health*" -and Name -notlike "System*" -and Name -notlike "Federated*" -and
     Name -notlike "Migration*" -and Name -notlike "admin*" -and Name -notlike "comms*"} `
    -Properties * | Where-Object { $null -ne $_.Surname -and $null -ne $_.ProxyAddresses -and 
    $null -ne $_.msExchRecipientTypeDetails -and $null -ne $_.msExchRemoteRecipientType -and 
    $_.targetAddress -notlike "*$($TargetDomain)" } | `
     Select-Object Name,SamAccountName,UserPrincipalName,ProxyAddresses,TargetAddress)

Write-Host -ForegroundColor 'White' "`nFound the following users:`n"
Write-Output $UserList
Write-Host -ForegroundColor 'White' "`nTotal users:" ($UserList | Measure-Object).Count

foreach ($User in $UserList) {

    #$UserAccount = (Get-ADUser -Filter {UserPrincipalName -eq $UPN} -Properties * | `
        #Select-Object Name,SamAccountName,UserPrincipalName,ProxyAddresses,TargetAddress)
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
    #Set-ADUser -Identity $UserSAM -Replace @{ msExchRecipientDisplayType="-2147483642";msExchRecipientTypeDetails="2147483648";`
        #msExchRemoteRecipientType="4";targetAddress="$Target" }

    if ($null -eq $User.targetAddress) {
        Enable-RemoteMailbox $UPN -RemoteRoutingAddress $Target -WhatIf
    } else {
        Set-RemoteMailbox $UPN -RemoteRoutingAddress $Target -EmailAddressPolicyEnabled $true -WhatIf
    }

    Start-Sleep 1
}

if ($ExchSessionCreated -eq $true) {
    Write-Host -ForegroundColor 'White' "`nClosing on-premise Exchange session..."
    Get-PSSession | Where-Object {$_.ComputerName -eq $ExchFQDN} | Remove-PSSession
}
