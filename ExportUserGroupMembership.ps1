# PowerShell script to export a list of groups for a specified user
# Version 2.0 - Copyright DM Tech 2019
#
# This script prompts for an AD account name to generate a list of groups that the specified user belongs to
# It then both writes a list of groups to the screen and a text file sorted by name

#Requires -Modules ActiveDirectory

# Global variables 
$Quit = $False
$Timestamp = Get-Date -Format yyyyMMdd

Write-Host -ForegroundColor 'Magenta' "`nPowerShell script to export a list of groups a specified user belongs to (excluding `'Domain Users`')"

# Continue prompting for account names until 'q' is entered
Do {

    # Get input for name lookup
    $NameLookup = Read-Host -Prompt "`nEnter a user's first, last or SAM account name to export groups from, or 'q' to quit"

    # Check if 'q' has been entered
    If ($NameLookup -eq "q") {

        Write-Host "Quitting..."
        
        $Quit = $True
    }

    Else {

        Try {

            # Attempt to resolve the input to a user object in the directory
            $Result = (Get-ADuser -Filter {Name -like $NameLookup -or GivenName -like $NameLookup -or SurName -like $Namelookup})
            
            # Create a variable with the SAM for easy access
            $UserSam = $Result.SamAccountName

            # Check if more than one object is returned by the lookup
            If (($Result | Measure-Object).Count -gt 1) {

                Write-Host -ForegroundColor 'Cyan' "`nMultiple matches found, please narrow search to one of the following accounts:`n"
                
                # Output list of user accounts
                Write-Output $UserSam 
            }

            Else {
            
                # Generate a relevant filename
                $FileName = "GroupMembership_$UserSam-$Timestamp.txt"

                # Generate a list of groups for a single matched user account
                $Groups = (Get-ADUser -Identity $UserSam -Properties MemberOf | Select-Object -ExpandProperty MemberOf | Get-ADGroup | Sort-Object | Select-Object -Property Name)
            
                Write-Host -ForegroundColor 'Green' "`nWriting the following groups to `'$FileName`':`n"
                        
                # Output to the screen by name only
                Write-Output $Groups.Name

                # Write the groups to a file
                Out-File -FilePath $FileName -InputObject $Groups

                # Output to screen and write to file
                #Tee-Object -InputObject $Groups -FilePath $FileName
                # Works fine but doesn't include the 'Name' header which could be useful for future parsing of the text files
            }
        }

        Catch {

            # If triggered, print an error and jump back up to the 'Do' loop
            Write-Host -ForegroundColor 'Magenta' "`nUnable to find account name matching input: `'$NameLookup`'"
            
            Continue
        }
    }

} Until ($Quit)
