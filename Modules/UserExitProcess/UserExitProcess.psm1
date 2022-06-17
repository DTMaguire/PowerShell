# PowerShell script to export groups for a list of old users, remove them from the groups and disable their accounts
# Version 4.2 - Copyright DM Tech 2019-2022
#
# This script will process user exits by running the following procedure on matched AD accounts:
# - Export a list of group memberships to a text file
# - Remove from all security groups and distribution lists
# - Remove Office 365 licenses and access (via security group removal)
# - Convert the mailbox to shared (if it exists)
# - Cancel future calendar appointments where the mailbox owner is the organiser
# - Optionally, prevent any further email delivery to the mailbox
# - Hide user from the Outlook address book
# - Remove Teams attributes and release assigned phone number
# - Remove from any directly assigned Office 365 cloud groups
# - Move account to a disabled users OU in AD
# - Disable and mark the AD account with "Exit processed"
# - Write transcript of actions to a log file

using namespace System.Collections.Generic
$AccountsArray = [List[PSObject]]::new()
$NotMatched = [List[PSObject]]::new()
$DisabledUsersOU = "OU=_Disabled,OU=Users,OU=LRS,DC=trs,DC=nsw"

function GetADExchangeInfo {
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
        try {
            $Match = (Get-ADUser -Identity $Name -Properties $Properties -ErrorAction SilentlyContinue | Select-Object $Properties)
        }
        catch {
            return $null
        }
    }
    else {
        $Match = (Get-ADUser -Filter {DisplayName -like $Name -or Name -like $Name -or SamAccountName -like $Name} -Properties $Properties | Select-Object $Properties)
    }

    if ($Match) {
        # Trick to remove any carriage returns from the 'Info' field before returning the object
        foreach ($UserObject in $Match) {
            if (!([string]::IsNullOrEmpty($UserObject.Info))) {
                $UserObject.Info = ($UserObject.Info).Trim() -replace '\r\n',' --> '
            }
        }
    }

    return $Match
}

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
                        'DESKLESS',
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
    $TeamsProps = 'UserPrincipalName','LineURI','TenantDialPlan','OnlineVoiceRoutingPolicy'
    $MsolUser = (Get-MsolUser -UserPrincipalName $Identity -ErrorAction SilentlyContinue)
    $TeamsUser = (Get-CsOnlineUser -Identity $Identity -ErrorAction SilentlyContinue | Select-Object $TeamsProps)

    if ($MsolUser) {
                 
        # A Teams/Phone System license is required to remove the Policies and LineURI attribute!
        if ($TeamsUser.LineURI) {

            Write-Host "`nClearing Teams attributes..." -ForegroundColor White

            if ($TeamsUser.LineURI) {
                SetUserLicenses $Identity
                Write-Host "`nReturning phone number to pool: $($TeamsUser.LineURI.split(':')[1])`n" -ForegroundColor Green
                Set-CsUser -Identity $Identity -LineURI $null -EnterpriseVoiceEnabled $false -WhatIf:$WhatIf
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
            Write-Host "`nNo Teams account found for: $Identity" -ForegroundColor Magenta
        }

        $DirectlyAssigned =  ($MsolUser.Licenses | Where-Object {!($_.GroupsAssigningLicense)}).AccountSkuID
        
        if ($DirectlyAssigned) {

            Write-Host "`nDirectly assigned licenses to be removed:`n" -ForegroundColor White
            Format-List -InputObject $DirectlyAssigned

            if (!$WhatIf) {
                $DirectlyAssigned | ForEach-Object {
                    Set-MsolUserLicense -UserPrincipalName $Identity -RemoveLicenses $_
                    # No -WhatIf option exists for this cmdlet!
                }   
            }
        }
    }
    else {
        Write-Host "No matching Azure AD account found!" -ForegroundColor Magenta
    }
    Start-Sleep 1
}

function ProcessMailbox ($Account) {

    $AccountUPN = $Account.UserPrincipalName
    if (Get-RemoteMailbox $AccountUPN -ErrorAction SilentlyContinue) {

        Write-Host -ForegroundColor 'White' "`nHiding `'$($Account.UserPrincipalName)`' from address lists..."
        Set-RemoteMailbox -Identity $AccountUPN -HiddenFromAddressListsEnabled $true -WhatIf:$WhatIf
            # Uncomment this to prevent email delivery: -AcceptMessagesOnlyFrom $AccountUPN
        
        if (Get-Mailbox -Identity $AccountUPN -ErrorAction SilentlyContinue) {

            Write-Host -ForegroundColor 'White' "`nCancelling future calendar meetings..."
            #Invoke-Command -Session $O365Session -ScriptBlock {
                Remove-CalendarEvents -Identity $AccountUPN -CancelOrganizedMeetings -QueryWindowInDays 730 -Confirm:$false -WhatIf:$WhatIf
            #}
    
            Write-Host -ForegroundColor 'White' "`nSetting mailbox `'$($Account.UserPrincipalName)`' to shared..."
            #Invoke-Command -Session $O365Session -ScriptBlock {
                Set-Mailbox -Identity $AccountUPN -Type Shared -WhatIf:$WhatIf
            #}
        }

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
        Write-Host -ForegroundColor 'Magenta' "`nAccount exit already processed, continuing..."
        continue
    }
    
    DeprovisionO365Teams $Account.UserPrincipalName

    $AccountSAM = $Account.SamAccountName
    $Groups = @($Account | Select-Object -ExpandProperty Memberof | Get-ADGroup | Sort-Object | Select-Object -ExpandProperty SamAccountName)
    
    if ($Groups) {
        RemoveFromGroups $AccountSAM $Groups
    }
    else {
        Write-Host -ForegroundColor 'Magenta' "`nNo group memberships found!"
    }

    if ($Account.Enabled -eq $true) {
        Write-Host -ForegroundColor 'White' "`nDisabling account..."
        Disable-ADAccount -Identity $AccountSAM -Confirm:$false -WhatIf:$WhatIf
    }
    else {
        Write-Host -ForegroundColor 'Magenta' "`nAccount already disabled!"
    }

    ProcessMailbox $Account

    $AccountDescription = $Account.Description + " -- Exit Processed: " + (Get-Date).ToShortDateString()
    $ProcessInfo = ("Exit processed " + (Get-Date -Format G) + " by " + ($env:UserName) + ".")

    Set-ADUser -Identity $AccountSAM -Description $AccountDescription -Replace @{info="$ProcessInfo`r`n$($Account.info)"} -WhatIf:$WhatIf

    if ((Read-Host -Prompt "`nMove account to $DisabledUsersOU (y/N)? Don't do this for service accounts!") -eq 'Y') {
        Get-ADUser -Identity $AccountSAM | Move-ADObject -TargetPath $DisabledUsersOU -WhatIf:$WhatIf
    }
}

function EndUserExitProcess {

    if ($ExchangeSession) {Disconnect-ExchangeSession}
    if (Get-ExchangeOnline) {Disconnect-ExchangeOnline -Confirm:$false}
    if ($MicrosoftTeams) {Disconnect-MicrosoftTeams -Confirm:$false}
    
    if (!($NoLog)) {
        Stop-Transcript
    }

    $AccountsArray.Clear()
    $NotMatched.Clear()

    Write-Host -ForegroundColor 'White' "`nEnd of processing"
}

function Start-UserExitProcess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        [Alias("User")]
        [string[]]$Identity,

        [Parameter(Position=1)]
        [ValidateScript({
            if (Test-Path -Path $_) {
                $true
            }
            else {
                throw "Unable to access: $($_)"
            }                
        })]
        [Alias("OutputDir")]
        [string]$OutputDirectory = "\\NetApp-Prod\Groups\Corp_Services\ICT\ICT Operations\User Offboarding",
        
        [Parameter(ValueFromPipeline,Position=2)]
        [pscredential]$Credential = $AdminCredential,

        [Parameter()]
        [Switch]$Exact = $false,

        [Parameter()]
        [Switch]$NoLog = $($WhatIfPreference),
        
        [Parameter()]
        [Switch]$WhatIf = $($WhatIfPreference)
    )

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

            $ExactMatch = GetADExchangeInfo -Identity $Name -Exact
            if ($ExactMatch) {
                $AccountsArray.Add($ExactMatch)
            }
            else {
                # If the name is not found, record it and notify 
                $NotMatched.Add($Name)
            }
        }
        else {
            $AccountLookup = GetADExchangeInfo -Name "*$Name*"

            if ($AccountLookup) {
                # Warn about off-boarding the other matched accounts!
                if ($AccountLookup.Count -gt 1) {
                    Write-Warning "More than one account matched found for `'$Name`' - check output before proceeding!"
                    Start-Sleep 1
                }
                 # Foreach loop to deal with multiple return values, but will run once with only one value
                foreach ($UserObject in $AccountLookup) {
                    # If array is empty or does not contain the user object, add it
                    if (!($AccountsArray.Count) -or !($AccountsArray.Find({$args.SamAccountName -eq $UserObject.SamAccountName}))) {
                        $AccountsArray.Add($UserObject)
                    }
                } 
            }
            else {
                # If the name is not found, record it to display later
                $NotMatched.Add($Name)
            }
        }
    }

    if ($AccountsArray.Count -gt 0) {

        Write-Host -ForegroundColor 'White' "`nAccount name matches found:"
        $AccountsArray | Format-Table -Property Name,SamAccountName,UserPrincipalName,Enabled,Description

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

            Write-Host -ForegroundColor 'White' "`nConnecting to online services..."

            if (!$Credential) {
                $Credential = Get-Credential -Message "Enter admin UPN and password for Exchange and Office 365 services:"
            }
            try {
                Connect-MsolService -Credential $Credential
                $Script:ExchangeSession = Connect-ExchangeSession -CommandName "*RemoteMailbox" -Credential $Credential
                Connect-ExchangeOnline -ShowBanner:$false -Credential $Credential -CommandName "*Mailbox","*Calendar*"
                # Should no longer need this line if it's defined in the .PSD file:
                # Import-Module -Name MicrosoftTeams -DisableNameChecking 
                $Script:MicrosoftTeams = Connect-MicrosoftTeams -Credential $Credential #-CommandName "Get-Cs*","Grant-Cs*","Set-Cs*" 
            }
            catch {
                EndUserExitProcess
                throw $($_)
            }
            
            Start-Sleep 1

            foreach ($Account in $AccountsArray) {
                ProcessExit $Account
            }
        }

    }
    else {
        Write-Host -ForegroundColor 'Magenta' "`nNo account name matches found!"
    }
    EndUserExitProcess
}