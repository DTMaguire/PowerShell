# PowerShell script to export groups for a list of old users, remove them from the groups and disable their accounts
# Version 3.4 - Copyright DM Tech 2019-2020
#
# This script will process user exits by running the following procedure on matched AD accounts:
# - Export a list of group memberships to a text file
# - Remove from all security groups and distribution lists
# - Remove Office 365 licenses and access (via security group removal)
# - Convert the mailbox to shared (if it exists)
# - Cancel future calendar appointments where the mailbox owner is the organiser
# - Optionally, prevent any further email delivery to the mailbox
# - Hide user from the Outlook address book
# - Remove Teams/Skype for Business attributes and release assigned phone number
# - Remove from any directly assigned Office 365 cloud groups
# - Disable and mark the AD account with "Exit processed"
# - Write transcript of actions to a log file

using namespace System.Collections.Generic
$AccountsArray = [List[PSObject]]::new()
$NotMatched = [List[PSObject]]::new()
$ExchSessionCreated = $false
$O365SessionCreated = $false

function SetUserLicenses {
    param (
        $Identity
    )
    $DisabledPlans =    'CDS_O365_P1',
                        'YAMMER_ENTERPRISE',
                        'WHITEBOARD_PLAN1',
                        'BPOS_S_TODO_1',
                        'SWAY',
                        'SHAREPOINTSTANDARD',
                        'POWERAPPS_O365_P1',
                        'OFFICEMOBILE_SUBSCRIPTION',
                        'SHAREPOINTWAC',
                        'INTUNE_O365',
                        'STREAM_O365_E1',
                        'Deskless',
                        'MICROSOFT_SEARCH',
                        'PROJECTWORKMANAGEMENT',
                        'FORMS_PLAN_E1',
                        'MYANALYTICS_P2',
                        'FLOW_O365_P1',
                        'EXCHANGE_S_STANDARD'

    $LicenseOptions = (New-MsolLicenseOptions -AccountSkuId 'NSWLandRegistryServices:TEAMS_EXPLORATORY' -DisabledPlans $DisabledPlans)

    while ($MsolUser.Licenses.AccountSkuID -notcontains 'NSWLandRegistryServices:MCOEV' -and !($WhatIf)) {
        
        Write-Host "`nNo Microsoft 365 Phone System or Teams license found." -ForegroundColor Yellow
        Write-Host "Assigning licenses temporarily and waiting 2 minutes for them to apply...`n" -ForegroundColor Cyan
     
        Set-MsolUserLicense -UserPrincipalName $Identity -AddLicenses 'NSWLandRegistryServices:TEAMS_EXPLORATORY' -LicenseOptions $LicenseOptions
        Start-Sleep 5
    
        Set-MsolUserLicense -UserPrincipalName $Identity -AddLicenses 'NSWLandRegistryServices:MCOEV'
        Start-Sleep 115

        $Script:MsolUser = (Get-MsolUser -UserPrincipalName $Identity)
    }
}

function DeprovisionO365Teams {
    param (
        $Identity
    )
    $TeamsProps =       'DisplayName',
				        'UserPrincipalName',
				        'LineURI',
				        'OnPremLineURI',
				        'OnPremLineURIManuallySet',
				        'EnabledForRichPresence',
				        'EnterpriseVoiceEnabled',
				        'VoicePolicy',
				        'OnlineVoiceRoutingPolicy',
				        'DialPlan',
				        'TenantDialPlan',
				        'HostedVoiceMail',
				        'HostedVoicemailPolicy',
				        'ConferencingPolicy',
				        'MobilityPolicy',
                        'OnlineDialinConferencingPolicy'
    
    $MsolUser = (Get-MsolUser -UserPrincipalName $Identity -ErrorAction SilentlyContinue)
    $TeamsUser = (Get-CsOnlineUser -Identity $Identity -ErrorAction SilentlyContinue | Select-Object $TeamsProps)

    if ($MsolUser) {

        if ($TeamsUser) {

            WriteLine Cyan

            Write-Host "`nTeams attributes:" -ForegroundColor White
            Format-List -InputObject $TeamsUser 
            # A Teams/Phone System license is required to remove the Policies and OnPremLineURI attribute!
            Write-Host "Assigned licenses:`n" -ForegroundColor White
            Format-List -InputObject $MsolUser.Licenses.AccountSkuID
            Start-Sleep 1
            
            if ($TeamsUser.OnPremLineURI) {
                SetUserLicenses $Identity
                Write-Host "`nReturning phone number to pool: $($TeamsUser.OnPremLineURI.split(':')[1])`n" -ForegroundColor Green
                Set-CsUser -Identity $Identity -OnPremLineURI $null -EnterpriseVoiceEnabled $false -WhatIf:$WhatIf
            }
            if ($TeamsUser.OnlineVoiceRoutingPolicy) {
                SetUserLicenses $Identity
                Grant-CsOnlineVoiceRoutingPolicy -Identity $Identity -PolicyName $null -WhatIf:$WhatIf
            }
            if ($TeamsUser.TenantDialPlan) {
                SetUserLicenses $Identity
                Grant-CsTenantDialPlan -Identity $Identity -PolicyName $null -WhatIf:$WhatIf
            }
        }
        else {
            Write-Host "`nNo Teams attributes found for: $Identity"
        }

        $DirectlyAssigned =  ($MsolUser.Licenses | Where-Object {!($_.GroupsAssigningLicense)}).AccountSkuID
        
        if ($DirectlyAssigned) {

            Write-Host "`nDirectly assigned licenses to be removed:`n" -ForegroundColor White
            Format-List -InputObject $DirectlyAssigned

            if (!$WhatIf) {
                $DirectlyAssigned | ForEach-Object {
                    #Write-Host "Set-MsolUserLicense -UserPrincipalName $Identity -RemoveLicenses $_"
                    Set-MsolUserLicense -UserPrincipalName $Identity -RemoveLicenses $_
                    # No -WhatIf option exists for this cmdlet!
                }   
            }
        }
    }
    else {
        Write-Host "No matching Azure AD account found!" -ForegroundColor Magenta
        <# 
        Write-Host "No matching Azure AD account found, other possible account names:"
        Get-MsolUser -SearchString "$(($Account.SamAccountName).split('.')[1])" #>
    }
    WriteLine Cyan -End
    Start-Sleep 1
}

function Get-ADExchangeInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        [Alias("Identity")]
        [String]$Name,

        [Parameter()]
        [string[]]
        $Properties = @('Name','SamAccountName','UserPrincipalName','Memberof','Enabled','Description','Info','msExchRemoteRecipientType'),

        [Parameter()]
        [switch]$Exact
    )

    if ($Exact) {
        Get-ADUser -Identity $Name -Properties $Properties | Select-Object $Properties
    }
    else {
        Get-ADUser -Filter {Name -like $Name -or SamAccountName -like $Name} -Properties $Properties | Select-Object $Properties
    }
}

function ProcessMailbox ($Account) {

    $AccountUPN = $Account.UserPrincipalName
    if (Get-RemoteMailbox $AccountUPN -ErrorAction SilentlyContinue) {

        Write-Host -ForegroundColor 'White' "`nHiding `'$($Account.UserPrincipalName)`' from address lists..."
        Set-RemoteMailbox -Identity $AccountUPN -HiddenFromAddressListsEnabled $true -WhatIf:$WhatIf
            # Uncomment this to prevent email delivery: -AcceptMessagesOnlyFrom $AccountUPN
        
        Write-Host -ForegroundColor 'White' "`nCancelling future calendar meetings..."
        Invoke-Command -Session $O365Session -ScriptBlock {Remove-CalendarEvents -Identity $Using:AccountUPN -CancelOrganizedMeetings -QueryWindowInDays 730 -Confirm:$false -WhatIf:$Using:WhatIf}

        Write-Host -ForegroundColor 'White' "`nSetting mailbox `'$($Account.UserPrincipalName)`' to shared..."
        Invoke-Command -Session $O365Session -ScriptBlock {Set-Mailbox -Identity $Using:AccountUPN -Type Shared -WhatIf:$Using:WhatIf}

        if ($Account.msExchRemoteRecipientType -eq 1) {
            Write-Host -ForegroundColor 'White' "`nUpdating local AD recipient type value from `'1`' to `'97`'"
            Set-ADUser $Account.SamAccountName -Replace @{msExchRemoteRecipientType="97"; msExchRecipientTypeDetails="34359738368"} -WhatIf:$WhatIf
        }
        elseif ($Account.msExchRemoteRecipientType -eq 4) {
            Write-Host -ForegroundColor 'White' "`nUpdating local AD recipient type value from `'4`' to `'100`'"
            Set-ADUser $Account.SamAccountName -Replace @{msExchRemoteRecipientType="100"; msExchRecipientTypeDetails="34359738368"} -WhatIf:$WhatIf
        }
        else {
            Write-Host -ForegroundColor 'Magenta' "`nValue: `'$($Account.msExchRemoteRecipientType)' not valid for recipient type, skipping update..."
            continue
        }
    }
    else {
        Write-Host -ForegroundColor 'Magenta' "`nNo mailbox for `'$AccountUPN`' found!"
    }
}

function RemoveFromGroups ($AccountSAM, $Groups) {

    Write-Host -ForegroundColor 'White' "`nGroup membership:`n"
    $Groups | Out-String
    Write-Host -ForegroundColor 'White' "Total groups: $($Groups.Count)`n"

    foreach ($Group in $Groups) {
        Start-Sleep -Milliseconds 50
        Write-Host -ForegroundColor 'White' "Removing from:" $Group
        Remove-ADGroupMember -Identity $Group -Member $AccountSAM -Confirm:$false -WhatIf:$WhatIf
    }

    try {
        $FilePath = Join-Path -Path $OutputDirectory -ChildPath "UserExit_$($AccountSAM)_Groups.txt"
        Write-Host -ForegroundColor 'Green' "`nSaving to: $FilePath"
        $Groups | Out-File $FilePath -NoClobber -WhatIf:$WhatIf
    }
    catch {
        $FilePath = Join-Path -Path 'C:\Temp' -ChildPath "UserExit_$($AccountSAM)_Groups.txt"
        Write-Host -ForegroundColor 'Yellow' "`nAccess error, falling back to: $FilePath"
        $Groups | Out-File $FilePath -NoClobber -WhatIf:$WhatIf
    }
}

function ProcessExit ($Account) {

    Write-Host -ForegroundColor 'Cyan' "`nUser: $($Account.Name)"
    Start-Sleep 1

    if ($Account.Description -match "Exit Processed") {
        Write-Host -ForegroundColor 'Magenta' "`nAccount exit already processed, skipping..."
        continue
    }

    DeprovisionO365Teams $Account.UserPrincipalName

    $AccountDescription = $Account.Description + " -- Exit Processed: " + (Get-Date).ToShortDateString()
    $ProcessInfo = ("Exit processed " + (Get-Date -Format G) + " by " + ($env:UserName) + ".")

    $AccountSAM = $Account.SamAccountName
    $Groups = @($Account | Select-Object -ExpandProperty Memberof | Get-ADGroup | Sort-Object | Select-Object -ExpandProperty SamAccountName)
    
    if ($null -eq $Groups) {
        Write-Host -ForegroundColor 'Magenta' "`nNo group memberships found!"
    }
    else {
        RemoveFromGroups $AccountSAM $Groups
    }

    if ($Account.Enabled -eq $true) {
        Write-Host -ForegroundColor 'White' "`nDisabling account..."
        Disable-ADAccount -Identity $AccountSAM -Confirm:$false -WhatIf:$WhatIf
    }
    else {
        Write-Host -ForegroundColor 'Magenta' "`nAccount already disabled!"
    }

    ProcessMailbox $Account
    Set-ADUser -Identity $AccountSAM -Description $AccountDescription -Replace @{info="$ProcessInfo`r`n$($Account.info)"} -WhatIf:$WhatIf
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
        [string]$OutputDirectory = "\\NetApp-Prod\Groups\Corp_Services\ICT\ICT Operations\User Offboarding",
        
        [Parameter()]
        [Switch]$Exact = $false,

        [Parameter()]
        [Switch]$NoLog = $($WhatIfPreference),
        
        [Parameter()]
        [Switch]$WhatIf = $($WhatIfPreference)
    )

    function EndUserExitProcess {

        if ($ExchSessionCreated -eq $true) {
            Write-Host -ForegroundColor 'White' "`nClosing on-premise Exchange session..."
            Get-PSSession | Where-Object {$_.ComputerName -eq $ExchangeFQDN} | Remove-PSSession
        }
        if ($O365SessionCreated -eq $true) {
            Write-Host -ForegroundColor 'White' "`nClosing Office 365 Exchange Online session..."
            Get-PSSession | Where-Object {$_.ComputerName -eq 'outlook.office365.com'} | Remove-PSSession
            # Disconnect-ExchangeOnline
        }

        Write-Host -ForegroundColor 'White' "`nClosing Skype for Business Online session..."
        Get-PSSession | Where-Object {$_.ComputerName -like "*lync.com"} | Remove-PSSession

        Write-Host -ForegroundColor 'White' "`nEnd of processing`n"
        
        if ($NoLog -eq $false) {
            Stop-Transcript
        }

        $AccountsArray.Clear()
        $NotMatched.Clear()
        break
    }

    try {
        $ExchangeFQDN = [System.Net.Dns]::GetHostEntry($Exchange).HostName
    }
    catch {
        "Unable to resolve name of on-premise Exchange Server: $($_)"
        break
    }

    $LogTime = Get-Date -UFormat %y%m%d%H%M%S
    $LogPath = Join-Path -Path $OutputDirectory -ChildPath 'Logs'
    $LogName = Join-Path -Path $LogPath -ChildPath "$($LogTime).log"
    
    Start-Transcript -Path $LogName -WhatIf:$NoLog

    Write-Host -ForegroundColor 'White' "`nStarting user exit script`n"
    Write-Host -ForegroundColor 'White' "`nImporting the following identities:`n"
    Write-Output $Identity
    Write-Host -ForegroundColor 'Green' "`nTotal identities imported:" $Identity.Count "`n"

    foreach ($Name in $Identity) {

        if ($Exact) {
            $ExactMatch = Get-ADExchangeInfo -Identity $Name -Exact
            $AccountsArray.Add($ExactMatch)
        }
        else {
            $AccountLookup = (Get-ADExchangeInfo $Name)

            if ($null -ne $AccountLookup) {
                # Foreach loop to deal with multiple return values
                foreach ($UserObject in $AccountLookup) {
                    # Do another lookup to include related Admin and Comms accounts
                    $AdminLookup = Get-ADExchangeInfo -Name *$(${UserObject}.SamAccountName)

                    foreach ($AdminObject in $AdminLookup) {
                        # If array is empty or does not contain the user object, add it
                        if ($AccountsArray.Count -lt 1) {
                            $AccountsArray.Add($AdminObject)
                        }
                        elseif (!($AccountsArray.SamAccountName.Contains($AdminObject.SamAccountName))) {
                            $AccountsArray.Add($AdminObject)
                        }
                    }
                }
            }
            else {
                # If the name is not found, record it and notify 
                $NotMatched.Add($Name)
            }
        }
    }

    if ($AccountsArray.Count -gt 0) {

        Write-Host -ForegroundColor 'White' "`nAccount name matches found:"
        $AccountsArray | Format-Table -Property Name, SamAccountName, UserPrincipalName, Enabled, Description

        Write-Host -ForegroundColor 'Green' "Total accounts matched:" $AccountsArray.Count

        if ($NotMatched.Count -eq 1) {
            Write-Host -ForegroundColor 'Magenta' "`n`nNo account match for:`n"
            Write-Output $NotMatched
        }
        elseif ($NotMatched.Count -gt 1) {
            Write-Host -ForegroundColor 'Magenta' "`n`nNo account matches for $($NotMatched.Count) names, please check input for:`n"
            Write-Output $NotMatched
        }

        if ((Read-Host -Prompt "`n`nRun exit process for these accounts (y/N)?") -eq 'y') {

            if (Get-PSSession | Where-Object {$_.ComputerName -eq $ExchangeFQDN -and $_.State -eq 'Opened'}) {
                Write-Host -ForegroundColor 'White' "`nDetected active on-premise Exchange session..."
            }
            else {
                Write-Host -ForegroundColor 'White' "`nOn-premise Exchange session starting..."
                try {
                    Import-PSSession (New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$ExchangeFQDN/powershell/") -AllowClobber -CommandName "*RemoteMailbox" | Out-Null
                    $Script:ExchSessionCreated = $true
                }
                catch {
                    "Unable to establish session to on-premise Exchange Server: $($_)"
                    EndUserExitProcess
                }
            }

            if (Get-PSSession | Where-Object {$_.ComputerName -eq 'outlook.office365.com' -and $_.State -eq 'Opened'}) {
                Write-Host -ForegroundColor 'White' "Detected active Office 365 Exchange Online session..."
                $Script:O365Session = (Get-PSSession | Where-Object {$_.ComputerName -eq 'outlook.office365.com' -and $_.State -eq 'Opened'} | Select-Object -First 1)
            }
            else {
                # This is a check to see if the environment variable for specifying an admin username exists
                # If so, call Functions-PSStoredCredentials.ps1 and attempt to grab the stored credentials
                # If not, fall back to the standard annoying prompt
                try {
                    # The two lines below should be set in the PowerShell profile:
                    #   $KeyPath = "$Home\Documents\WindowsPowerShell"
                    #   . "$Env:DevPath\Profile\Functions-PSStoredCredentials.ps1"
                    $O365Cred = (Get-StoredCredential -UserName $Env:AdminUPN)
                }
                catch {
                    Write-Host -ForegroundColor 'Magenta' "Admin credentials required!"
                    $O365Cred = (Get-Credential -Message "Enter Office 365 Admin Credentials")
                }
            
                Write-Host -ForegroundColor 'White' "`nOffice 365 Exchange Online session starting..."
                try {
                    $Script:O365Session = (New-PSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/ -ConfigurationName Microsoft.Exchange -Credential $O365Cred -Authentication Basic -AllowRedirection)
                    # $Script:O365Session = Connect-ExchangeOnline -Credential $O365Cred -ShowBanner $false
                    $Script:O365SessionCreated = $true
                }
                catch {
                    "Unable to establish session to Office 365: $($_)"
                    EndUserExitProcess
                }
            }

            function GetSfBSession {Get-PSSession | Where-Object {$_.ComputerName -like "*lync.com"}}
            
            GetSfBSession | Where-Object {$_.State -notlike "Opened"} | ForEach-Object {Remove-PSSession -Session $_ -Verbose}

            if ((GetSfBSession).State -like "Opened") {
                Write-Host -ForegroundColor 'White' "`nDetected active Skype for Business Online session..."
            } else {
                Write-Host -ForegroundColor 'White' "`nSkype for Business Online session starting..."
                $SfbSession = New-CsOnlineSession -Credential $AdminCredential
                Import-PSSession $SfbSession -AllowClobber | Out-Null
            }
            Connect-MsolService -Credential $O365Cred | Out-Null

            Start-Sleep 1
            foreach ($Account in $AccountsArray) {
                ProcessExit $Account
            }
        }

    } else {
        Write-Host -ForegroundColor 'Magenta' "`nNo account name matches found!"
    }

    EndUserExitProcess
}
