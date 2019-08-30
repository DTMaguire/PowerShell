# PowerShell script to export a list of account expiry and password attributes for a specified user to CSV
# Version 2.0 - Copyright DM Tech 2019

#Requires -Modules ActiveDirectory

Write-Host -ForegroundColor 'Cyan' "`nPowerShell script to gather account expiry and password attributes for a specified user and export them to CSV`n"

# Global variables 
$Quit = $False
$Timestamp = Get-Date -Format yyyyMMdd
$OutputDir = "..\Output"

function AccountLookup {
    param ( $InputStr )
    
    # Try to perform a look up, but filter invalid input with a regular expression that allows for a maximum of 2 non-consecutive wildcards or spaces
    if ($InputStr -match '\*?[-\w]+\s?\*?') { 

        try {       # Test if input exactly matches a user identity (SamAccountName)
            $UsrObject = (Get-ADUser -Identity $InputStr -Properties * | Select-Object `
            -Property GivenName,SurName,SamAccountName,UserPrincipalName,AccountExpirationDate,AccountLockoutTime,BadLogonCount,`
            Enabled,LastBadPasswordAttempt,LastLogonDate,LockedOut,lockoutTime,PasswordExpired,PasswordLastSet,PasswordNeverExpires)
        }
        catch {     # Otherwise, fall back to an LDAPFilter query which allows wildcard searches
            $UsrObject = (Get-ADUser -LDAPFilter "(|(SamAccountName=$InputStr)(GivenName=$InputStr)(SN=$InputStr))" -Properties * | Select-Object `
            -Property GivenName,SurName,SamAccountName,UserPrincipalName,AccountExpirationDate,AccountLockoutTime,BadLogonCount,`
            Enabled,LastBadPasswordAttempt,LastLogonDate,LockedOut,lockoutTime,PasswordExpired,PasswordLastSet,PasswordNeverExpires)
        }

    } else {        # Otherwise, just return nothing instead of generating an error
        
        return
    }
    
    return $UsrObject
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

            Write-Host -ForegroundColor 'Magenta' "`n$ObjCount matches found, please narrow search to one of the following accounts:"
        
            # Output the list of matched user accounts
            $UsrObject | Select-Object GivenName,SurName,SamAccountName,UserPrincipalName | Format-Table -AutoSize | Write-Output
    
        } elseif ( $ObjCount -eq 1 ) {
            
            # Generate a relevant filename
            $FilePath = Join-Path -Path $OutputDir -ChildPath "UserExpiry_$Timestamp.csv"

            # Output user details to the screen
            Write-Host -ForegroundColor 'Green' "`nResolved account name to user:"
            Write-Output $UsrObject | Format-List

            # Write the groups to a CSV file
            Write-Host -ForegroundColor 'Green' "Adding to $FilePath`n"
            $UsrObject | Export-Csv -NoTypeInformation -Path $FilePath

        } else {

            # If nothing matches, print an error and jump back up to the 'Do' loop
            Write-Host -ForegroundColor 'Magenta' "`nUnable to find account name matching input: `'$InputStr`'`n"
            continue
        }
    }

} until ($Quit)