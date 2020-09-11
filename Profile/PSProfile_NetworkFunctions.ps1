# Create some useful functions to allow quick lookup of names and addresses in DNS
function Get-HostEntry {
    param ($Address)
    try {
        [System.Net.Dns]::GetHostEntry("$Address")
    }
    catch {
        throw "$($_)"
    }
}

function Test-DnsHostName {
    param (
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$Name = $Env:COMPUTERNAME
    )
    
    Begin {
        function Write-HostStatus () {
            [PSCustomObject]@{
                HostName = $Name
                IP = $IP
                PtrValue = $RName
                Status = $Status
            }
        }
    }

    Process {

        $IP = $null
        $RName = $null
            
        try {
            $IPs = @(Get-HostEntry $Name | Select-Object -ExpandProperty AddressList | ForEach-Object {$_.IPAddressToString})
        }
        catch {
            $Status = 'No Host Record'
            Write-HostStatus
            Return
        }

        foreach ($IP in $IPs) {

            try {
                $RName = ((Get-HostEntry $IP).HostName)
                if ($RName -like "$Name*") {
                    $Status = 'Record Match'
                } else {
                    $Status = 'Record Mismatch'
                }
            }
            catch {
                if ($IP -match '10\.77\.\d{1,3}\.\d{1,3}') {
                    $Status = 'AWS Address'
                } else {
                    $Status = 'No PTR Record'
                }
            }

            Write-HostStatus
        }
    }
}

function Get-LastBootupTime {
    param (
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$Name = $Env:COMPUTERNAME
    )

    Process {

        $Online = (Test-Connection -ComputerName $Name -Quiet -Count 1 -ErrorAction SilentlyContinue)

        try {
            if ($Online) {
                $LastBootupTime = (Get-CimInstance Win32_OperatingSystem -ComputerName $Name -ErrorAction Stop).LastBootupTime
                $Duration = (New-TimeSpan -Start $LastBootupTime -End (Get-Date))
            } else {
                $LastBootupTime = 'No Data'
                $Duration = $null
            }
        }
        catch {
            #$LastBootupTime = "$($_)"
            $LastBootupTime = 'WinRM Error'
            $Duration = $null
        }

        [PSCustomObject]@{
            Hostname = $Name
            Online = $Online
            Uptime = '{0}d {1:hh\:mm\:ss}' -f $Duration.Days,$Duration
            LastBootupTime = $LastBootupTime
        }
    }
}
