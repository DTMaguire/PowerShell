function Send-WOL
{
<# 
  .SYNOPSIS  
    Send a WOL packet to a broadcast address
  .PARAMETER Mac
   The MAC address of the device that need to wake up
  .PARAMETER IP
   The IP address where the WOL packet will be sent to
  .EXAMPLE 
   Send-WOL -Mac 00:11:32:21:2D:11 -IP 192.168.8.255 
#>

[CmdletBinding()]
param(
[Parameter(Mandatory=$True,Position=1)]
[string]$Mac,
[string]$IP="255.255.255.255", 
[int]$Port=9
)
$Broadcast = [Net.IPAddress]::Parse($IP)
 
$Mac = (($Mac.Replace(":","")).replace("-","")).replace(".","")
$Target = 0,2,4,6,8,10 | ForEach-Object {[convert]::ToByte($Mac.Substring($_,2),16)}
$Packet = (,[byte]255 * 6) + ($Target * 16)
 
$UDPclient = New-Object System.Net.Sockets.UdpClient
$UDPclient.Connect($Broadcast,$Port)
[void]$UDPclient.Send($Packet, 102) 

}
