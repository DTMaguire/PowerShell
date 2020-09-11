# Connect to on-premise Exchange and SfB/Teams in Office 365
# Uses $AdminCredential set in the PowerShell profile via the Get-StoredCredential function
# Requires -Modules ActiveDirectory,SkypeOnlineConnector

# Session functions
function Get-ExchSession {
    Get-PSSession | Where-Object {$_.ConfigurationName -eq 'Microsoft.Exchange'}
}
function Get-SfBSession {
    Get-PSSession | Where-Object {$_.ComputerName -like "*lync.com"}
}

# Connect to on-premise Exchange Server function
function Connect-Exchange {

    begin {
        $ADDomain = Get-ADDomain
        $ExchangeFQDN = ((Get-ADObject -LDAPFilter "(objectClass=msExchExchangeServer)" -SearchBase "CN=Configuration,$($ADDomain.DistinguishedName)") | Where-Object {$_.ObjectClass -eq 'msExchExchangeServer'}).Name + '.' + ($ADDomain).DNSRoot
    }

    process {

        if (Get-PSSession | Where-Object {$_.ConfigurationName -eq 'Microsoft.Exchange' -and $_.State -eq 'Opened'}) {
            Write-Warning "Detected active on-premise Exchange session"
        }
        elseif ($ExchangeFQDN) {

            try {
                Import-PSSession (New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$ExchangeFQDN/powershell/") -AllowClobber -DisableNameChecking 
            }
            catch {
                "Unable to establish session to on-premise Exchange Server: $($_)"
            }
        }
        else {
            Write-Error "No Exchange Server found"
        }
    }
}

# Connect cloud service functions
function Connect-SfBOnline {
    if ((Get-SfBSession).State -notmatch 'Opened') {

        try {
            $Script:SfBSession = New-CsOnlineSession -Credential $AdminCredential
        
            Import-PSSession $SfBSession -Verbose
            Enable-CsOnlineSessionForReconnection   
        }
        catch {
            "Unable to establish session to Skype for Business Online. This feature requires the Skype for Business Online PowerShell Module: $($_)"
        }
        
    } else {
        Write-Warning "Existing Skype for Business Online session detected - to close the session, run: 'Remove-SfBOnline'"
    }
}

# Disconnect functions
function Remove-SfBOnline {
    param ($SfBSession)

    if ($SfBSession) {
        try {
            Remove-PSSession $SfBSession
        }
        catch {
            Write-Warning "Unable to remove: $SfBSession"
            return
        }
    } else {
        $SfBSession = Get-SfBSession
        Remove-PSSession $SfBSession
    }

    $SfBModule = (Get-Command -Name Get-CsOnlineUser -ErrorAction SilentlyContinue).Source
    if ($SfBModule) {
        Remove-Module $SfBModule
    }
}

function Remove-Exchange {
    param ($ExchSession)

    if ($ExchSession) {
        try {
            Remove-PSSession $ExchSession
        }
        catch {
            Write-Warning "Unable to remove: $ExchSession"
            return
        }
    } else {
        $ExchSession = Get-ExchSession
        Remove-PSSession $ExchSession
    }

    $ExchModule = (Get-Command -Name Get-RemoteMailbox -ErrorAction SilentlyContinue).Source
    if ($ExchModule) {
        Remove-Module $ExchModule
    }
}
