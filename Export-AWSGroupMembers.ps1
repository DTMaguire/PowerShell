# PowerShell script to export a list of groups and their members that match a given filter
# Version 1.0 - Copyright DM Tech 2019
#
#Requires -Modules ActiveDirectory

$OutputCSVPath = "D:\Scripts\Output\AWS Groups\UserMembership.csv"
$UserArray = @()

$Groups = (Get-ADGroup -Filter {Name -like "*AWS*"} -Properties * | Where-Object {$_.GroupCategory -like "Security"} | `
    Sort-Object -Property SamAccountName | Select-Object SamAccountName, Description, Members)
$GroupsTotal = $Groups.Count
$CurGroup = 0

ForEach ($Group in $Groups) {

    $CurUser = 0
    $CurGroup++
    $GroupSAM = $Group.SamAccountName

    Write-Progress -Id 1 -Activity "Gathering Group Information for: `'$GroupSAM`'" `
        -CurrentOperation " " -PercentComplete ($CurGroup / $GroupsTotal * 100)

    $GroupMembers = (Get-ADGroupMember -Identity $GroupSAM | Select-Object Name, SamAccountName, ObjectClass)
    $MembersTotal = $GroupMembers.Count

    if ($MembersTotal -lt 1) {

        Write-Warning "`nSkipping creation of file for empty group `'$GroupSAM`'"

    } else {

        Start-Sleep -Milliseconds 100
        Write-Host -ForegroundColor 'Green' "`n`n$GroupSAM - Members: $MembersTotal`n$($Group.Description)`n"
        Start-Sleep -Milliseconds 100

        foreach ($Member in $GroupMembers) {

            $CurUser++
            $MemberSAM = $Member.SamAccountName

            Write-Progress -Id 2 -Activity "Gathering Member Information for: `'$($Member.Name)`'" `
                -PercentComplete ($CurUser / $MembersTotal * 100) -ParentId 1

            Write-Host -ForegroundColor 'White' "$MemberSAM"

            if ($Member.ObjectClass -eq 'computer') {
                Write-Warning "Object is a computer account, skipping"
                Continue
            }

            if (($UserArray.SamAccountName) -contains ($MemberSAM)) {
                Write-Host -ForegroundColor 'Magenta' "User already in array"
                Start-Sleep -Milliseconds 50
            } else {
                $UserObject = (Get-ADUser -Identity $MemberSAM -Properties *)
                $UserAttributes = ($UserObject | `
                    Select-Object Name, SamAccountName, Description, Enabled, WhenCreated, LastLogonDate, AccountExpirationDate)
                $AWSGroupMembership = ($UserObject | Select-Object -ExpandProperty MemberOf | `
                    Where-Object {$_ -match "AWS"} | Get-ADGroup | Select-Object -ExpandProperty SamAccountName)
                $UserArray += ($UserAttributes | `
                    Select-Object *, @{label='AWSGroups'; expression={$AWSGroupMembership}})
            }
        }
        Write-Host -ForegroundColor 'White' "`nRunning total:" $UserArray.Count
    }
}

$UserArray | Sort-Object SamAccountName | Format-Table Name, SamAccountName, AWSGroups
Write-Host -ForegroundColor 'White' "Total of unique AWS group members: $($UserArray.Count)`n"
$UserArray | Export-Csv -NoTypeInformation -Path $OutputCSVPath
Write-Host -ForegroundColor 'Green' "Output file saved as: $OutputCSVPath`n"
