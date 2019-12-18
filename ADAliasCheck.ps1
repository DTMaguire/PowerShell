# PowerShell script to compare user Alias/UPN/Email addresses from the directory and write to CSV
# Generally you want all of the attributes to match to avoid confusion for users
#
# Version 1.0 - Copyright DM Tech 2019

#Requires -Modules ActiveDirectory
$ExchFQDN = [System.Net.Dns]::GetHostByName('sydawsexchange').HostName
$ExchSessionCreated = $false
$OutCSV = "$Env:DevPath\Output\MismatchedEnabledAliases.csv"

if (Get-PSSession | Where-Object {$_.ComputerName -eq $ExchFQDN -and $_.State -eq "Opened"}) {
    Write-Host -ForegroundColor 'White' "`nDetected active on-premise Exchange session..."
} else {
    Write-Host -ForegroundColor 'White' "`nOn-premise Exchange session starting..."
    Import-PSSession (New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$ExchFQDN/powershell/") -AllowClobber -CommandName "*RemoteMailbox" | Out-Null
    $ExchSessionCreated = $true
}

Write-Host -ForegroundColor 'Cyan' "`nBuilding a list of accounts, please wait a moment...`n"
$UserList = (Get-ADUser -Filter 'Enabled -eq $True' | Select-Object -ExpandProperty SamAccountName | Get-RemoteMailbox -Erroraction 'SilentlyContinue' | Select-Object Name,SamAccountName,Alias,UserPrincipalName,PrimarySMTPAddress,@{n='Date';e={(Get-Date).ToShortDateString()}})
$MismatchedUsers = @()

foreach ($User in $UserList) {
    $AliasCheck = $User.UserPrincipalName -replace '(@[A-Za-z.]+)',''
    $SMTPCheck = $User.PrimarySMTPAddress -replace '(@[A-Za-z.]+)',''
    if ($User.Alias -ne $AliasCheck -or $User.Alias -ne $SMTPCheck) {
        $MismatchedUsers += $User
        Write-Host -ForegroundColor 'Magenta' "`nAlias/UPN/SMTP mismatch for: $($User.Alias) - $AliasCheck - $SMTPCheck `n"
        Start-Sleep 1
    } else {
        Write-Host -ForegroundColor 'Green' "Alias/UPN/SMTP match for: $($User.Alias) - $AliasCheck - $SMTPCheck"
        Start-Sleep -Milliseconds 10
    }
}

Write-Host -ForegroundColor 'Cyan' "`n`nList of enabled accounts with mismatches:"
Start-Sleep 1
Write-Output $MismatchedUsers
Write-Host -ForegroundColor 'Cyan' "`nNumber of accounts with mismatches:" $MismatchedUsers.Count
Write-Host -ForegroundColor 'Cyan' "`nTotal accounts checked:" $UserList.Count
Write-Host -ForegroundColor 'White' "`nWriting to file:" $OutCSV
$MismatchedUsers | Export-Csv -NoTypeInformation -Path $OutCSV -Append
Invoke-Item $OutCSV

if ($ExchSessionCreated) {
    Write-Host -ForegroundColor 'White' "`nClosing on-premise Exchange session..."
    Get-PSSession | Where-Object {$_.ComputerName -eq $ExchFQDN} | Remove-PSSession
}
