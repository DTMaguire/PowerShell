# Script to pull the Exchange attributes from AD users and decode them via hash tables.
# Useful to compare account properties in an AD Sync/Office 365 configuration 
# where on-prem AD objects don't reflect the mailbox status in Office 365
# (ie - Exchange hybrid mode is disabled but still have on-prem Exchange).
#
# Copyright DM Tech 2019

$RemoteRecipientType = @{
    1 = 'ProvisionMailbox'
    2 = 'ProvisionArchive (On-Prem Mailbox)'
    3 = 'ProvisionMailbox, ProvisionArchive'
    4 = 'Migrated (UserMailbox)'
    6 = 'ProvisionArchive, Migrated'
    8 = 'DeprovisionMailbox'
    10 = 'ProvisionArchive, DeprovisionMailbox'
    16 = 'DeprovisionArchive (On-Prem Mailbox)'
    17 = 'ProvisionMailbox, DeprovisionArchive'
    20 = 'Migrated, DeprovisionArchive'
    24 = 'DeprovisionMailbox, DeprovisionArchive'
    33 = 'ProvisionMailbox, RoomMailbox'
    35 = 'ProvisionMailbox, ProvisionArchive, RoomMailbox'
    36 = 'Migrated, RoomMailbox'
    38 = 'ProvisionArchive, Migrated, RoomMailbox'
    49 = 'ProvisionMailbox, DeprovisionArchive, RoomMailbox'
    52 = 'Migrated, DeprovisionArchive, RoomMailbox'
    65 = 'ProvisionMailbox, EquipmentMailbox'
    67 = 'ProvisionMailbox, ProvisionArchive, EquipmentMailbox'
    68 = 'Migrated, EquipmentMailbox'
    70 = 'ProvisionArchive, Migrated, EquipmentMailbox'
    81 = 'ProvisionMailbox, DeprovisionArchive, EquipmentMailbox'
    84 = 'Migrated, DeprovisionArchive, EquipmentMailbox'
    97 = 'ProvisionMailbox, SharedMailbox'
    100 = 'Migrated, SharedMailbox'
    102 = 'ProvisionArchive, Migrated, SharedMailbox'
    116 = 'Migrated, DeprovisionArchive, SharedMailbox'
}

$RecipientTypeDetails = @{
    1 = 'UserMailbox'
    2 = 'LinkedMailbox'
    4 = 'SharedMailbox'
    16 = 'RoomMailbox'
    32 = 'EquipmentMailbox'
    128 = 'MailUser'
    2147483648 = 'RemoteUserMailbox'
    8589934592 = 'RemoteRoomMailbox'
    17179869184 = 'RemoteEquipmentMailbox'
    34359738368 = 'RemoteSharedMailbox'
}

Get-ADUser -Filter * -Properties * | `
    Where-Object {$_.msExchRemoteRecipientType -ne $null -or $_.msExchRecipientTypeDetails -ne $null} | `
    Select-Object Name, UserPrincipalName, Created, msExchRemoteRecipientType, msExchRecipientTypeDetails, `
    @{n='RemoteRecipientType';e={$RemoteRecipientType[[int]$_.msExchRemoteRecipientType]}}, `
    @{n='RecipientTypeDetails';e={$RecipientTypeDetails[$_.msExchRecipientTypeDetails]}} | `
    Export-Csv -NoTypeInformation ..\Output\msExchRecipientAttributes.csv
    #Invoke-Item ..\Output\msExchRecipientAttributes.csv
