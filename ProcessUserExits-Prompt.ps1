# PowerShell script to export groups for a list of old users, remove them from the groups and disable their accounts
# Version 2.0 - Copyright DM Tech 2019
# Still a work in progress - To Do:
#   Extend input to allow reading of users from text and CSV files
#   Create parameters and turn into module

#Requires -Modules ActiveDirectory

$NameList = @()
$AccountsArray = @()
$OutputDir = "D:\Scripts\Output\UserExits"
$ExchFQDN = "address.goes.here"
$SessionCreated = $false

function GetUserAccount {
    param ($Name)
    Get-ADUser -Filter {Name -eq $Name -or SamAccountName -eq $Name} -Properties * | Select-Object Name, SamAccountName, UserPrincipalName, Memberof, Enabled
}

function SetSharedMailbox {
    param ($UserSAM)
    if(Get-RemoteMailbox $UserSAM -ErrorAction SilentlyContinue) {
        Write-Host -ForegroundColor 'White' "`nSet mailbox for `'$UserSAM`' to shared (y/N)? " -NoNewline
        if ((Read-Host) -eq 'y') {
            Set-RemoteMailbox -Identity $UserSAM -HiddenFromAddressListsEnabled $True #-WhatIf
        }
    } else {
        Write-Host -ForegroundColor 'Magenta' "`nNo mailbox for `'$UserSAM`' found!"
    }
}
function RemoveFromGroups {
    param ($AccountSAM, $Groups)
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
function ProcessExit {
    param ($Account)

    $AccountSAM = $Account.SamAccountName
    Write-Host -ForegroundColor 'Cyan' "`nUser: $($Account.Name)"
    Start-Sleep 1
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
    SetSharedMailbox $AccountSAM
}

Write-Host -ForegroundColor 'White' "`nStarting user exit script...`n"

do {
    $ReadInput = (Read-Host -Prompt "Enter usernames seperated by commas, or `'q`' to quit")
    if ($ReadInput -eq 'q') {
        exit
    }
} until ($ReadInput -match '[\w.]+')

$NameList = @(($ReadInput).Split(",").Trim())

Write-Host -ForegroundColor 'White' "`n`nImporting the following users:`n"
Write-Output $NameList
Write-Host -ForegroundColor 'Green' "`n`nTotal names imported: " $NameList.Count "`n"

foreach ($Name in $NameList) {
    $AccountsArray += (GetUserAccount $Name)
}

if ($AccountsArray.Length -gt 0) {

    if (Get-PSSession | Where-Object {$_.ComputerName -eq $ExchFQDN}) {
        Write-Host -ForegroundColor 'White' "`nDetected active Exchange session..."
    } else {
        Write-Host -ForegroundColor 'White' "`nRemote Exchange session starting..."
        Import-PSSession (New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$ExchFQDN/powershell/") -AllowClobber -CommandName "*-RemoteMailbox"
        $SessionCreated = $true
    }
    
    Write-Host -ForegroundColor 'White' "`nAccount name matches found:" -NoNewline
    $AccountsArray | Format-Table -Property Name, SamAccountName, UserPrincipalName, Enabled

    Write-Host -ForegroundColor 'Green' "Total accounts matched: " $AccountsArray.Count
    
    if ((Read-Host -Prompt "`n`nRun exit process for these accounts (y/N)?") -eq 'y') {
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