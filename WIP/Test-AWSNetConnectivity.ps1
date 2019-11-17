#Requires #Requires -Modules ActiveDirectory
$AWSServers = (Get-ADComputer -Filter 'Name -like "SYDAWS*"' | Select-Object -ExpandProperty Name)
$NetWorking = @()
$NetNotWorking = @()
$WSManWorking = @()
$WSManNotWorking = @()

foreach ($Server in $AWSServers) {
    Write-Progress -Activity "Testing Net Connectivity" -Status "$Server" `
            -PercentComplete ($AWSServers.IndexOf($Server)+1 / $AWSServers.Count*100)
    if (Test-Connection -ComputerName $Server -Count 1 -ErrorAction SilentlyContinue) {
        $NetWorking += $Server
        if (Test-WSMan -ComputerName $Server -ErrorAction SilentlyContinue) {
            $WSManWorking += $Server
            Write-Host -ForegroundColor 'Green' "+" -NoNewline
        } else {
            $WSManNotWorking += $Server
            Write-Host -ForegroundColor 'Red' "-" -NoNewline
        }
    } else {
        $NetNotWorking += $Server
    }
}
Start-Transcript -Path ..\..\Output\Test-NetConnectivity.log
Write-Host -ForegroundColor 'Green' "`nNet Working for: $($NetWorking.Count)"
$NetWorking
Write-Host -ForegroundColor 'Red' "`nNet NOT Working for: $($NetNotWorking.Count)"
$NetNotWorking

Write-Host -ForegroundColor 'Green' "`nWSMan working for: $($WSManWorking.Count)"
$WSManWorking
Write-Host -ForegroundColor 'Red' "`nWSMan NOT Working for: $($WSManNotWorking.Count)"
$WSManNotWorking
Stop-Transcript