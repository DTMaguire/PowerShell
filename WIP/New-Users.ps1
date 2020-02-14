# Script for creation of users in AD based off an existing user
# Version 1.0 - Copyright DM Tech 2020

#Requires -Modules ActiveDirectory

# Variables to set
#$NewUsers = @(Get-Content ((Split-Path $Env:DevPath -Parent) + '\Input\NewUsers.txt')) # Read names from a text file
$NewUsers = @('First Person') # Or enter names as an array here
$CopyUser = 'DMaguire' # SAM account name of the user to copy

# Common variables
$Props = 'City','Company','Country','Department','Description','HomeDrive','Manager','Office','PostalCode','State','StreetAddress','Title'

$CopyObject = (Get-ADUser -Identity $CopyUser -Properties $Props)
$CopyGroups = (Get-ADUser -Identity $CopyUser -Properties MemberOf | Select-Object -ExpandProperty MemberOf)

# This places the new users in the same OU as the copied one, without it the account is created in the default Users OU
#$OU = ($CopyObject.DistinguishedName.Split(',',2)[1])
# 'January2020' (MonthYear)
$Password = (ConvertTo-SecureString -AsPlainText ((Get-Date).ToString("MMMMyyyy")) -Force) 
# SAM account name is appended for the H: drive folder so leave the trailing slash
$UserShare = '\\nas-qs-trs\users\'

$UserInstance = New-Object Microsoft.ActiveDirectory.Management.ADUser

foreach ($Prop in $Props) {
    if ($null -ne ${CopyObject}.$Prop) {
        ${Script:UserInstance}.$Prop = ${CopyObject}.$Prop
    } else {
        Write-Host -ForegroundColor 'White' "No value set for $Prop on $CopyUser"
    }
}

Write-Host -ForegroundColor 'White' "`nCommon parameters:"
Format-List -InputObject $UserInstance

foreach ($User in $NewUsers) {

    $UserSAM = ($User.Substring(0,1) + ($User.Split(' ')[-1])).ToLower()

    $NewUserProps = [ordered]@{
        Name = $User
        DisplayName = $User
        SamAccountName = $UserSAM
        GivenName = ${User}.Split(' ')[0]
        SurName = ${User}.Split(' ')[-1]
        UserPrincipalName = (${User}.Replace(' ','.') + '@' + $Env:UPNSuffix).ToLower()
        HomeDirectory = ($UserShare + $UserSAM)
    }

    Write-Host -ForegroundColor 'White' "`nSetting up user with details:`n"
    
    Format-Table -InputObject $NewUserProps
    
    #foreach($Key in $NewUserProps.Keys)
    #{
    #    $Value = $NewUserProps.$Key
    #    Write-Output "$Key `t`t`t $Value"
    #}

    #$NewUserProps | Out-String

    New-ADUser @NewUserProps -Instance $UserInstance <#-Path $OU#> -AccountPassword $Password -Enabled $True -ChangePasswordAtLogon $True -WhatIf
    
    Write-Host -ForegroundColor 'White' "New mailboxes can be activated with the following command:"
    Write-Host -ForegroundColor 'Cyan' "Enable-RemoteMailbox (${NewUserProps[UserPrincipalName]}) -RemoteRoutingAddress $(${User}.Replace(' ','.') + '@NSWLandRegistryServices.mail.onmicrosoft.com')`n"
    #$RemoteMailbox = "Enable-RemoteMailbox ${NewUserProps}.UserPrincipalName -RemoteRoutingAddress (${User}.Replace(' ','.') + '@NSWLandRegistryServices.mail.onmicrosoft.com')"

    Write-Host -ForegroundColor 'White' "Waiting a few seconds for account object before starting groups...`n"
    Start-Sleep 4
    #$CopyGroups | ForEach-Object {Add-ADGroupMember -Identity $_.SamAccountName -Members $UserSAM -WhatIf}
    Write-Host -ForegroundColor 'Green' "`nUpdated Groups: $($CopyGroups.Count) `n"
    Start-Sleep 1
    
}

Write-Host -ForegroundColor 'Green' "User setup complete, wait a few minutes before running the Enable-RemoteMailbox command for each."
