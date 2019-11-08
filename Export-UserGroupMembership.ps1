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
$AccProps = @("GivenName","SurName","Title","SamAccountName","UserPrincipalName","CanonicalName")

function AccountLookup {
    param ($InputStr)
    
    # Filter invalid input with a regular expression that allows for a maximum of 2 non-consecutive wildcards or spaces
    if ($InputStr -match '\*?[-\w]+\s?\*?') { 

        try {       # Test if input exactly matches a user identity (SamAccountName)

            $UsrObject = (Get-ADUser -Identity $InputStr -Properties * | Select-Object -Property $AccProps)
        }
        catch {     # Otherwise, fall back to an LDAPFilter query which allows wildcard searches

            $UsrObject = (Get-ADUser -LDAPFilter "(|(SamAccountName=$InputStr)(GivenName=$InputStr)(SN=$InputStr))" -Properties * | Select-Object -Property $AccProps)
        }

    } else {        # If all else fails, just return nothing instead of generating a nasty red error mesasge
        
        return
    }
    
    return $UsrObject
}

function GetGroups {
    param ($UsrObject)

    # Generate a list of groups for a matched user account
    $Groups = (Get-ADPrincipalGroupMembership -Identity $UsrObject.SamAccountName | Get-ADGroup -Properties * | Sort-Object | Select-Object -Property Name, SamAccountName, GroupCategory, Description)

    return $Groups
}

if (!(Test-Path $OutputDir)) {

    Write-Host -ForegroundColor 'Magenta' "`nPath to `'$OutputDir`' does not exist, creating it under:"

    # Create output folder if it doesn't exist
    New-Item -ItemType Directory -Force -Path $OutputDir
}

# Main loop - continue prompting for account names until 'q' is entered
do {

    Write-Host -ForegroundColor 'White' "Input name to search for user account (wildcards supported), or 'q' to quit`n`n:> " -NoNewline
    $InputStr = Read-Host

    if ($InputStr -eq "q") {

        Write-Host -ForegroundColor 'White' "`nQuitting...`n"
        $Quit = $True

    } elseif ($InputStr.length -lt 2) {

        Write-Host -ForegroundColor 'Magenta' "`nPlease Enter 2 or more characters!`n"

    } else {
        
        # Attempt to resolve the input to a user object in the directory, assign attributes to variables
        $UsrObject = AccountLookup $InputStr

        $ObjCount = ($UsrObject | Measure-Object).Count
        $UsrProps = ($UsrObject | Select-Object -Property  GivenName,SurName,Title,SamAccountName,UserPrincipalName)

        # Determine path to take depending on number of objects returned by lookup
        if ($ObjCount -gt 1) {

            Write-Host -ForegroundColor 'Magenta' "`n`n$ObjCount matches found, please narrow search to one of the following accounts:"
            $UsrProps | Format-Table
    
        } elseif ($ObjCount -eq 1) {
            
            $Groups = GetGroups $UsrObject

            $FilePath = Join-Path -Path $OutputDir -ChildPath "GroupMembership_$($UsrProps.SamAccountName)-$Timestamp.csv"

            # Output user details to the screen
            Write-Host -ForegroundColor 'Green' "`n`nResolved account name to user:"
            $UsrProps | Format-Table

            Write-Host -ForegroundColor 'Green' "Under OU:`n"
            Write-Output $UsrObject.CanonicalName
            Start-Sleep 1

            Write-Host -ForegroundColor 'Green' "`n`nGroup memberships:"
            $Groups | Select-Object -Property Name, GroupCategory, Description | Format-Table

            try {

                $Groups | Export-Csv -NoTypeInformation -Path $FilePath
                Write-Host -ForegroundColor 'Green' "Writing groups to `'$FilePath`'`n"
                Start-Sleep 1
    
                Write-Host -ForegroundColor 'White' "Open file? (y/N):> " -NoNewline
                $InputStr =Read-Host
    
                if ($InputStr -eq "y") {

                    Invoke-Item -Path $FilePath

                } elseif ($InputStr -eq "q") {
                    
                    Write-Host -ForegroundColor 'White' "`nQuitting...`n"
                    $Quit = $True
                }

                Write-Host "`n"
            }
            catch {

                Write-Host -ForegroundColor 'Magenta' "Unable to open $Filepath - please close the file and try again.`n"
            }
            
        } else {

            Write-Host -ForegroundColor 'Magenta' "`nUnable to find account name matching input: `'$InputStr`'`n"
            continue
        }
    }

} until ($Quit)