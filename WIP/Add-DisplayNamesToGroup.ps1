# PowerShell script to add a list of user Display Names to a group
#
# The Add-ADGroupMember cmdlet will only accept -Members of type:
#    Distinguished name
#    GUID (objectGUID)
#    Security identifier (objectSid)
#    SAM account name (sAMAccountName)
#
# This script looks up SamAccountName for each Display Name and adds it to an array
# Once complete, it runs Add-ADGroupMember and passes in the array as the -Members parameter
#
# Version 1.0 - Copyright DM Tech 2019

#Requires -Modules ActiveDirectory
$AccountsArray = @()

# Import a list of user display names from a plain txt file, assuming name on a new line
$UserList = (Get-Content -Path "D:\Scripts\Input\DL List.txt")

# Ensure no erroneous spaces in input, then sort in alphabetical order
$DispNames = (($UserList).Trim() | Sort-Object)

# CSV import would look like this - just make sure it's in a valid comma-separated values format!
#$UserList = (Import-Csv -Path "D:\Scripts\Input\Some.csv")

# Trim spaces again, but this uses .DisplayName to select the correct column in the CSV file
#$DispNames = (($UserList.DisplayName).Trim() | Sort-Object)

$Group = "Customer Facing Staff-1-667818328"

Write-Host -ForegroundColor 'White' "`nImporting the following users:`n"
Write-Output $DispNames
Write-Host -ForegroundColor 'Green' "`n`nTotal users: " $DispNames.Count "`n"

# Run through list of names to look up in AD and get the SamAccountName for each
foreach ($Name in $DispNames) {

    $UserAcc = (Get-ADUser -Filter {Name -like $Name} | Select-Object -ExpandProperty SamAccountName)
    # It's possible more than one SamAccountName is returned as Display Names do not have to be unique in AD
    # This array allows multiple returned accounts to be captured as individual items
    foreach ($Acc in $UserAcc) {
        $AccountsArray += $Acc
    }
}

# Write the details to the screen so we know what was found
Write-Host -ForegroundColor 'White' "`nAccount name matches found:`n"
Write-Output $AccountsArray
Write-Host -ForegroundColor 'Green' "`nTotal accounts matched: " $AccountsArray.Count "`n`n"

if ((Read-Host -Prompt "Add listed users to `'${Group}`'? (y/N)") -eq "y") {
    # This passes in the AccountsArray in so each member gets added in one go - remove -WhatIf when ready!
    Add-ADGroupMember -Identity $Group -Members $AccountsArray -Confirm:$false -WhatIf
}
