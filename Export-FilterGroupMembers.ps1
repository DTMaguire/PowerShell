# PowerShell script to export a list of groups and their members that match a given filter
# Version 1.0 - Copyright DM Tech 2019

#Requires -Modules ActiveDirectory

do {
    $Filter = Read-Host -Prompt "`nInput group string to search, or 'Q' to exit"
    if ($Filter -eq 'q') {
        exit
    }
} until ($null -ne $Filter)

$FilterString = [string]::Format('*{0}*', $Filter)
$OutputPath = "D:\Scripts\Output\Export Groups\"
$OutputCSV = Join-Path -Path $OutputPath -ChildPath "$($Filter)UserMembership.csv"
$UserArray = [System.Collections.ArrayList]::new()

if (Test-Path $OutputCSV) {
    Write-Warning "Output file already exists at $OutputCSV"
    if (Read-Host -Prompt "Continue anyway? (y/N):" -eq y) {
        continue
    } else {
        break
    }
}

Write-Host -ForegroundColor 'White' "`nFiltering groups matching: `'$Filter`'"
Start-Sleep 1

$Groups = (Get-ADGroup -Filter {Name -like $FilterString} -Properties * | Where-Object {$_.GroupCategory -like "Security"} | `
    Sort-Object -Property SamAccountName | Select-Object SamAccountName, Description, Members)
$GroupsTotal = $Groups.Count
Write-Host $GroupsTotal
Start-Sleep 2
$CurGroup = 0

ForEach ($Group in $Groups) {

    $CurUser = 0
    $CurGroup++
    $NotUnique = 0
    $GroupSAM = $Group.SamAccountName

    Write-Progress -Id 1 -Activity "Gathering Group Information for: `'$GroupSAM`'" `
        -PercentComplete ($CurGroup / $GroupsTotal * 100)

    $GroupMembers = (Get-ADGroupMember -Identity $GroupSAM | Sort-Object | Select-Object Name, SamAccountName, ObjectClass)
    $MembersTotal = $GroupMembers.Count

    if ($MembersTotal -lt 1) {

        Write-Host -ForegroundColor 'Yellow' "`nSkipping empty group `'$GroupSAM`'"

    } else {

        Write-Host -ForegroundColor 'Green' "`n`n$GroupSAM - Members: $MembersTotal`n$($Group.Description)`n"
        Start-Sleep -Milliseconds 100

        foreach ($Member in $GroupMembers) {

            $CurUser++
            $MemberSAM = $Member.SamAccountName

            Write-Progress -Id 2 -Activity "Gathering Member Information for: `'$($Member.Name)`'" `
                -PercentComplete ($CurUser / $MembersTotal * 100) #-ParentId 1
            Start-Sleep -Milliseconds 50

            if ($Member.ObjectClass -eq 'computer') {
                Write-Warning "Object `'$MemberSAM`' is a computer account, skipping"
                Continue
            }

            if ($UserArray.Contains($MemberSAM)) {
                    $NotUnique++
            } else {
                Write-Host -ForegroundColor 'White' "$MemberSAM"
                if ((Get-ADObject -Filter 'Name -like "$MemberSAM"').ObjectClass -eq 'user') {
                    $UserObject = (Get-ADUser -Identity $MemberSAM -Properties *)
                    $UserAttributes = ($UserObject | `
                        Select-Object Name, SamAccountName, Description, Enabled, WhenCreated, LastLogonDate, AccountExpirationDate)
                    $FilterGroupMembership = ($UserObject | Select-Object -ExpandProperty MemberOf | `
                        Where-Object {$_ -match "$Filter"} | Get-ADGroup | Select-Object -ExpandProperty SamAccountName)
                    $UserArray.Add(($UserAttributes | `
                        Select-Object *, @{label='FilteredGroups'; expression={$FilterGroupMembership -join '; '}}))
                }
            }                                     
        }
        Write-Host -ForegroundColor 'Magenta' "`nMembers already matched:" $NotUnique
        Write-Host -ForegroundColor 'Cyan' "Current unique members: " $UserArray.Count
    }
}

$UserArray | Sort-Object SamAccountName | Format-Table Name, SamAccountName, FilteredGroups
Write-Host -ForegroundColor 'White' "Total of unique $Filter group members: $($UserArray.Count)`n"

if ($UserArray.Count -ge 1) {
    $UserArray | Export-Csv -NoTypeInformation -Path $OutputCSV
    Write-Host -ForegroundColor 'Green' "Output file saved as: $OutputCSV`n"   
}
