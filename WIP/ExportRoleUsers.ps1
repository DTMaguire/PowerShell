# Modification of the ExportRoleGroups.ps1 script...

$MemberFiles = Get-ChildItem -Name "*Members.txt"

ForEach ($File in $MemberFiles) {
#################################### - Needs work!
    $ExportName = $Group.SamAccountName
    $GroupAttributes = $Group | Select Name,SamAccountName,CanonicalName,GroupCategory,GroupScope
    $GroupMembers = Get-ADGroupMember -Identity $Group | Select Name 
    If (!$GroupMembers) {
        Write-Host -ForegroundColor Gray "Skipping creation of file for empty group `'$ExportName`'"
        $ExportName | Out-File -Append "ROLE - Empty Groups.txt"
        }
    Else {
        Write-Host -ForegroundColor Green "Writing group `'$ExportName`' to `'ROLE - All Groups.csv`' and members to `'$ExportName - Members.txt`'"
        Export-Csv -InputObject $GroupAttributes -NoTypeInformation -Append -Path "ROLE - All Groups.csv"
        $GroupMembers | Out-File "$ExportName - Members.txt"
    }
}