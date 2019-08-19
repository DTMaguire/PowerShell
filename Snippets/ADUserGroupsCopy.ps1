# Simple script to copy group membership from one user to another
Import-Module ActiveDirectory

$Source = Read-Host "Enter user UPN to copy groups from: "
$Destination = Read-host "Enter user UPN to copy groups to: "

Get-ADuser -Identity $Source -Properties MemberOf | Select-Object -ExpandProperty MemberOf | Add-ADGroupMember -WhatIf -Members $Destination

# One-liner:
Get-ADUser -Identity User1 -Properties MemberOf | Select-Object -ExpandProperty MemberOf | Add-ADGroupMember -Members User2


# Copied, not tested:
#$UserGroups =@()
#$UserGroups = (Get-ADUser -Identity $samaccount_to_copy -Properties MemberOf).MemberOf
#ForEach ($Group in $UserGroups) {
#    Add-ADGroupMember -Identity $Group -Members $TargetUser
#}
#(Get-ADUser -Identity $TargetUser -Properties MemberOf).MemberOf
