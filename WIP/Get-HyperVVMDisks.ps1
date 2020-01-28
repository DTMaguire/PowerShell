$ClusterVMs = Get-ClusterGroup -Cluster CLS-QS-HYPPRD1 | Where-Object {$_.GroupType -eq 'VirtualMachine' -and $_.State -eq 'Online'} | Get-VM

foreach ($VM in $ClusterVMs) {
    Get-VHD -ComputerName $VM.ComputerName -Path $VM.HardDrives.Path | Select-Object @{N="Name";E={$VM.Name}},@{N="VHDPath";E={$VM.HardDrives.Path}},@{N="Capacity(GB)";E={[math]::Round($_.Size/ 1GB)}},@{N="Used Space(GB)";E={[math]::Round($_.FileSize/ 1GB)}}
}