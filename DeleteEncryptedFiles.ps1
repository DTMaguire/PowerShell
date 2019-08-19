## CryptoLocker File Removal Script - Version 2.0 by DM
##
## Re-written in response to muppet(s) CryptoLocking their network drives and scattering .encrypted files all over the place
## See: https://en.wikipedia.org/wiki/CryptoLocker
##
## As always, isolate and remove offending machines from the network first and deal with them seperately
## Run this script to remove the damage, then restore all files from backup and SKIP any existing files to avoid overwriting newer items
## 
## Define the root directory to be scanned as $Path, save and run the script from an elevated PowerShell prompt
## A log file will be place in the root directory with a list of all files identified and removed

$Path = "C:\Test"

$Dirs = Get-ChildItem -Path $Path -Recurse | Where-Object {$_.PsIsContainer}

Foreach ($Dir in $Dirs) {
    
    $Files = Get-ChildItem -Path $Dir.FullName | Where-Object {-not $_.PsIsContainer -and $_.name -like "*.encrypted"}
    Out-File -FilePath $Path\DeletedFiles.log -Append -InputObject $Files
    
    Foreach ($File in $Files) {
        
        $FilePath = Join-Path $Dir.FullName $File
        Remove-Item $FilePath -Force
        Write-Host "Deleting File: $FilePath"
    } 
}
