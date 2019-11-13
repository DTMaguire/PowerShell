[System.Collections.ArrayList]$SourceFile = (Get-Content D:\Scripts\Input\SR-1058_GarbledMess.txt)

while ($SourceFile -contains "`t") {
    $SourceFile.Remove("`t")
}

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
    Out-File -FilePath 'D:\Scripts\Output\SR-1058_UnGarbled.csv' -InputObject $InputString -Append -NoNewline
}
