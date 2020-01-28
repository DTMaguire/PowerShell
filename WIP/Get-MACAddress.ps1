$Inputmachine = Read-Host -Prompt "Enter hostname of Windows machine"
$IPAddress = ([System.Net.Dns]::GetHostByName($Inputmachine).AddressList[0]).IpAddressToString 
$IPMAC = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $Inputmachine 
$MACAddress = ($IPMAC | Where-Object { $_.IpAddress -eq $IPAddress}).MACAddress 
Write-Output "Machine Name : $Inputmachine`nIP Address : $IPAddress`nMAC Address: $MACAddress`n"                           