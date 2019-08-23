# PowerShell script to export a list of groups for a specified user
# Version 2.0 - Copyright DM Tech 2019
#
# This script prompts for an AD account name to generate a list of groups that the specified user belongs to
# It then both writes a list of groups to the screen and a text file sorted by name

#Requires -Modules ActiveDirectory

Write-Host -ForegroundColor 'Magenta' "`nPowerShell script to export a list of groups a specified user belongs to (excluding `'Domain Users`')"

# Global variables 
$Quit = $False
$Timestamp = Get-Date -Format yyyyMMdd
$OutputDir = "..\Output"

If( !(Test-Path $OutputDir)) {

    Write-Host -ForegroundColor 'Magenta' "`nPath to `'$OutputDir`' does not exist, creating it under:"

    # Create output folder if it doesn't exist
    New-Item -ItemType Directory -Force -Path $OutputDir
}

# Continue prompting for account names until 'q' is entered
Do {

    # Get input for name lookup
    $Lookup = Read-Host -Prompt "`nEnter a user's first, last or SAM account name to export groups from, or 'q' to quit"

    # Check if 'q' has been entered
    If ($Lookup -eq "q") {

        Write-Host "Quitting..."
        $Quit = $True
    }

    Else {

        Try {

            # Attempt to resolve the input to a user object in the directory
            $Result = (Get-ADuser -Filter {SamAccountName -like $Lookup -or Name -like $Lookup -or GivenName -like $Lookup -or SurName -like $lookup})
            
            # Create a variable with the SAM for easy access
            $UserSam = $Result.SamAccountName

            # Check if more than one object is returned by the lookup
            If (($Result | Measure-Object).Count -gt 1) {

                Write-Host -ForegroundColor 'Cyan' "`nMultiple matches found, please narrow search to one of the following accounts:`n"
                
                # Output list of user accounts
                Write-Output $UserSam 
            }

            Else {
            
                # Generate a relevant filename, -Path can be adjusted as required
                $File = "GroupMembership_$UserSam-$Timestamp.txt"
                $FileName = (Join-Path -Path "..\Output" -ChildPath $File)

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
            Write-Host -ForegroundColor 'Magenta' "`nUnable to find account name matching input: `'$Lookup`'"
            Continue
        }
    }

} Until ($Quit)
