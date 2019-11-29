#Requires -Module ActiveDirectory

Function Get-UserLockoutStatus { 
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            Position=0)]
            [ValidateNotNullOrEmpty()]
            [Alias("User")]
            [String]$SamAccountName
    )
 
    Try
    {
        Get-ADUser -Identity $SamAccountName | Out-Null
    }
    Catch [Exception] 
    { 
        Write-Host "$($_.Exception.Message)" -ForegroundColor Red 
        Break 
    } 

    $UserInfo = @()
    $DCs = (Get-ADDomainController -Filter *)

    ForEach ($DC in $DCs) 
    { 
        $AccountStatus = (Get-ADUser -LDAPFilter "(sAMAccountName=$SamAccountName)" -Server $DC.Name -Properties `
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
        Write-Host "`nAccount lockout status for ${SamAccountName}:" -ForegroundColor 'White'
    } 
    $UserInfo | Sort-Object -Property "DC Name" | Format-Table -AutoSize 
}

Export-ModuleMember -Function 'Get-UserLockoutStatus'
