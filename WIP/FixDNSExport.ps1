# PowerShell script to fix the Timestamp column exported from DNS Management
# Version 1.0 - Copyright DM Tech 2019

$CSVInput = (Import-Csv -Path "D:\Scripts\Input\DNS.csv")
$OutPath = "D:\Scripts\Output\DNS_Fixed.csv"

Write-Host -ForegroundColor 'Green' "`n`nTotal records imported: " $CSVInput.Count "`n"

$TimeTaken = (Measure-Command {

    foreach ($Record in $CSVInput) {
        $Record.Timestamp =  ($Record.Timestamp).replace("?","")
    }

    Write-Host -ForegroundColor 'Green' "`n`nWriting output to: " $OutPath "`n"
    $CSVInput | Export-Csv -NoTypeInformation -LiteralPath $OutPath

} | Select-Object -ExpandProperty TotalMilliseconds, TotalSeconds)

Write-Host -ForegroundColor 'Green' "`n`nTime taken: " $TimeTaken "`n"