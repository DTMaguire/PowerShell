# PowerShell script to export groups for a list of old users, remove them from the groups and disable their accounts
# Version 3.0 - Copyright DM Tech 2019
#
# This script will process user exits by:
# - Export a list of group memberships to a text file
# - Remove from all security groups and distribution lists
# - Remove Office 365 licenses and access (via security group removal)
# - Convert the mailbox to shared (if it exists)
# - Optionally, prevent any further email delivery to the mailbox (if it exists)
# - Hide user from the Outlook address book
# - Disable and mark the AD account with "Exit processed"
# - Write transcript of actions to a log file

using namespace System.Collections.Generic
$AccountsArray = [List[PSObject]]::new()
$NotMatched = [List[PSObject]]::new()
$ExchSessionCreated = $false
$O365SessionCreated = $false

function Get-ADAccountInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        [Alias("Identity")]
        [String]$Name
    )
    Get-ADUser -Filter {Name -like $Name -or SamAccountName -like $Name} -Properties * | `
        Select-Object Name, SamAccountName, UserPrincipalName, Memberof, Enabled, Description, Info, msExchRemoteRecipientType
}

function ProcessMailbox ($Account) {

    $AccountUPN = $Account.UserPrincipalName
    if(Get-RemoteMailbox $AccountUPN -ErrorAction SilentlyContinue) {

        Write-Host -ForegroundColor 'White' "`nHiding `'$($Account.UserPrincipalName)`' from address lists..."
        Set-RemoteMailbox -Identity $AccountUPN -HiddenFromAddressListsEnabled $True `
            # Uncomment this to prevent email delivery: -AcceptMessagesOnlyFrom $AccountUPN `
            -WhatIf:$WhatIf
        
        Write-Host -ForegroundColor 'White' "`nSetting mailbox `'$($Account.UserPrincipalName)`' to shared..."
        Invoke-Command -Session $O365Session -ScriptBlock {Set-Mailbox -Identity $Using:AccountUPN `
            -Type Shared -WhatIf:$Using:WhatIf}

        if ($Account.msExchRemoteRecipientType -eq 1) {
            Write-Host -ForegroundColor 'White' "`nUpdating local AD recipient type value from `'1`' to `'97`'"
            Set-ADUser $Account.SamAccountName -Replace `
                @{msExchRemoteRecipientType="97"; msExchRecipientTypeDetails="34359738368"} -WhatIf:$WhatIf
        } elseif ($Account.msExchRemoteRecipientType -eq 4) {
            Write-Host -ForegroundColor 'White' "`nUpdating local AD recipient type value from `'4`' to `'100`'"
            Set-ADUser $Account.SamAccountName -Replace `
                @{msExchRemoteRecipientType="100"; msExchRecipientTypeDetails="34359738368"} -WhatIf:$WhatIf
        } else {
            Write-Host -ForegroundColor 'Magenta' `
                "`nValue: `'$($Account.msExchRemoteRecipientType)' not valid for recipient type, skipping update..."
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
        Remove-ADGroupMember -Identity $Group -Member $AccountSAM -Confirm:$false -WhatIf:$WhatIf
    }

    $FilePath = Join-Path -Path $OutputDirectory -ChildPath "UserExit_$($AccountSAM)_Groups.txt"
    Write-Host -ForegroundColor 'Green' "`nSaving to: $FilePath"
    $Groups | Out-File $FilePath -NoClobber -WhatIf:$WhatIf
}

function ProcessExit ($Account) {

    Write-Host -ForegroundColor 'Cyan' "`nUser: $($Account.Name)"
    Start-Sleep 1

    if ($Account.Description -match "Exit Processed") {
        Write-Host -ForegroundColor 'Magenta' "`nAccount exit already processed, skipping..."
        continue
    }

    $AccountDescription = $Account.Description + " -- Exit Processed: " + (Get-Date).ToShortDateString()
    $ProcessInfo = ("Exit processed " + (Get-Date -Format G) + " by " + ($env:UserName) + ".")

    $AccountSAM = $Account.SamAccountName
    $Groups = ($Account | Select-Object -ExpandProperty Memberof | Get-ADGroup | Sort-Object `
        | Select-Object -ExpandProperty SamAccountName)
    
    if ($null -eq $Groups) {
        Write-Host -ForegroundColor 'Magenta' "`nNo group memberships found!"
    } else {
        RemoveFromGroups $AccountSAM $Groups
    }

    if ($Account.Enabled -eq $True) {
        Write-Host -ForegroundColor 'White' "`nDisabling account..."
        Disable-ADAccount -Identity $AccountSAM -Confirm:$false -WhatIf:$WhatIf
    } else {
        Write-Host -ForegroundColor 'Magenta' "`nAccount already disabled!"
    }

    ProcessMailbox $Account
    
    Set-ADUser -Identity $AccountSAM -Description $AccountDescription `
        -Replace @{info="$ProcessInfo`r`n$($Account.info)"} -WhatIf:$WhatIf
}

function Start-UserExitProcess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        [Alias("User")]
        [string[]]$Identity,

        [Parameter(Position=1)]
        [ValidateScript({
            if (Test-Connection -ComputerName $_ -Quiet -Count 1) {
                $true
            } else {
                throw "Unable to contact on-premise Exchange Server: $($_)"
            }
        })]
        [string]$Exchange = "sydawsexchange",

        [Parameter(Position=2)]
        [ValidateScript({
            if (Test-Path -Path $_) {
                $true
            } else {
                throw "Unable to access: $($_)"
            }                
        })]
        [Alias("OutputDir")]
        [string]$OutputDirectory = "\\NAS-QS-TRS\Groups\Corp_Services\ICT\ICT Operations\User Offboarding",
        
        [Parameter()]
        [Switch]$NoLog = $($WhatIfPreference),
        
        [Parameter()]
        [Switch]$WhatIf = $($WhatIfPreference)
    )

    $LogTime = Get-Date -UFormat %y%m%d%H%M%S
    $LogPath = Join-Path -Path $OutputDirectory -ChildPath 'Logs'
    $LogName = Join-Path -Path $LogPath -ChildPath "$($LogTime).log"
    $ExchangeFQDN = [System.Net.Dns]::GetHostByName($Exchange).HostName

    Start-Transcript -Path $LogName -WhatIf:$NoLog

    Write-Host -ForegroundColor 'White' "`nStarting user exit script`n"

    Write-Host -ForegroundColor 'White' "`n`nImporting the following identities:`n"
    Write-Output $Identity

    Write-Host -ForegroundColor 'Green' "`n`nTotal identities imported: " $Identity.Count "`n"

    foreach ($Name in $Identity) {

        $AccountLookup = (Get-ADAccountInfo $Name)
        if ($null -ne $AccountLookup) {

            # Foreach loop to deal with multiple return values
            foreach ($UserObject in $AccountLookup) {

                # Do another lookup to include related Admin and Comms accounts
                $AdminLookup = Get-ADAccountInfo *$(${UserObject}.SamAccountName)

                foreach ($AdminObject in $AdminLookup) {
                    # If array is empty or does not contain the user object, add it
                    if ($AccountsArray.Count -lt 1) {
                        [void]$AccountsArray.Add($AdminObject)
                        
                    } elseif (!($AccountsArray.SamAccountName.Contains($AdminObject.SamAccountName))) {
                        [void]$AccountsArray.Add($AdminObject)
                    }
                }
            }
        } else {
            # If the name is not found, record it and notify 
            [void]$NotMatched.Add($Name)
        }
    }

    if ($AccountsArray.Count -gt 0) {

        Write-Host -ForegroundColor 'White' "`nAccount name matches found:"
        $AccountsArray | Format-Table -Property Name, SamAccountName, UserPrincipalName, Enabled, Description

        Write-Host -ForegroundColor 'Green' "Total accounts matched: " $AccountsArray.Count

        if ($NotMatched.Count -eq 1) {
            Write-Host -ForegroundColor 'Magenta' "`n`nNo account match for:`n"
            Write-Output $NotMatched
        } elseif ($NotMatched.Count -gt 1) {
            Write-Host -ForegroundColor 'Magenta' "`n`nNo account matches for $($NotMatched.Count) names, `
                please check input for:`n"
            Write-Output $NotMatched
        }

        if ((Read-Host -Prompt "`n`nRun exit process for these accounts (y/N)?") -eq 'y') {

            if (Get-PSSession | Where-Object {$_.ComputerName -eq $ExchangeFQDN -and $_.State -eq 'Opened'}) {
                Write-Host -ForegroundColor 'White' "`nDetected active on-premise Exchange session..."
            } else {
                Write-Host -ForegroundColor 'White' "`nOn-premise Exchange session starting..."
                Import-PSSession (New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri `
                    "http://$ExchangeFQDN/powershell/") -AllowClobber  -CommandName "*RemoteMailbox" | Out-Null
                $Script:ExchSessionCreated = $true
            }

            if (Get-PSSession | Where-Object {$_.ComputerName -eq 'outlook.office365.com' -and $_.State -eq 'Opened'}) {
                Write-Host -ForegroundColor 'White' "`nDetected active Office 365 Exchange Online session..."
                $Script:O365Session = (Get-PSSession | Where-Object `
                    {$_.ComputerName -eq 'outlook.office365.com' -and $_.State -eq 'Opened'} | Select-Object -First 1)
            } else {
                # This is a check to see if the environment variable for specifying an admin username exists
                # If so, call Functions-PSStoredCredentials.ps1 and attempt to grab the stored credentials
                # If not, fall back to the standard annoying prompt
                try {
                    # The two lines below should be set in the PowerShell profile:
                    #   $KeyPath = "$Home\Documents\WindowsPowerShell"
                    #   . "$Env:DevPath\Profile\Functions-PSStoredCredentials.ps1"
                    $O365Cred = (Get-StoredCredential -UserName $Env:AdminUPN)
                } catch {
                    Write-Host -ForegroundColor 'Magenta' "`nAdmin credentials required..."
                    $O365Cred = (Get-Credential)
                }
            
                Write-Host -ForegroundColor 'White' "`nOffice 365 Exchange Online session starting..."
                $Script:O365Session = (New-PSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
                    -ConfigurationName Microsoft.Exchange -Credential $O365Cred -Authentication Basic -AllowRedirection)
                $Script:O365SessionCreated = $true
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
        Get-PSSession | Where-Object {$_.ComputerName -eq $ExchangeFQDN} | Remove-PSSession
    }
    if ($O365SessionCreated -eq $true) {
        Write-Host -ForegroundColor 'White' "`nClosing Office 365 Exchange Online session..."
        Get-PSSession | Where-Object {$_.ComputerName -eq 'outlook.office365.com'} | Remove-PSSession
    }

    Write-Host -ForegroundColor 'White' "`nEnd of processing`n"

    if ($NoLog -eq $false) {
        Stop-Transcript
    }
    $AccountsArray.Clear()
    $NotMatched.Clear()
}