
$ExchFQDN = [System.Net.Dns]::GetHostByName('sydawsexchange').HostName
$ExchSessionCreated = $false
$TargetDomain = 'NSWLandRegistryServices.mail.onmicrosoft.com'

$NewUsers = @('Lindell Galaroza','Matthew Emanuel','Michael Cerna','Nick Craig')

if (Get-PSSession | Where-Object {$_.ComputerName -eq $ExchFQDN -and $_.State -eq "Opened"}) {
    Write-Host -ForegroundColor 'White' "`nDetected active on-premise Exchange session..."
} else {
    Write-Host -ForegroundColor 'White' "`nOn-premise Exchange session starting..."
    Import-PSSession (New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri `
        "http://$ExchFQDN/powershell/") -AllowClobber -CommandName "*RemoteMailbox" | Out-Null
    $Script:ExchSessionCreated = $true
}

foreach ($User in $NewUsers) {
    
    $SAM = (($User.Substring(0,1) + ($User.Split(' ')[-1])).ToLower())
    $ADUser = (Get-ADUser -Identity $SAM -Properties TargetAddress)
    $UPN = (($ADUser).UserPrincipalName)
    $Target = ($UPN -replace $Env:UPNSuffix,$TargetDomain)

    if ($null -eq (Get-ADUser -Identity $SAM -Properties TargetAddress).TargetAddress) {
            Enable-RemoteMailbox $UPN -RemoteRoutingAddress $Target
            Write-Host -ForegroundColor 'Cyan' "`nEnabling Remote Mailbox - Target Address:" $Target
        } else {
            Set-RemoteMailbox $UPN -RemoteRoutingAddress $Target -EmailAddressPolicyEnabled $true
            Write-Host -ForegroundColor 'Cyan' "`nUpdating Remote Mailbox - Target Address:" $Target
        }
        Start-Sleep 1
}

if ($ExchSessionCreated -eq $true) {
    Write-Host -ForegroundColor 'White' "`nClosing on-premise Exchange session..."
    Get-PSSession | Where-Object {$_.ComputerName -eq $ExchFQDN} | Remove-PSSession
}