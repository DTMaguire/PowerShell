# PowerShell script to monitor the saved game file and create a backup whenever it changes
using namespace System.Diagnostics
using namespace System.IO

$SteamExe = [FileInfo](Get-ItemPropertyValue -Path 'HKCU:\SOFTWARE\Valve\Steam' -Name 'SteamExe')
Write-Host "`nLaunching Hellblade via Steam...`n" -ForegroundColor DarkRed
[void][Process]::Start($SteamExe, '-applaunch 414340'); Start-Sleep 10

$SaveFileName = 'HellbladeSave_0.sav'
$BackupDirName = 'Backup'

$SavePath = [Path]::Combine($Env:LOCALAPPDATA, 'HellbladeGame\Saved\SaveGames')
$BackupPath = [Path]::Combine($SavePath, $BackupDirName)

if (!([Directory]::Exists($BackupPath))) {
    [Directory]::CreateDirectory($BackupPath)
}

$Watcher = [FileSystemWatcher]::new()
$Watcher.Path = $SavePath
$Watcher.Filter = $SaveFileName
$Conditions = [WatcherChangeTypes]::Changed

function TestFile {
    param ($SaveFile)
    
    Try {
        $FileStream = [File]::Open($SaveFile,'Open','Write')
        $FileStream.Close()
        $FileStream.Dispose()

        return $true
    } Catch [System.UnauthorizedAccessException] {
        return 'AccessDenied'
    } Catch {
        return $false
    }
}

function BackupFile {
    param ($SaveFile)
    
    $Attempt = 0
    do {
        $Attempt++
        $Unlocked = TestFile $SaveFile

        Write-Host "Save Attempt $Attempt`: $Unlocked" -ForegroundColor DarkGray

        if ($Attempt -ge 1000 -or $Unlocked -match 'AccessDenied') {
            
            Write-Host "`nArrgh, something's broken!`n" -ForegroundColor Red
            return
        }
    } until ($Unlocked)

    $DateStamp = $SaveFile.LastWriteTime.GetDateTimeFormats('O').Split('.')[0] -replace '\-|:'
    $BackupFile = [Path]::Combine($BackupPath, $SaveFile.BaseName + '_' + $DateStamp + '.sav')

    Write-Host "$SaveFile -->`n$BackupFile`n" -ForegroundColor DarkMagenta
    [File]::Copy($SaveFile, $BackupFile)
}

while ([Process]::GetProcessesByName('HellbladeGame')) {
    
    $Result = $Watcher.WaitForChanged($Conditions, 1000)
    if ($Result.TimedOut) {
        continue
    }
    BackupFile ([FileInfo][Path]::Combine($SavePath, $SaveFileName))
}
Write-Host "`nGame process ended, script exiting...`n" -ForegroundColor DarkRed