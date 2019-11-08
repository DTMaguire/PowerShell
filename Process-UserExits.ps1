# PowerShell script to export groups for a list of old users, remove them from the groups and disable their accounts
# Version 2.0 - Copyright DM Tech 2019
# Still a work in progress - To Do:
#   Extend input to allow reading of users from text and CSV files
#   Create parameters and turn into module
#
#Requires -PSEdition Desktop
#Requires -Version 5
#Requires -Modules ActiveDirectory

$NameList = @()
$AccountsArray = @()
$NotMatched = @()
$MailDomain = "externalmaildomain.com.au"
$ExchFQDN = "internalexchange.domain.name"
$OutputDir = "\\SomeNetworkPath\ICT\ICT Operations\User Offboarding"
$LogTime = Get-Date -UFormat %y%m%d%H%M%S
$LogPath = Join-Path -Path $OutputDir -ChildPath 'Logs'
$LogName = Join-Path -Path $LogPath -ChildPath "$($LogTime).log"
$ExchSessionCreated = $false
$O365SessionCreated = $false
$WinVer = [version](Get-CimInstance Win32_OperatingSystem).version
$Shell = $Host.UI.RawUI
$Shell.WindowTitle="User Offboarding Script"

If ($WinVer -lt [version]6.2) {

    # Shell variables to size window correctly for Win 7 and earlier
    $BSize = $Shell.BufferSize
    $BSize.Width=120
    $Shell.BufferSize = $BSize

    $WSize = $Shell.WindowSize
    $WSize.Width=120
    $Shell.WindowSize = $WSize
}

if ($env:UserName -notlike "admin*") {
    Write-Host -ForegroundColor 'Red' "`nThe current account `'$env:UserName`' does not appear to be a domain admin.
Please re-run this script with your admin account (Shift-right click, Run as different user).`nExiting...`n"
    Start-Sleep 3
    exit
}

function GetUserAccount ($Name) {

    Get-ADUser -Filter {Name -like $Name -or SamAccountName -like $Name} -Properties * | `
    Select-Object Name, SamAccountName, UserPrincipalName, Memberof, Enabled, Description, Info, msExchRemoteRecipientType
}

function ProcessMailbox ($Account) {

    $AccountUPN = $Account.UserPrincipalName
    if(Get-RemoteMailbox $AccountUPN -ErrorAction SilentlyContinue) {

        Set-RemoteMailbox -Identity $AccountUPN -AcceptMessagesOnlyFrom $AccountUPN -HiddenFromAddressListsEnabled $True #-WhatIf
        Write-Host -ForegroundColor 'White' "`nSetting mailbox for `'$($Account.UserPrincipalName)`' to shared..."
        Invoke-Command -Session $O365Session -ScriptBlock {Set-Mailbox -Identity $Using:AccountUPN -Type Shared <#-WhatIf#>}

        if ($Account.msExchRemoteRecipientType -eq 1) {
            Write-Host -ForegroundColor 'White' "`nUpdating local AD recipient type value from `'1`' to `'97`'"
            Set-ADUser $Account.SamAccountName -Replace @{msExchRemoteRecipientType="97"; msExchRecipientTypeDetails="34359738368"} #-WhatIf
        } elseif ($Account.msExchRemoteRecipientType -eq 4) {
            Write-Host -ForegroundColor 'White' "`nUpdating local AD recipient type value from `'4`' to `'100`'"
            Set-ADUser $Account.SamAccountName -Replace @{msExchRemoteRecipientType="100"; msExchRecipientTypeDetails="34359738368"} #-WhatIf
        } else {
            Write-Host -ForegroundColor 'Magenta' "`nValue: `'$($Account.msExchRemoteRecipientType)' not valid for recipient type, skipping update..."
            continue
        }
        
    } else {
        Write-Host -ForegroundColor 'Magenta' "`nNo mailbox for `'$AccountUPN`' found!"
    }
}

function RemoveFromGroups ($AccountSAM, $Groups) {

    Write-Host -ForegroundColor 'White' "`nGroup membership:`n"
    $Groups | Out-String
    Write-Host -ForegroundColor 'White' "Total groups: $($Groups.Count)`n"

    foreach ($Group in $Groups) {
        Start-Sleep -Milliseconds 100
        Write-Host -ForegroundColor 'White' "Removing from:" $Group
        Remove-ADGroupMember -Identity $Group -Member $AccountSAM -Confirm:$false #-WhatIf
    }

    $FilePath = Join-Path -Path $OutputDir -ChildPath "UserExit_$($AccountSAM)_Groups.txt"
    Write-Host -ForegroundColor 'Green' "`nSaving to: $FilePath"
    $Groups | Out-File $FilePath -NoClobber #-WhatIf
}

function ProcessExit ($Account) {

    Write-Host -ForegroundColor 'Cyan' "`nUser: $($Account.Name)"
    Start-Sleep 1

    if ($Account.Description -match "Exit Processed") {
        Write-Host -ForegroundColor 'Magenta' "`nAccount exit already processed - continuing!"
        continue
    }

    $Account.Description += (" -- Exit Processed: " + (Get-Date).ToShortDateString() )
    $ProcessInfo = ("Exit processed " + (Get-Date -Format G) + " by " + ($env:UserName) + ".")

    $AccountSAM = $Account.SamAccountName
    $Groups = ($Account | Select-Object -ExpandProperty Memberof | Get-ADGroup | Sort-Object | Select-Object -ExpandProperty SamAccountName)
    
    if ($null -eq $Groups) {
        Write-Host -ForegroundColor 'Magenta' "`nNo group memberships found!"
    } else {
        RemoveFromGroups $AccountSAM $Groups
    }

    if ($Account.Enabled -eq $True) {
        Write-Host -ForegroundColor 'White' "`nDisabling account..."
        Disable-ADAccount -Identity $AccountSAM -Confirm:$false #-WhatIf
    } else {
        Write-Host -ForegroundColor 'Magenta' "`nAccount already disabled!"
    }

    ProcessMailbox $Account
    
    Set-ADUser -Identity $AccountSAM -Description $Account.Description -Replace @{info="$ProcessInfo`r`n$($Account.info)"} #-WhatIf
}

If(!(Test-Path -Path $LogPath)){
    New-Item -Path $LogPath -ItemType Directory
}

Start-Transcript -Path $LogName | Out-Null
Write-Host -ForegroundColor 'White' "`nStarting user exit script`n"

do {
    $ReadInput = (Read-Host -Prompt "Enter usernames seperated by commas, or `'q`' to quit")
    if ($ReadInput -eq 'q') {
        exit
    }
} until ($ReadInput -match '[\w.]+')

$NameList = @(($ReadInput).Split(",").Trim())

<#
Alternatively, NameList can be set to get info from a file or even file names like so:
$NameList = @((Get-Content -Path "D:\Scripts\Input\AWS-OldUsers_Remaining.txt") | Where-Object {$_ -ne "Jonathan Fan"})
$NameList = @((Get-ChildItem -Path "\\NAS-QS-TRS\Groups\Corp_Services\ICT\ICT Operations\User Offboarding" | Select-Object -ExpandProperty Name) -replace ('UserExit_','') -replace ('_Groups.txt',''))
#>

Write-Host -ForegroundColor 'White' "`n`nImporting the following users:`n"
Write-Output $NameList
Write-Host -ForegroundColor 'Green' "`n`nTotal names imported: " $NameList.Count "`n"

foreach ($Name in $NameList) {
    $AccountLookup = (GetUserAccount $Name)
    if ($null -ne $AccountLookup) {
        $AccountsArray += $AccountLookup
    } else {
        $NotMatched += $Name
    }
}

if ($AccountsArray.Length -gt 0) {

    Write-Host -ForegroundColor 'White' "`nAccount name matches found:"
    $AccountsArray | Format-Table -Property Name, SamAccountName, UserPrincipalName, Enabled, Description

    Write-Host -ForegroundColor 'Green' "Total accounts matched: " $AccountsArray.Count

    if ($NotMatched.Count -eq 1) {
        Write-Host -ForegroundColor 'Magenta' "`n`nNo account match for:`n"
        Write-Output $NotMatched
    } elseif ($NotMatched.Count -gt 1) {
        Write-Host -ForegroundColor 'Magenta' "`n`nNo account matches for $($NotMatched.Count) names, please check input for:`n"
        Write-Output $NotMatched
    }
    
    if ((Read-Host -Prompt "`n`nRun exit process for these accounts (y/N)?") -eq 'y') {
        
        if (Get-PSSession | Where-Object {$_.ComputerName -eq $ExchFQDN -and $_.State -eq "Opened"}) {
            Write-Host -ForegroundColor 'White' "`nDetected active on-premise Exchange session..."
        } else {
            Write-Host -ForegroundColor 'White' "`nOn-premise Exchange session starting..."
            Import-PSSession (New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$ExchFQDN/powershell/") -AllowClobber -CommandName "*RemoteMailbox" | Out-Null
            $ExchSessionCreated = $true
        }

        if (Get-PSSession | Where-Object {$_.ComputerName -eq "outlook.office365.com" -and $_.State -eq "Opened"}) {
            Write-Host -ForegroundColor 'White' "`nDetected active Office 365 Exchange Online session..."
            $O365Session = (Get-PSSession | Where-Object {$_.ComputerName -eq "outlook.office365.com" -and $_.State -eq "Opened"} | Select-Object -First 1)
        } else {
            # This is a check to see if the custom environment variable exists which I use for specifying an admin username for authentication
            # If so, the custom Functions-PSStoredCredentials.ps1 should also be loaded so just grab the credentials from there
            # If not, fall back to the standard annoying prompt...
            # For more info, see: https://practical365.com/blog/saving-credentials-for-office-365-powershell-scripts-and-scheduled-tasks/
            try {
                # The two lines below should be set in the PowerShell profile:
                #$KeyPath = "$Home\Documents\WindowsPowerShell"
                #. "$Env:DevPath\Profile\Functions-PSStoredCredentials.ps1"
                $O365Cred = (Get-StoredCredential -UserName ($env:UserName + "@$MailDomain"))
            }
            catch {
                Write-Host -ForegroundColor 'Magenta' "`nAdmin credentials required..."
                $O365Cred = (Get-Credential) #-Credential ($env:UserName + "@$MailDomain"))
            }
        
            Write-Host -ForegroundColor 'White' "`nOffice 365 Exchange Online session starting..."
            $O365Session = New-PSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
            -ConfigurationName Microsoft.Exchange -Credential $O365Cred -Authentication Basic -AllowRedirection
            $O365SessionCreated = $true
        }

        Start-Sleep 1    
        foreach ($Account in $AccountsArray) {
            ProcessExit $Account
        }
    }
    
} else {
    Write-Host -ForegroundColor 'Magenta' "`nNo account name matches found!"
}

if ($ExchSessionCreated -eq $true) {
    Write-Host -ForegroundColor 'White' "`nClosing on-premise Exchange session..."
    Get-PSSession | Where-Object {$_.ComputerName -eq $ExchFQDN} | Remove-PSSession
}
if ($O365SessionCreated -eq $true) {
    Write-Host -ForegroundColor 'White' "`nClosing Office 365 Exchange Online session..."
    Get-PSSession | Where-Object {$_.ComputerName -eq "outlook.office365.com"} | Remove-PSSession
}

Write-Host -ForegroundColor 'White' "`nEnd of processing`n"
Stop-Transcript | Out-Null
$Shell.WindowTitle="User Offboarding Script"
