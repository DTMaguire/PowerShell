# Creates a function alias to jump back to the DevPath, saves having to type 'Set-Location $Env:DevPath'
function SetDevPath {Set-Location $Env:DevPath}
New-Alias -Name 'sdp' -Value SetDevPath

# Writes a line of a specified colour across the width of the screen
function WriteLine {
    [Alias("WL")]
    param (
        [ValidateSet(
            'Black',
            'DarkBlue',
            'DarkGreen',
            'DarkCyan',
            'DarkRed',
            'DarkMagenta',
            'DarkYellow',
            'Gray',
            'DarkGray',
            'Blue',
            'Green',
            'Cyan',
            'Red',
            'Magenta',
            'Yellow',
            'White'
        )]
        [string]$Colour = 'White',
        [switch]$Start,
        [switch]$End
    )

    if ($null -eq $Line -or $Line.Length -ne $Host.UI.RawUI.WindowSize.Width) {
        $Script:Line = $null
        for ($i = 0; $i -lt ($Host.UI.RawUI.WindowSize.Width); $i++) {
            $Line += "-"
        }
    }
    
    if ($Start) {
        Write-Host "`n"
    }
    
    Write-Host $Line -ForegroundColor $Colour -NoNewline
    
    if ($End) {
        Write-Host "`n"
    }
}

# Function overload to allow easy selection of complex objects in calculated properties
<# function Select-Object{
    [CmdletBinding(DefaultParameterSetName='DefaultParameter', HelpUri='http://go.microsoft.com/fwlink/?LinkID=113387', RemotingCapability='None')]
    param(
        [Parameter(ValueFromPipeline=$true)]
        [psobject]
        ${InputObject},
 
        [Parameter(ParameterSetName='SkipLastParameter', Position=0)]
        [Parameter(ParameterSetName='DefaultParameter', Position=0)]
        [System.Object[]]
        ${Property},
 
        [Parameter(ParameterSetName='SkipLastParameter')]
        [Parameter(ParameterSetName='DefaultParameter')]
        [string[]]
        ${ExcludeProperty},
 
        [Parameter(ParameterSetName='DefaultParameter')]
        [Parameter(ParameterSetName='SkipLastParameter')]
        [string]
        ${ExpandProperty},
 
        [switch]
        ${Unique},
 
        [Parameter(ParameterSetName='DefaultParameter')]
        [ValidateRange(0, 2147483647)]
        [int]
        ${Last},
 
        [Parameter(ParameterSetName='DefaultParameter')]
        [ValidateRange(0, 2147483647)]
        [int]
        ${First},
 
        [Parameter(ParameterSetName='DefaultParameter')]
        [ValidateRange(0, 2147483647)]
        [int]
        ${Skip},
 
        [Parameter(ParameterSetName='SkipLastParameter')]
        [ValidateRange(0, 2147483647)]
        [int]
        ${SkipLast},
 
        [Parameter(ParameterSetName='IndexParameter')]
        [Parameter(ParameterSetName='DefaultParameter')]
        [switch]
        ${Wait},
 
        [Parameter(ParameterSetName='IndexParameter')]
        [ValidateRange(0, 2147483647)]
        [int[]]
        ${Index})
 
    begin
    {
        try {
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }
            #only if the property array contains a hashtable property
            if ( ($Property | Where-Object { $_ -is [System.Collections.Hashtable] }) ) {
                $newProperty = @()
                foreach ($prop in $Property){
                    if ($prop -is [System.Collections.Hashtable]){
                        foreach ($htEntry in $prop.GetEnumerator()){
                           $newProperty += @{n=$htEntry.Key;e=$htEntry.Value}
                        }
                    }
                    else {
                        $newProperty += $prop
                    }
                }
                $PSBoundParameters.Property = $newProperty
            }
            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Select-Object', [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = {& $wrappedCmd @PSBoundParameters }
            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        } catch {
            throw
        }
    }
 
    process
    {
        try {
            $steppablePipeline.Process($_)
        } catch {
            throw
        }
    }
 
    end
    {
        try {
            $steppablePipeline.End()
        } catch {
            throw
        }
    }
 
}
 #>