using namespace System.Collections.Generic
$Members = [List[PSObject]]::new()
$AdminGroups = (Get-ADGroup -Filter 'SamAccountName -like "*Admin*"' | Where-Object {$_.SamAccountName -notmatch '^(AZ|AWS|NAS QS|ROLE_|SAN QS Drive|SAP|SEC BitBucket|SEC Confluence|SEC Jira)'} | Sort-Object -Property SamAccountName)

foreach ($Group in $AdminGroups) {
    #$Members = [List[PSObject]]::new()
    $Users = (Get-ADGroupMember -Identity $Group -Recursive | Where-Object { $_.ObjectClass -eq 'User'} | Select-Object -ExpandProperty SamAccountName)
    foreach ($User in $Users) {
        $Members.Add((Get-ADUser -Identity $User -Properties Title,Description | Select-Object Name,SamAccountName,UserPrincipalName,Enabled,Title,Description))
    }
    $GroupName = $Group.SamAccountName
    Export-Csv -InputObject $Members -NoTypeInformation -Path ((Split-Path $Env:DevPath -Parent) + "\Output\AdminGroups\$GroupName.csv")
    $Members.Clear()
}

<#
ROLE Access Network Admin
ROLE ADFS Server Admin
ROLE Azure Group Admin
ROLE Backup Admin
ROLE BitBucket Admin
ROLE Call Centre Admin
ROLE Citrix Admin
ROLE Comms Admin
ROLE Confluence Admin
ROLE Core Network Admin
ROLE Desktop Admin
ROLE Desktop Admin - CL
ROLE DHCP Admin
ROLE DIIMS Admin
ROLE DNS Admin
ROLE Domain Admin
ROLE Enterprise Admin
ROLE Group Policy Admin
ROLE HelpDesk Operator Admin
ROLE HelpDesk Supervisor Admin
ROLE Hyper-V Admin
ROLE JIRA Admin
ROLE Jira System Admin
ROLE KiteWorks Admin
ROLE Linux Admin
ROLE Linux Dev Admin
ROLE MDM Server Admin
ROLE NAS Admin
ROLE NOS Admin
ROLE RHEVM Admin
ROLE RHEVM RO ADMIN
ROLE SAP Server Admin
ROLE SCOM Admin
ROLE SCVMM 2012 Administrators
ROLE SCVMM Library Admin
ROLE Server Admin
ROLE Service Desk Admin
ROLE SQL Admin
ROLE Storage Admin
ROLE TRIM TRS Admin
ROLE Versent REVM Admins
ROLE VMS Admin
ROLE WiFi Admins
ROLE_ADMIN_ICT
ROLE_ADMIN_ICT
ROLE_ADMIN_ICT
ROLE_ADMIN_TPS
ROLE_ADMIN_TPS
ROLE_ADMIN_TPS
ROLE_PORTAL_ADMIN
ROLE_PORTAL_ADMIN
ROLE_PORTAL_ADMIN
#>