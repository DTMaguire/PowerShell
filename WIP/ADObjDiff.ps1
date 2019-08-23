Function CompareObjectProperties {
    Param(
        [PSObject]$ReferenceObject,
        [PSObject]$DifferenceObject 
    )

    $ObjProps = $ReferenceObject | Get-Member -MemberType Property,NoteProperty | ForEach-Object Name
    $ObjProps += $DifferenceObject | Get-Member -MemberType Property,NoteProperty | ForEach-Object Name
    $ObjProps = $ObjProps | Sort-Object | Select-Object -Unique
    $Diffs = @()

    ForEach ($ObjProp in $ObjProps) {

        $Diff = Compare-Object $ReferenceObject $DifferenceObject -Property $ObjProp

        If ($Diff) {

            $DiffProps = @{

                PropertyName=$ObjProp
                RefValue=($Diff | Where-Object {$_.SideIndicator -eq '<='} | ForEach-Object $($ObjProp))
                DiffValue=($Diff | Where-Object {$_.SideIndicator -eq '=>'} | ForEach-Object $($ObjProp))
            }

            $Diffs += New-Object PSObject -Property $DiffProps
        }        
    }

    If ($Diffs) {return ($Diffs | Select-Object PropertyName,RefValue,DiffValue | Out-GridView)}     
}

Function ObjClass {
    Param (
        [PSObject]$ADObject
    )

    switch ($ObjClass.ObjectClass) {

        "user" { Get-ADUser -Identity $ADObject -Properties *  }
        "group" { Get-ADGroup -Identity $ADObject -Properties * }
        "computer" { Get-ADComputer -Identity $ADObject -Properties *}
        Default { Write-Host -ForegroundColor 'Magenta' "¯\_(ツ)_/¯"}
    }
    
    Return 
}

function CheckObject {
    param (
        $InputObject
    )
        # Work out if multiple results are returned?
        $ObjCheck = Get-ADObject -Filter 'SamAccountName -like "$ADObject*"'

        If (($ObjCheck | Measure-Object).Count -gt 1) {

            Write-Host -ForegroundColor 'Cyan' "`nMultiple matches found, please narrow search to one of the following accounts:`n"
            
            # Output list of user accounts
            Write-Output $ObjCheck.SamAccountName 
        }
    

}

    #$Ad1 = Get-ADUser -Identity $(Read-Host -Prompt "`nEnter an AD account username to reference, or 'q' to quit") -Properties *
    #$Ad2 = Get-ADUser -Identity $(Read-Host -Prompt "Enter an AD account username to difference, or 'q' to quit") -Properties *
    $Input1 = Read-Host -Prompt "`nEnter an AD object SamAccountName to reference, or 'q' to quit"
    $Input2 = Read-Host -Prompt "`nEnter an AD object SamAccountName to difference, or 'q' to quit"

    #$Ad2 = Get-ADUser -Identity $(Read-Host -Prompt "Enter an AD account username to difference, or 'q' to quit") -Properties *
    
    #$Ad2 = Get-ADObject -Filter 'Name -like "Daniel Maguire"' -Properties *



    #$Ad1 = Get-ADUser amelia.mitchell -Properties *
    #$Ad2 = Get-ADUser carolyn.quinn -Properties *

    # Call the function with the two objects as parameters
    CompareObjectProperties $Ad1 $Ad2

    #Write-Host -ForegroundColor 'Magenta' "Well, that didn't work..."







If ( $(Get-ADObject -Filter 'SamAccountName -like "$Input1*"').ObjectClass -like "user" ) {
    $Ad1 = Get-ADUser -Identity $Input1 -Properties *
}
ElseIf ( $(Get-ADObject -Filter 'SamAccountName -like "$Input1*"').ObjectClass -like "group") {
    $Ad1 = Get-ADGroup -Identity $Input1 -Properties *
}
ElseIf ( $(Get-ADObject -Filter 'SamAccountName -like "$Input1*"').ObjectClass -like "computer") {
    $Ad1 = Get-ADComputer
}
Else {
    Write-Host -ForegroundColor 'Magenta' "¯\_(ツ)_/¯"
    Break
}