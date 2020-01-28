# Script for creation of users in AD based off an existing user
# Version 1.0 - Copyright DM Tech 2020

#Requires -Modules ActiveDirectory

$NewUsers = @('Lindell Galaroza','Matthew Emanuel','Michael Cerna','Nick Craig')

# Common variables
$CopyUser = 'CFunnell'
$Password = (Get-Date).ToString("MMMMyyyy") # Formatted as 'January2020' (MonthYear)
$HomeDrive = 'H:'
$UserShare = '\\nas-qs-trs\users\'
$Props = 'City','Company','Country','Department','Description','Manager','Office','PostalCode','State','StreetAddress','Title'

$CopyObject = (Get-ADUser -Identity $CopyUser -Properties $Props)
$CopyGroups = (Get-ADUser -Identity $CopyUser -Properties MemberOf | Select-Object -ExpandProperty MemberOf | Get-ADGroup)

foreach ($User in $NewUsers) {
    
    $UserInstance = New-Object Microsoft.ActiveDirectory.Management.ADUser
    
    $UserInstance.DisplayName = $User
    $UserInstance.Name = $User
    # Split the string into an array of 2 elements at the first ',' then select the element at array index [1]
    #$UserInstance.DistinguishedName = ("CN=$User/" + ($CopyObject.DistinguishedName.Split(',',2)[1])) # Taking a punt here... 

    $UserInstance.SamAccountName = (($User.Substring(0,1) + ($User.Split(' ')[-1])).ToLower())
    $UserInstance.Given = ($User.Split(' ')[0])
    $UserInstance.SurName = ($User.Split(' ')[-1])
    $UserInstance.UserPrincipalName = (($User.Replace(' ','.') + '@' + $Env:UPNSuffix).ToLower())
    $UserInstance.HomeDir = ($UserShare + $SAM)


        
    foreach ($Prop in $Props) {
        if ($null -ne $Prop) {
            ($Script:UserInstance).$Prop = ($CopyObject).$Prop
        }
    }

    Write-Host -ForegroundColor 'White' "`nSetting up user with details:`n"

    Write-Host "OU:`t`t$OU`nSAM:`t`t$SAM`nGiven:`t`t$Given`nSurName:`t$SurName`nUPN:`t`t$UPN`nHomeDir:`t$HomeDir`n"
    
    <# To create new users
    New-ADUser -AccountPassword (ConvertTo-SecureString -AsPlainText $Password -Force) -ChangePasswordAtLogon $True `
        -DisplayName $User -Enabled $True -GivenName $Given -HomeDirectory $HomeDir -HomeDrive $HomeDrive `
        -Instance $Instance -Path $OU -SamAccountName $SAM -SurName $SurName -UserPrincipalName $UPN -WhatIf
    #>

    New-ADUser -SAMAccountName $SAM -Instance $userInstance -Path ($CopyObject.DistinguishedName.Split(',',2)[1])

    # To update existing users
    $ReplaceHashTable = @{
        DisplayName = $User
        HomeDirectory = $HomeDir
        HomeDrive = $HomeDrive
        UserPrincipalName = $UPN
    }

    $UpdateObject = (Get-ADUser -Identity $SAM -Properties $Props)

    foreach ($Prop in $Props) {
        ($Script:UpdateObject).$Prop = ($CopyObject).$Prop
    }

    Write-Host -ForegroundColor 'White' "Updated Object Properties:`n"
    Write-Output $ReplaceHashTable
    Write-Output $UpdateObject
    Start-Sleep 3
    Set-ADUser -Identity $SAM -ChangePasswordAtLogon $True -Replace $ReplaceHashTable -WhatIf
    Start-Sleep 3
    #Set-ADUser -Instance $UpdateObject
    Write-Host -ForegroundColor 'Green' "`nCompleted: $User`n"
    Start-Sleep 1

    <#
    $CopyGroups | ForEach-Object {Add-ADGroupMember -Identity $_ -Members $SAM -Verbose}
    Write-Host -ForegroundColor 'Green' "`nUpdated Groups: $($CopyGroups.Count) `n"
    Start-Sleep 1
    #>
}
