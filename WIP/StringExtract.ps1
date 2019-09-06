$InputFile = '.\Netlog.txt'
$OutputFile = '.\NetlogIPs.txt'
$Regex = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
Select-String -Path $InputFile -Pattern $Regex -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } | Out-File $OutputFile

#Where-Object {$_ -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'} | Out-File -Path .\NetLogonIPs.txt
#One liner:
Select-String -Path .\Netlog.txt -Pattern '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' | ForEach-Object {$_.Matches} | ForEach-Object {$_.Value} | Sort-Object | Group-Object | Select-Object -Property Count,Name

Select-String -Path .\Netlogon.txt -Pattern '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' | ForEach-Object {$_.Matches} | ForEach-Object {$_.Value} | Sort-Object | Group-Object | Select-Object -Property Count,Name