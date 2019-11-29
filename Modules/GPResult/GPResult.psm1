function Get-GPResult {
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [ValidateScript({
            if (Get-ADUser $_) {
                $true
            } else {
                throw "Unable to find user: $($_)"
            }
        })]
        [string]$User = $($env:USERNAME),

        [Parameter(Position=1)]
        [ValidateScript({
            if (Test-Connection -ComputerName $_ -Quiet -Count 1) {
                $true
            } else {
                throw "Unable to contact host: $($_)"
            }
        })]
        [string]$Computer = $($env:COMPUTERNAME),

        [Parameter(Position=2)]
        [ValidateScript({
            if (Test-Path -Path $_) {
                $true
            } else {
                throw "Unable to access: $($_)"
            }                
        })]
        [string]$Path = $($Env:USERPROFILE + "\Documents")
    )

    if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
    {
        $FilePath = (Join-Path (Resolve-Path $Path).Path -ChildPath "GPReport-${User}_${Computer}.html")
        Write-Host -ForegroundColor 'White' "`nRunning GP report for ${User} on ${Computer}" -NoNewline
        try {
            Get-GPResultantSetOfPolicy -User $User -Computer $Computer -ReportType Html -Path $FilePath
        }
        catch {
            Write-Error -Message "Unable to generate report -: ${PSItem.Exception.InnerException}" -ErrorAction Stop
        }
        Write-Host -ForegroundColor 'White' "Report saved to: $FilePath" -NoNewline
        Start-Process iexplore.exe -ArgumentList $FilePath
    }
    else {
        Write-Error -Message "PowerShell session not elevated - please restart with administrative privileges." -ErrorAction Stop
    }

}

Export-ModuleMember -Function 'Get-GPResult'
