[System.Collections.ArrayList]$SourceFile = (Get-Content D:\Scripts\Input\SR-1058_GarbledMess.txt)
while ($SourceFile -contains "`t") {
    $SourceFile.Remove("`t")
}
$OutputFile = 'D:\Scripts\Output\SR-1058_UnGarbled.csv'

$Counter = 0
foreach ($Line in $SourceFile) {
    $Counter++
    $Line = $Line -replace "`t`t",""
    if ($Counter -eq 7) {
        $Counter = 0
        $InputString = $Line + "`r`n"
    } else {
        $InputString = $Line + ","
    }
    Out-File -FilePath $OutputFile -Encoding UTF8 -InputObject $InputString -Append -NoNewline
}

Invoke-Item $OutputFile