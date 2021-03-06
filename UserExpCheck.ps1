# PowerShell script to export a list of account expiry and password attributes for a specified user to CSV
# Version 3.0 - Copyright DM Tech 2019

#Requires -Modules ActiveDirectory

Write-Host -ForegroundColor 'Cyan' "`nPowerShell script to gather account expiry and password attributes for a specified user and export them to CSV`n"

# Global variables 
$Quit = $False
$DateStamp = Get-Date -Format yyyyMM
$OutputDir = "..\Output"
$PDC = (Get-ADDomain).PDCEmulator
$AccProps = @("GivenName","SurName","Title","SamAccountName","UserPrincipalName","Enabled","LastLogonDate","PasswordExpired","PasswordLastSet","PasswordNeverExpires","AccountExpirationDate","BadLogonCount","LastBadPasswordAttempt","LockedOut","AccountLockoutTime")

function AccountLookup {
    param ($InputStr)
    
    # Filter invalid input with a regular expression allowing for a maximum of 2 non-consecutive wildcards or spaces
    if ($InputStr -match '\*?[-\w]+\s?\*?') { 

        try {       # Test if input exactly matches a user identity (SamAccountName)

            $UsrObject = (Get-ADUser -Identity $InputStr -Server $PDC -Properties * | Select-Object -Property $AccProps)
        }
        catch {     # Fall back to an LDAPFilter query which allows wildcard searches

            $UsrObject = (Get-ADUser -LDAPFilter "(|(SamAccountName=$InputStr)(GivenName=$InputStr)(SN=$InputStr))" -Server $PDC -Properties * | Select-Object -Property $AccProps)
        }

    } else {        # Otherwise, just return nothing instead of generating an error
        
        return
    }
    
    return $UsrObject
}

function GetPasswordExp {
    param ($UsrSam)

    if ($UsrObject.PasswordNeverExpires -eq $True) {

        $PasswordExp = $null
    } else {

        $PasswordExpInt = (Get-ADUser -Identity $UsrSam -Properties msDS-UserPasswordExpiryTimeComputed | Select-Object -ExpandProperty "msDS-UserPasswordExpiryTimeComputed")
        $PasswordExp = ([datetime]::FromFileTime($PasswordExpInt))
    }

    return $PasswordExp
}

if (!(Test-Path $OutputDir)) {

    Write-Host -ForegroundColor 'Magenta' "`nPath to `'$OutputDir`' does not exist, creating it under:"
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
        
        $UsrObject = AccountLookup $InputStr
        $ObjCount = ($UsrObject | Measure-Object).Count

        # Determine path to take depending on number of objects returned by AccountLookup
        if ($ObjCount -gt 1) {

            Write-Host -ForegroundColor 'Magenta' "`n$ObjCount matches found, please narrow search to one of the following accounts:"
            $UsrObject | Select-Object GivenName,SurName,Title,SamAccountName,UserPrincipalName | Format-Table
    
        } elseif ($ObjCount -eq 1) {
            
            $PasswordExp = GetPasswordExp $UsrObject.SamAccountName
            Add-Member -InputObject $UsrObject -NotePropertyMembers @{'PasswordExpirationDate'=$PasswordExp}
            Write-Host -ForegroundColor 'Green' "`nAccount and password details:"
            $UsrObject | Format-List
            
            if ($null -ne $PasswordExp) {

                $Remaining = (New-TimeSpan -Start (Get-Date) -End $PasswordExp)
                Write-Host -ForegroundColor 'White' $Remaining.Days "days," $Remaining.Hours "hours," $Remaining.Minutes "minutes until password expires.`n`n"
            }

            try {

                $FilePath = Join-Path -Path $OutputDir -ChildPath "UserExpiry_$DateStamp.csv"
                $UsrObject | Export-Csv -NoTypeInformation -Append -Path $FilePath
                Write-Host -ForegroundColor 'Green' "Adding to $FilePath`n"
            }
            catch {
                
                Write-Host -ForegroundColor 'Magenta' "Unable to open $Filepath for writing - please close the file try again.`n"
            } 

        } else {

            Write-Host -ForegroundColor 'Magenta' "`nUnable to find account name matching input: `'$InputStr`'`n"
            continue
        }
    }

} until ($Quit)