# PowerShell script to check a users' credentials against AD
# Version 2.0 - Copyright DM Tech 2019
#
# Be aware this test is counted as a normal login and can cause an account lockout after multiple attempts

#Requires -Modules ActiveDirectory

Write-Host -ForegroundColor 'Cyan' "`nPowerShell script to check a users' credentials against AD`n"

Function TestADAuthentication {
    Param($UserLogin,$UserPassword)
    (New-Object DirectoryServices.DirectoryEntry "",$UserLogin,$UserPassword).psbase.name -ne $null
}

$Quit = $False

Do {
    # Prompt for user name or to quit
    $Login = Read-Host "Enter user name, or `'q`' to quit"

    If ($Login -eq "q") {

        # Wipe plain text credentials off the console
        Clear-Host

        Write-Host -ForegroundColor 'Magenta' "Clearing screen and quitting...`n"
        $Quit = $True
    }

    Else {

        # Prompt user to enter account password
        # The -AsSecureString option would be ideal here but it causes the function lookup to fail
        $Password = Read-Host "Enter password"

        If (TestADAuthentication $Login $Password){
            Write-Host -ForegroundColor 'Green' "`nValid credentials`n"
        }

        Else {
            Write-Host -ForegroundColor 'Red' "`nInvalid credentials`n"
        }
    }

} Until ($Quit)
