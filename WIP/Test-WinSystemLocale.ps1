# Script for checking the system locale of Windows Servers in AD
# Version 1.0 - Copyright DM Tech 2019

#Requires #Requires -Modules ActiveDirectory
using namespace System.Collections.Generic

$OutCSV = (Split-Path $Env:DevPath -Parent) + '\Output\ServerLocales.csv'
$OfflineCSV = (Split-Path $Env:DevPath -Parent) + '\Output\ServersOffline.csv'
$ServerList = (Get-ADComputer -Filter 'OperatingSystem -like "Windows Server*"' | Select-Object -ExpandProperty Name)
$NetNotWorking = [List[hashtable]]::new()
$WSManNotWorking = [List[hashtable]]::new()
$LocaleList = [List[PSObject]]::new()

foreach ($Server in $ServerList) {

    Write-Progress -Activity "Attempting remote connection:" -Status "$Server" `
            -PercentComplete ($ServerList.IndexOf($Server) / $ServerList.Count*100)

    if (Test-Connection -ComputerName $Server -Count 1 -ErrorAction SilentlyContinue) {
        try {
            #Test-WSMan -ComputerName $Server | Out-Null
            $Run = ([System.Globalization.CultureInfo]([int]("0x" + (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $Server -AsJob).locale)))
            
            $Run | Wait-Job -Timeout 5

            
            $Run | Where-Object {$_.State -ne "Completed"} | Stop-Job
        
            $ObjectProperties = [Ordered]@{
                HostName = $Server
                LCID = $ServerLocale.LCID
                LocaleName = $ServerLocale.Name
                LocaleDisplayName = $ServerLocale.DisplayName
            }

            $LocaleList.Add([PSCustomObject]$ObjectProperties)
        
        } catch {

            $WSManNotWorking.Add(@{Name='Hostname'; Expression={$Server}},@{Name='Status'; Expression={'Host online but unable to retrieve WMI Object'}})
        }
    } else {

        $NetNotWorking.Add(@{Name='Hostname'; Expression={$Server}},@{Name='Status'; Expression={'Host offline or not responding'}})
    }
}

Write-Host -ForegroundColor 'Green' "`nLocale retrieved for: $($LocaleList.Count)"
$LocaleList | Export-Csv -NoTypeInformation $OutCSV
Invoke-Item $OutCSV

Write-Host -ForegroundColor 'Red' "`nLocale NOT retrieved for: $($WSManNotWorking.Count)"
$WSManNotWorking | Export-Csv -NoTypeInformation $OfflineCSV
Write-Output $WSManNotWorking

Write-Host -ForegroundColor 'Red' "`nServers offline: $($NetNotWorking.Count)"
$NetNotWorking | Export-Csv -NoTypeInformation $OfflineCSV -Append
Write-Output $NetNotWorking
Invoke-Item $OfflineCSV
Write-Host "`n"

$NetNotWorking.Clear()
$WSManNotWorking.Clear()
$LocaleList.Clear()
