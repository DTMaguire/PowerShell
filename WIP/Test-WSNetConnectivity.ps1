# Script for testing WS Management (PowerShell Remoting) connectivity to Windows Servers in AWS
# Version 2.0 - Copyright DM Tech 2019

#Requires #Requires -Modules ActiveDirectory
using namespace System.Collections.Generic

$OutCSV = 'D:\Scripts\Output\AWSServersWSManTest.csv'
$AWSServers = (Get-ADComputer -Filter 'Name -like "*AWS*" -and OperatingSystem -like "Windows Server*"' | Select-Object -ExpandProperty Name)
$ServerStatus= [List[PSObject]]::new()

foreach ($Server in $AWSServers) {
    Write-Progress -Activity "Testing Net Connectivity" -Status "$Server" `
            -PercentComplete ($AWSServers.IndexOf($Server)+1 / $AWSServers.Count*100)
    if (Test-Connection -ComputerName $Server -Count 1 -ErrorAction SilentlyContinue) {
        if (Test-WSMan -ComputerName $Server -ErrorAction SilentlyContinue) {
            $Status = "WSMan test succeeded"
            Write-Host -ForegroundColor 'Green' "+" -NoNewline
        } else {
            $Status = "WSMan test failed"
            Write-Host -ForegroundColor 'Red' "-" -NoNewline
        }
    } else {
        $Status = "No connectivity"
        Write-Host "_" -NoNewline
    }
    $ServerProperties = [Ordered]@{
        Name = $Server
        Status = $Status
    }
    $ServerStatus.Add([PSCustomObject]$ServerProperties)
}

Write-Host -ForegroundColor 'White' "`nTotal machines tested: $($AWSServers.Count)"
$ServerStatus | Export-Csv -NoTypeInformation $OutCSV
Invoke-Item $OutCSV
