# PowerShell script to export a list of groups and their members that match a given filter
# Version 1.0 - Copyright DM Tech 2019
#
# This script will generate three outputs:
#   - A CSV file containing all matching groups and their attributes
#   - A TXT file for each of the groups containing the names of all group members
#   - A TXT file with a list of empty groups
#
# It has the potential to generate hundreds of text files so run it from somewhere appropriate 

#Requires -Modules ActiveDirectory

# Filter groups with names starting with "ROLE" - change as required
$Filter = "ADMIN"

$Groups = Get-ADGroup -LDAPFilter "(Name=*$Filter*)" # -Properties CanonicalName

ForEach ($Group in $Groups) {

    # Generate a sane file name for the current group
    $ExportName = $Group.SamAccountName

    # Select some useful attributes to capture
    $GroupAttributes = $Group | Select-Object Name,SamAccountName,CanonicalName,GroupCategory,GroupScope

    # Collect a list of members of the current group
    $GroupMembers = Get-ADGroupMember -Identity $Group | Select-Object Name

    # Check if group is empty and if so, write its name to a text file and jump to the next group
    If (! $GroupMembers) {

        Write-Host -ForegroundColor Gray "Skipping creation of file for empty group `'$ExportName`'"

        #$ExportName | Out-File -Append "$Filter - Empty Groups.txt"
    }

    Else {

        # Group does contain members, so append group name to CSV and then output the list of members to a seperate text file
        Write-Host -ForegroundColor Green "Writing group `'$ExportName`' to `'"$Filter" - All Groups.csv`' and members to `'$ExportName - Members.txt`'"
        Write-Output $GroupAttributes
        #Export-Csv -InputObject $GroupAttributes -NoTypeInformation -Append -Path "$Filter - All Groups.csv"

        #$GroupMembers | Out-File "$ExportName - Members.txt"
    }
} 