# Script for checking the system locale of Windows Servers in AD
# Version 1.0 - Copyright DM Tech 2019

#Requires #Requires -Modules ActiveDirectory
using namespace System.Collections.Generic

$OutCSV = (Split-Path $Env:DevPath -Parent) + '\Output\ServerLocales.csv'
$ServerList = (Get-ADComputer -Filter 'OperatingSystem -like "Windows Server*"' | Select-Object -ExpandProperty Name)
$NetNotWorking = [List[string]]::new()
$LocaleNotWorking = [List[string]]::new()
$LocaleList = [List[PSObject]]::new()

foreach ($Server in $ServerList) {

    Write-Progress -Activity "Attempting remote connection:" -Status "$Server" `
            -PercentComplete ($ServerList.IndexOf($Server) / $ServerList.Count*100)

    if (Test-Connection -ComputerName $Server -Count 1 -ErrorAction SilentlyContinue) {
        try {

            $ServerLocale = [System.Globalization.CultureInfo]([int]("0x" + (Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $Server).locale))
        
            $ObjectProperties = [Ordered]@{
                HostName = $Server
                LCID = $ServerLocale.LCID
                LocaleName = $ServerLocale.Name
                LocaleDisplayName = $ServerLocale.DisplayName
            }

            $LocaleList.Add([PSCustomObject]$ObjectProperties)

        } catch {

            $LocaleNotWorking.Add($Server)
        }
    } else {

        $NetNotWorking.Add($Server)
    }
}

Write-Host -ForegroundColor 'Green' "`nLocale retrieved for: $($LocaleList.Count)"
$LocaleList | Export-Csv -NoTypeInformation $OutCSV
Invoke-Item $OutCSV

Write-Host -ForegroundColor 'Red' "`nLocale NOT retrieved for: $($LocaleNotWorking.Count)"
Write-Output $LocaleNotWorking

Write-Host -ForegroundColor 'Red' "`nServers offline: $($NetNotWorking.Count)"
Write-Output $NetNotWorking
Write-Host "`n"
