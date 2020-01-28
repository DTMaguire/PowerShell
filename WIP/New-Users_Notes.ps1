First attempt:
$NewUsers | ForEach-Object {New-ADUser -Instance $CopyUser -GivenName ($_.Split(' ')[0]) -Surname ($_.Split(' ')[1]) -Name $_ -SamAccountName ($_.Substring(0,1) + ($_.Split(' ')[1])).ToLower() -UserPrincipalName ($_.Split(' ') -join '.') -AccountPassword (ConvertTo-SecureString -AsPlainText "January2020" -Force) -Path ($CopyUser.DistinguishedName.Replace('CN=Courtney Funnell,','')) -Enabled $True}


$CopyUser = (Get-ADUser -Identity CFunnell -Properties City,Company,Country,Department,Description,DisplayName,Manager,MemberOf,Office,PostalCode,State,StreetAddress,Title)

$CopyGroups = (Get-ADUser -Identity $CopyUser.SamAccountName -Properties MemberOf | Select-Object -ExpandProperty MemberOf | Get-ADGroup)

$NewUsers | ForEach-Object {New-ADUser -AccountPassword (ConvertTo-SecureString -AsPlainText "January2020" -Force) -ChangePasswordAtLogon $True -DisplayName $_ -Enabled $True -GivenName ($_.Split(' ')[0]) -HomeDirectory ("\\nas-qs-trs\users\" + ($_.Substring(0,1) + ($_.Split(' ')[1])).ToLower()) -HomeDrive 'H:' -Instance $CopyUser -Path ($CopyUser.DistinguishedName.Split(',',2)[1]) -SamAccountName (($_.Substring(0,1) + ($_.Split(' ')[1])).ToLower()) -Surname ($_.Split(' ')[1]) -UserPrincipalName ($_.Replace(' ','.') + '@' + $Env:UPNSuffix) -WhatIf}


$NewUsers | ForEach-Object {New-ADUser -AccountPassword (ConvertTo-SecureString -AsPlainText "January2020" -Force) -ChangePasswordAtLogon $True -DisplayName $_ -Enabled $True -GivenName ($_.Split(' ')[0]) -HomeDirectory ("\\nas-qs-trs\users\" + ($_.Substring(0,1) + ($_.Split(' ')[1])).ToLower()) -HomeDrive 'H:' -Instance $ADInstance -Path ($ADInstance.DistinguishedName.Split(',',2)[1]) -SamAccountName (($_.Substring(0,1) + ($_.Split(' ')[1])).ToLower()) -Surname ($_.Split(' ')[1]) -UserPrincipalName ($_.Replace(' ','.') + '@' + $Env:UPNSuffix) -WhatIf}

$NewUsers | ForEach-Object { }
foreach ($User in $NewUsers) {$CopyGroups | ForEach-Object {Add-ADGroupMember -Identity $_ -Members ($User.Substring(0,1) + ($User.Split(' ')[1])) -join ',' -WhatIf}}

foreach ($Prop in $Props) {if ($null -ne $Prop) {($UserInstance).$Prop = ($DM).$Prop}}

QSQ Liverpool


#Tested and working:
$TestUsers | ForEach-Object { 
    #Given      
    ($_.Split(' ')[0])
    #HomeDir    
    ("\\nas-qs-trs\users\" + ($_.Substring(0,1) + ($_.Split(' ')[1])).ToLower())
    #OU         
    ($CopyUser.DistinguishedName.Split(',',2)[1]) # Split the string into an array of 2 elements at the first ',' then select the element at array index [1]
    #SAM        
    (($_.Substring(0,1) + ($_.Split(' ')[-1])).ToLower())
    #SurName
    ($_.Split(' ')[1])
    #UPN        
    (($_.Replace(' ','.') + '@' + $Env:UPNSuffix).ToLower()) }


Testing:    
$Description = $CopyUser.Description            
$Department = $CopyUser.Department
$Title = $CopyUser.Title
$Office = $CopyUser.Office

$UpdateUser = Get-ADUser $SAM -Properties Description, Department, Title, Office
$UpdateUser.Description = $user.TitleDescription
$UpdateUser.Department = $user.DepartmentName
$UpdateUser.Title = $user.TitleDescription
$UpdateUser.Office = $user.BranchName
Set-ADUser -Instance $userupdate


AccountExpirationDate                : 
accountExpires                       : 9223372036854775807
AccountLockoutTime                   : 
AccountNotDelegated                  : False
AllowReversiblePasswordEncryption    : False
AuthenticationPolicy                 : {}
AuthenticationPolicySilo             : {}
BadLogonCount                        : 0
badPasswordTime                      : 132233350849367048
badPwdCount                          : 0
c                                    : AU
CannotChangePassword                 : False
CanonicalName                        : trs.nsw/TitleCo/Users/Production Users/Titling and Plan Services/Titling and Plan Services/Courtney Funnell
Certificates                         : {}
City                                 : Sydney
CN                                   : Courtney Funnell
co                                   : Australia
codePage                             : 0
Company                              : NSW LRS
CompoundIdentitySupported            : {}
Country                              : AU
countryCode                          : 36
Created                              : 28/04/2017 8:48:57 AM
createTimeStamp                      : 28/04/2017 8:48:57 AM
Deleted                              : 
Department                           : DPC/Land XML Team
Description                          : Title & Plan Officer
DisplayName                          : Courtney Funnell
DistinguishedName                    : CN=Courtney Funnell,OU=Titling and Plan Services,OU=Titling and Plan Services,OU=Production 
                                       Users,OU=Users,OU=TitleCo,DC=trs,DC=nsw
Division                             : 
DoesNotRequirePreAuth                : False
dSCorePropagationData                : {23/12/2019 1:04:59 PM, 1/01/1601 11:00:01 AM}
EmailAddress                         : Courtney.Funnell@nswlrs.com.au
EmployeeID                           : 
EmployeeNumber                       : 
Enabled                              : True
Fax                                  : 
GivenName                            : Courtney
HomeDirectory                        : \\nas-qs-trs\users\cfunnell
HomedirRequired                      : False
HomeDrive                            : H:
HomePage                             : 
HomePhone                            : 
Initials                             : 
instanceType                         : 4
isDeleted                            : 
KerberosEncryptionType               : {}
l                                    : Sydney
LastBadPasswordAttempt               : 13/01/2020 7:38:04 AM
LastKnownParent                      : 
lastLogoff                           : 0
lastLogon                            : 132235939277981371
LastLogonDate                        : 16/01/2020 7:39:09 AM
lastLogonTimestamp                   : 132235943495560302
legacyExchangeDN                     : /o=TRS NSW/ou=External (FYDIBOHF25SPDLT)/cn=Recipients/cn=776436d8e1b548d68222883f699c6bef
LockedOut                            : False
lockoutTime                          : 0
logonCount                           : 204
LogonWorkstations                    : 
mail                                 : Courtney.Funnell@nswlrs.com.au
mailNickname                         : Courtney.Funnell
Manager                              : 
MemberOf                             : {CN=NAS QS G TRS TCD TRAINING- read access,OU=Security,OU=Groups,OU=TitleCo,DC=trs,DC=nsw, CN=All 175 
                                       Liverpool Staff,OU=Distribution Lists,OU=Groups,OU=TitleCo,DC=trs,DC=nsw, CN=SEC Jira NSW LRS DRS Digital 
                                       Packet Workflow Examiner,OU=Jira,OU=Groups,OU=TitleCo,DC=trs,DC=nsw, CN=SEC Jira NSW LRS Contact Centre 
                                       Task Manager Examiner,OU=Jira,OU=Groups,OU=TitleCo,DC=trs,DC=nsw...}
MNSLogonAccount                      : False
MobilePhone                          : 
Modified                             : 16/01/2020 7:41:33 AM
modifyTimeStamp                      : 16/01/2020 7:41:33 AM
mS-DS-ConsistencyGuid                : {250, 195, 103, 79...}
msDS-ExternalDirectoryObjectId       : User_e01c39df-38b5-44b8-9b41-078ca7dcfb94
msDS-User-Account-Control-Computed   : 0
msExchArchiveQuota                   : 104857600
msExchArchiveWarnQuota               : 94371840
msExchDumpsterQuota                  : 31457280
msExchDumpsterWarningQuota           : 20971520
msExchELCMailboxFlags                : 2
msExchMailboxGuid                    : {9, 175, 83, 194...}
msExchPoliciesIncluded               : {1e03a903-0295-447d-bb64-4edac84184b7, {26491cfc-9e50-4857-861b-0cb8df22b5d7}}
msExchRecipientDisplayType           : -2147483642
msExchRecipientTypeDetails           : 2147483648
msExchRemoteRecipientType            : 4
msExchTextMessagingState             : {302120705, 16842751}
msExchUMDtmfMap                      : {reversedPhone:6166822920, emailAddress:268786393866355, lastNameFirstName:386635526878639, 
                                       firstNameLastName:268786393866355}
msExchUserAccountControl             : 0
msExchVersion                        : 88218628259840
msExchWhenMailboxCreated             : 28/04/2017 9:41:45 AM
Name                                 : Courtney Funnell
nTSecurityDescriptor                 : System.DirectoryServices.ActiveDirectorySecurity
ObjectCategory                       : CN=Person,CN=Schema,CN=Configuration,DC=trs,DC=nsw
ObjectClass                          : user
ObjectGUID                           : 4f67c3fa-cc4a-4562-bff4-e0ed00d35e3b
objectSid                            : S-1-5-21-1417901796-1476651256-1067267087-7954
Office                               : 175 Liverpool St
OfficePhone                          : 0292286616
Organization                         : 
OtherName                            : 
Parent                               : {}
PasswordExpired                      : False
PasswordLastSet                      : 6/01/2020 7:37:31 AM
PasswordNeverExpires                 : False
PasswordNotRequired                  : False
Path                                 : {}
physicalDeliveryOfficeName           : 175 Liverpool St
POBox                                : 
PostalCode                           : 2000
PrimaryGroup                         : CN=Domain Users,CN=Users,DC=trs,DC=nsw
primaryGroupID                       : 513
PrincipalsAllowedToDelegateToAccount : {}
ProfilePath                          : 
ProtectedFromAccidentalDeletion      : False
protocolSettings                     : {IMAP4?0????????????, POP3?0????????????}
proxyAddresses                       : {x500:/o=TRS NSW/ou=Exchange Administrative Group 
                                       (FYDIBOHF23SPDLT)/cn=Recipients/cn=8da0c93217d84e3c93bb152488d0fb53-Courtney Funnell, 
                                       X500:/o=ExchangeLabs/ou=Exchange Administrative Group 
                                       (FYDIBOHF23SPDLT)/cn=Recipients/cn=8eb6a7ada218414390e13b8febea6cbb-Courtney Fu, 
                                       smtp:Courtney.Funnell@NSWLandRegistryServices.mail.onmicrosoft.com, SMTP:Courtney.Funnell@nswlrs.com.au}
pwdLastSet                           : 132227302519460823
SamAccountName                       : cfunnell
sAMAccountType                       : 805306368
ScriptPath                           : 
sDRightsEffective                    : 15
ServicePrincipalNames                : {}
showInAddressBook                    : {CN=All Recipients(VLV),CN=All System Address Lists,CN=Address Lists Container,CN=TRS NSW,CN=Microsoft 
                                       Exchange,CN=Services,CN=Configuration,DC=trs,DC=nsw, CN=Default Global Address List,CN=All Global Address 
                                       Lists,CN=Address Lists Container,CN=TRS NSW,CN=Microsoft 
                                       Exchange,CN=Services,CN=Configuration,DC=trs,DC=nsw, CN=All Users,CN=All Address Lists,CN=Address Lists 
                                       Container,CN=TRS NSW,CN=Microsoft Exchange,CN=Services,CN=Configuration,DC=trs,DC=nsw}
SID                                  : S-1-5-21-1417901796-1476651256-1067267087-7954
SIDHistory                           : {}
SmartcardLogonRequired               : False
sn                                   : Funnell
st                                   : NSW
State                                : NSW
StreetAddress                        : 175 Liverpool St
Surname                              : Funnell
targetAddress                        : SMTP:Courtney.Funnell@NSWLandRegistryServices.mail.onmicrosoft.com
telephoneNumber                      : 0292286616
Title                                : Title and Plan Officer
TrustedForDelegation                 : False
TrustedToAuthForDelegation           : False
UseDESKeyOnly                        : False
userAccountControl                   : 512
userCertificate                      : {}
UserPrincipalName                    : Courtney.Funnell@nswlrs.com.au
uSNChanged                           : 6207845
uSNCreated                           : 51495
whenChanged                          : 16/01/2020 7:41:33 AM
whenCreated                          : 28/04/2017 8:48:57 AM
WriteDebugStream                     : {}
WriteErrorStream                     : {}
WriteInformationStream               : {}
WriteVerboseStream                   : {}
WriteWarningStream                   : {}



$NewUsers | % {}

(ConvertTo-SecureString -AsPlainText "January2020" -Force)

New-ADUser : Access to the attribute is not permitted because the attribute is owned by the Security Accounts Manager (SAM)
badPasswordTime,badPwdCount,lastLogoff,lastLogon,logonCount,memberOf,objectGUID,objectSid,primaryGroupID,pwdLastSet,sAMAccountType