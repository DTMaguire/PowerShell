# PowerShell script to add a list of user Display Names to a group
#
# The Add-ADGroupMember cmdlet will only accept input for '-Members' that is one of the following:
#    Distinguished name
#    GUID (objectGUID)
#    Security identifier (objectSid)
#    SAM account name (sAMAccountName)
#
# This script looks up the SamAccountName for each Display Name and adds it to an array
# Once complete, it runs Add-ADGroupMember and passes in the array as the '-Members' parameter
#
# Version 1.0 - Copyright DM Tech 2019

#Requires -Modules ActiveDirectory
$AccountsArray = @()

# Import a list of user display names from a plain txt file, assuming one name per line
# Ensure no erroneous spaces in input, then sort in alphabetical order
#$DispNames = ((Get-Content -Path "D:\Scripts\Input\DL List.txt").Trim() | Sort-Object)

# A CSV import would look like this - just make sure it's in a valid comma-separated values format!
# Trim spaces again, but this uses .DisplayName to select the correct column in the CSV file
#$DispNames = (((Import-Csv -Path "D:\Scripts\Input\Some.csv").DisplayName).Trim() | Sort-Object)

# If you get nothing assigned to the variable above, your CSV file probably has spaces in the header as well!
# It can be worked around by enclosing the header string in both parentheses and double quotes:
$DispNames = (((Import-Csv -Path 'D:\Scripts\Input\SR-1102_test.csv').("Display Name ")).Trim() | Sort-Object)
# Alternatively, just fix the source file!

# If nothing returned, no point in going any further...
if ($DispNames.Count -lt 1) {
    Write-Error "No display names found - exiting!"
    exit
}

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
    Add-ADGroupMember -Identity $Group -Members $AccountsArray -WhatIf
}
