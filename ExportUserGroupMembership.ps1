# PowerShell script to export a list of groups for a specified user
# Version 3.0 - Copyright DM Tech 2019
#
# This script prompts for an AD account name to generate a list of groups that the specified user belongs to
# It then both writes a list of groups sorted by name to the screen and a CSV file

#Requires -Modules ActiveDirectory

Write-Host -ForegroundColor 'Cyan' "`nPowerShell script to export a list of groups that a specified user belongs to`n"

# Global variables 
$Quit = $False
$Timestamp = Get-Date -Format yyyyMMdd
$OutputDir = "..\Output"

function AccountLookup {
    param ( $InputStr )
    
    # Try to perform a look up, but filter invalid input with a regular expression that allows for a maximum of 2 non-consecutive wildcards or spaces
    if ($InputStr -match '\*?[-\w]+\s?\*?') { 

        try {       # Test if input exactly matches a user identity (SamAccountName)
            $UsrObject = (Get-ADUser -Identity $InputStr | Select-Object GivenName, SurName, SamAccountName)
        }
        catch {     # Otherwise, fall back to an LDAPFilter query which allows wildcard searches
            $UsrObject = (Get-ADUser -LDAPFilter "(|(SamAccountName=$InputStr)(GivenName=$InputStr)(SN=$InputStr))" | Select-Object GivenName, SurName, SamAccountName)
        }

    } else {        # Otherwise, just return nothing instead of generating an error
        
        return
    }
    
    return $UsrObject
}

function GetGroups {
    param ( $UsrObject )

    # Generate a list of groups for a single matched user account
    $Groups = (Get-ADPrincipalGroupMembership -Identity $UsrObject.SamAccountName | Get-ADGroup -Properties * | Sort-Object | Select-Object -Property Name, GroupCategory, Description)

    return $Groups
}

if ( !(Test-Path $OutputDir) ) {

    Write-Host -ForegroundColor 'Magenta' "`nPath to `'$OutputDir`' does not exist, creating it under:"

    # Create output folder if it doesn't exist
    New-Item -ItemType Directory -Force -Path $OutputDir
}

# Continue prompting for account names until 'q' is entered
do {

    # Get input for name lookup
    Write-Host -ForegroundColor 'White' "Input name to search for user account (wildcards supported), or 'q' to quit`n`n> " -NoNewline
    $InputStr = Read-Host

    # Check if 'q' has been entered
    if ( $InputStr -eq "q" ) {

        Write-Host -ForegroundColor 'White' "`nQuitting...`n"
        $Quit = $True

    } elseif ( $InputStr.length -lt 2 ) {

        Write-Host -ForegroundColor 'Magenta' "`nPlease Enter 2 or more characters!`n"

    } else {
        
        # Attempt to resolve the input to a user object in the directory
        $UsrObject = AccountLookup $InputStr
        $ObjCount = ($UsrObject | Measure-Object).Count

        # Check if more than one object is returned by the lookup
        if ( $ObjCount -gt 1 ) {

            Write-Host -ForegroundColor 'Magenta' "`n`n$ObjCount matches found, please narrow search to one of the following accounts:"
        
            # Output the list of matched user accounts
            $UsrObject | Format-Table -AutoSize | Write-Output
    
        } elseif ( $ObjCount -eq 1 ) {
            
            # Get the group memberships for a single user object
            $Groups = GetGroups $UsrObject

            # Generate a relevant filename
            $FilePath = Join-Path -Path $OutputDir -ChildPath "GroupMembership_$($UsrObject.SamAccountName)-$Timestamp.csv"

            # Output user details to the screen
            Write-Host -ForegroundColor 'Green' "`n`nResolved account name to user:"
            Write-Output $UsrObject | Format-Table

            # Output group details to the screen
            Write-Host -ForegroundColor 'Green' "Writing groups to `'$FilePath`':"
            Write-Output $Groups | Select-Object Name, GroupCategory | Format-Table
        
            # Write the groups to a CSV file
            $Groups | Export-Csv -NoTypeInformation -Path $FilePath

        } else {

            # If nothing matches, print an error and jump back up to the 'Do' loop
            Write-Host -ForegroundColor 'Magenta' "`nUnable to find account name matching input: `'$InputStr`'`n"
            continue
        }
    }

} until ($Quit)