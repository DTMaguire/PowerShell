# PowerShell script to add a separate country field extracted from the location column of the exported Azure AD Sign-in logs
# Version 1.0 - Copyright DM Tech 2019

$CSVInput = (Import-Csv -Path "D:\Scripts\Input\SignIns_2019-09-01_2019-10-02.csv")
$OutPath = "D:\Scripts\Output\SignIns_2019-09-01_2019-10-02_Country.csv"

Write-Host -ForegroundColor 'Green' "`n`nTotal records imported: " $CSVInput.Count "`n"

$TimeTaken = Measure-Command {

    $CSVInput = ($CSVInput | Select-Object -Property *, @{label='Country'; expression = {""}}) # Problem here...

    foreach ($Record in $CSVInput) {

        if ($Record.Location -ne "null, null, null") {

            $Record.Country = ($Record.Location).Substring($Record.Location.Length - 2)
            Write-Host -ForegroundColor 'White' "`nExtracted: " $Record.Country " From: " $Record.Location
        }
    }

    Write-Host -ForegroundColor 'Green' "`n`nWriting output to: " $OutPath "`n"
    $CSVInput | Export-Csv -NoTypeInformation -LiteralPath $OutPath
}

Write-Host -ForegroundColor 'Green' "`nTime taken: " $TimeTaken "`n"
