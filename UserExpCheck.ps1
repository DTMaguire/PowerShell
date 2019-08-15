# PowerShell script to export a list of account expiry and password attributes for a specified user to CSV
# Version 2.0 - Copyright DM Tech 2019

#Requires -Modules ActiveDirectory

# Global variables
$Quit = $False
$Timestamp = Get-Date -Format yyyyMMdd

Do {

    $User = Read-Host -Prompt "`nEnter an AD account username to check, or 'q' to quit"

    If ($User -eq "q") {

        Write-Host "Quitting..."

        $Quit = $True
    }

    Else {

        Try {
        
            #Format a list of relevant properties
            $Properties = (Get-ADUser -Identity $User -Properties * -ErrorAction Inquire | Select-Object `
            -Property Name,AccountExpirationDate,AccountLockoutTime,BadLogonCount,Enabled,LastBadPasswordAttempt,`
            LastLogonDate,LockedOut,lockoutTime,PasswordExpired,PasswordLastSet,PasswordNeverExpires)

            Write-Output ($Properties | Format-List)

            Write-Host -ForegroundColor 'Green' "Adding to UserExpiry_$Timestamp.csv`n"

            # Export and append the properties to CSV
            Export-Csv -NoTypeInformation -Append -Path "UserExpiry_$Timestamp.csv" -InputObject $Properties
        }

        Catch {

            Write-Host -ForegroundColor 'Magenta' "`nUnable to find account name match for `'$User`'"

            Continue
        }

    }

} Until ($Quit)
