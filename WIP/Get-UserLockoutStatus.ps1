#Requires -Module ActiveDirectory

Function Get-UserLockoutStatus { 
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,Position=0)]
        [String]$TargetUserName
    )
<#    
    Try
    { 
        $DCs = [System.DirectoryServices.ActiveDirectory.domain]::GetDomain(( 
        (New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext('Domain', $TargetDomainName)))) | `
            ForEach-Object { $_.DomainControllers } | Select-Object Name, SiteName 
    } 
    Catch [Exception] 
    { 
        Write-Host "$($_.Exception.Message) Please enter domain name in FQDN format; eg TargetDomainName.co.uk  " -ForegroundColor Red 
        Break 
    } 
#>

    $UserInfo = @()
    $DCs = (Get-ADDomainController -Filter *)
    ForEach ($DC in $DCs) 
    { 
<#
        $DCOnly = ForEach-Object {$DC.name} #The % sign ensures that only the server name is selected. 
        #If not included, it will be displayed in the format @{Name=xxx,Site=xxx};  
        #popping error when used in the Get-ADComputer command below 
        $DCName = (Get-ADComputer -LDAPFilter "(DNSHostName=$DCOnly)" -Server $DCOnly).Name #Get DCs in Name format, not FQDN 
        Try
        { 
            $dn = (Get-ADUser -Identity $TargetUserName -server $DCOnly -ErrorAction Stop).DistinguishedName     
        } 
        Catch [Exception] 
        { 
            Write-Host "$($_.Exception.Message) Please resolve the error and try again " -ForegroundColor Red 
            Break 
        }
#>
        $AccountStatus = (Get-ADUser -LDAPFilter "(sAMAccountName=$TargetUserName)" -Server $DC.Name -Properties `
            LockedOut,badPwdCount,LastBadPasswordAttempt,PasswordLastSet,AccountLockoutTime -ErrorAction Stop | `
            Select-Object @{Label = "DC Name";Expression = {$DC.Name}}, 
                @{Label = "Site"; Expression = {$DC.Site}}, 
                @{Label = "User State"; Expression = {If ($_.LockedOut -eq  'True') {'Locked'} Else {'Not Locked'}}},
                @{Label = "Bad Pwd Count"; Expression = {If (($_.badPwdCount -eq '0') -or ($null -eq $_.badPwdCount)) {'0'} Else {$_.badPwdCount}}}, 
                @{Label = "Last Bad Pwd"; Expression = {If ($null -eq $_.LastBadPasswordAttempt) {'None'} Else {$_.LastBadPasswordAttempt}}}, 
                @{Label = "Pwd Last Set"; Expression = {If ($null -eq $_.PasswordLastSet) {'Password Must Change'} Else {$_.PasswordLastSet}}}, 
                @{Label = "Lockout Time"; Expression = {If ($null -eq $_.AccountLockoutTime) {'N/A'} Else {$_.AccountLockoutTime}}})
        $UserInfo += $AccountStatus
    } 
    If ($UserInfo) 
    {
        Write-Host "Account lock out status for $TargetUserName is displayed below:" -ForegroundColor Yellow
    } 
    $UserInfo | Sort-Object -Property "DC Name" | Format-Table -AutoSize 
}

Get-UserLockoutStatus -TargetUserName 
