# PowerShell script to export a list of account expiry and password attributes for a specified user to CSV
# Version 2.0 - Copyright DM Tech 2019

#Requires -Modules ActiveDirectory

Write-Host -ForegroundColor 'Cyan' "`nPowerShell script to gather account expiry and password attributes for a specified user and export them to CSV"

# Global variables
$Quit = $False
$Timestamp = Get-Date -Format yyyyMMdd
$OutputDir = "..\Output"

If( !(Test-Path $OutputDir)) {

    Write-Host -ForegroundColor 'Magenta' "`nPath to `'$OutputDir`' does not exist, creating it under:"

    # Create output folder if it doesn't exist
    New-Item -ItemType Directory -Force -Path $OutputDir
}

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
            -Property Name,CanonicalName,SamAccountName,UserPrincipalName,AccountExpirationDate,AccountLockoutTime,BadLogonCount,`
            Enabled,LastBadPasswordAttempt,LastLogonDate,LockedOut,lockoutTime,PasswordExpired,PasswordLastSet,PasswordNeverExpires)

            Write-Output ($Properties | Format-List)

            $File = "UserExpiry_$Timestamp.csv"
            $FileName = (Join-Path -Path $OutputDir -ChildPath $File)

            Write-Host -ForegroundColor 'Green' "Adding to $FileName`n"

            # Export and append the properties to CSV
            Export-Csv -NoTypeInformation -Append -Path $FileName -InputObject $Properties
        }

        Catch {

            Write-Host -ForegroundColor 'Magenta' "`nUnable to find account name match for `'$User`'"

            Continue
        }
    }

} Until ($Quit)
