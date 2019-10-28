# PowerShell script to export groups for a list of old users, remove them from the groups and disable their accounts
# Version 2.0 - Copyright DM Tech 2019
# Still a work in progress - To Do:
#   Extend input to allow reading of users from text and CSV files
#   Create parameters and turn into module

#Requires -Modules ActiveDirectory

$NameList = @()
$AccountsArray = @()
$NotMatched = @()
$OutputDir = "\\NAS-QS-TRS\Groups\Corp_Services\ICT\ICT Operations\User Offboarding"
$ExchFQDN = "sydawsexchange.trs.nsw"
$SessionCreated = $false

function GetUserAccount ($Name) {

    Get-ADUser -Filter {Name -like $Name -or SamAccountName -like $Name} -Properties * | `
    Select-Object Name, SamAccountName, UserPrincipalName, Memberof, Enabled, Description, Info
}

function SetSharedMailbox ($AccountSAM) {

    if(Get-RemoteMailbox $AccountSAM -ErrorAction SilentlyContinue) {
        Set-RemoteMailbox -Identity $AccountSAM -AcceptMessagesOnlyFrom $AccountSAM -HiddenFromAddressListsEnabled $True #-WhatIf
        Write-Host -ForegroundColor 'White' "`nSet mailbox for `'$AccountSAM`' to shared (y/N)? " -NoNewline
        if ((Read-Host) -eq 'y') {
            Set-ADUser -Identity $AccountSAM -Replace @{msExchRemoteRecipientType=100;msExchRecipientTypeDetails=34359738368} #-WhatIf
        }
    } else {
        Write-Host -ForegroundColor 'Magenta' "`nNo mailbox for `'$AccountSAM`' found!"
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

    $Account.Description += (" -- Exit Processed: " + (Get-Date).ToShortDateString() )
    $ProcessInfo = ("Exit processed " + (Get-Date -Format G) + " by " + ($env:UserName) + ".")
    Set-ADUser -Identity $AccountSAM -Description $Account.Description -Replace @{info="$ProcessInfo`r`n$($Account.info)"}

    SetSharedMailbox $AccountSAM
}

Write-Host -ForegroundColor 'White' "`nStarting user exit script`n"
<#
do {
    $ReadInput = (Read-Host -Prompt "Enter usernames seperated by commas, or `'q`' to quit")
    if ($ReadInput -eq 'q') {
        exit
    }
} until ($ReadInput -match '[\w.]+')

$NameList = @(($ReadInput).Split(",").Trim())
#>
$NameList = @((Get-Content -Path "D:\Scripts\Input\AWS-OldUsers_Remaining.txt") | Where-Object {$_ -ne "Jonathan Fan"})
#$NameList += "Hugh Jorgan", "Mike Hunt", "Phil McCracken"

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
        if (Get-PSSession | Where-Object {$_.ComputerName -eq $ExchFQDN}) {
            Write-Host -ForegroundColor 'White' "`nDetected active Exchange session..."
        } else {
            Write-Host -ForegroundColor 'White' "`nRemote Exchange session starting..."
            Import-PSSession (New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$ExchFQDN/powershell/") -AllowClobber -CommandName "*-RemoteMailbox" | Out-Null
            $SessionCreated = $true
        }
        Start-Sleep 1    
        foreach ($Account in $AccountsArray) {
            ProcessExit $Account
        }
    }
    
} else {
    Write-Host -ForegroundColor 'Magenta' "`nNo account name matches found!"
}

if ($SessionCreated -eq $true) {
    Write-Host -ForegroundColor 'White' "`nClosing remote Exchange session..."
    Get-PSSession | Where-Object {$_.ComputerName -eq $ExchFQDN} | Remove-PSSession
    $SessionCreated = $false
}

Write-Host -ForegroundColor 'White' "`nEnd of processing`n"
