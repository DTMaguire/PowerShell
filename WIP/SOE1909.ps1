# .Net methods for hiding/showing the console in the background
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
function Hide-Console
{
    $consolePtr = [Console.Window]::GetConsoleWindow()
    #0 hide
    [Console.Window]::ShowWindow($consolePtr, 0)
}

Hide-Console

# Record script start time
$StartTime = $(Get-Date)

# Install logging framework from PS Gallery, create and set path
If (!(Get-InstalledModule PSFramework)) {
    Install-Module PSFramework -Force -confirm:$false
}
Import-Module PSFramework
$path = "C:\Windows\SOE"
If(!(test-path $path))
{
    New-Item -ItemType Directory -Force -Path $path
}
Set-PSFLoggingProvider -Name logfile -FilePath "$path\SOERunLog_%computername%_%date%.csv" -Enabled $true

# Start logging
Write-PSFMessage -Level Verbose -Message "SOE run started"

Write-PSFMessage -Level Debug -Message "Creating Registry PSDrive"
New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT

$SOERegistryPath = 'HKLM:\Software\LRS\SOE'
function Set-SOERegistryPath {
    If (!(Test-Path $SOERegistryPath)) {
        New-Item -Path $SOERegistryPath -Force | Out-Null
    }    
}

function Test-RegistryKeyValue
{
    <#
    .SYNOPSIS
    Tests if a registry value exists.
     
    .DESCRIPTION
    The usual ways for checking if a registry value exists don't handle when a value simply has an empty or null value. This function actually checks if a key has a value with a given name.
     
    .EXAMPLE
    Test-RegistryKeyValue -Path 'hklm:\Software\Carbon\Test' -Name 'Title'
     
    Returns `True` if `hklm:\Software\Carbon\Test` contains a value named 'Title'. `False` otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        # The path to the registry key where the value should be set. Will be created if it doesn't exist.
        $Path,
        
        [Parameter(Mandatory=$true)]
        [string]
        # The name of the value being set.
        $Name
    )

    if( -not (Test-Path -Path $Path -PathType Container) )
    {
        return $false
    }
    
    $properties = Get-ItemProperty -Path $Path 
    if( -not $properties )
    {
        return $false
    }
    
    $member = Get-Member -InputObject $properties -Name $Name
    if( $member )
    {
        return $true
    }
    else
    {
        return $false
    }
}

# Set Windows Locale to Australia
Function WindowsLocale {
	Write-PSFMessage -Level Debug -Message "Function started"
    Set-WinSystemLocale en-AU
    
    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "WindowsLocale" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Enable Printer AutoSetup on Private networks
Function PrinterAutoSetup {
	Write-PSFMessage -Level Debug -Message "Function started"
    If (!(Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\NcdAutoSetup\Private")) {
		New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\NcdAutoSetup\Private" -Force | Out-Null
	}
	Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\NcdAutoSetup\Private' -Name 'AutoSetup' -Value 1
    
    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "PrinterAutoSetup" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Enable random MAC for WiFi adapter
Function EnableRandomMAC {
	Write-PSFMessage -Level Debug -Message "Function started"
    $WiFi = Get-NetAdapter -Name "Wi-Fi"
    $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}"
    ($Key = Get-ItemProperty -Path "$RegPath\*" -Name "AdapterModel") 2> $Null
    If ($Key.AdapterModel -eq $WiFi.InterfaceDescription){
        New-ItemProperty -Path "$RegPath\$($Key.PSChildName)" -Name "NetworkAddress" -Value $($WiFi.MacAddress) -PropertyType String -Force
    }

    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "EnableRandomMAC" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Disable Feedback
Function DisableFeedback {
	Write-PSFMessage -Level Debug -Message "Function started"
	Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClient" -ErrorAction SilentlyContinue | Out-Null
	Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload" -ErrorAction SilentlyContinue | Out-Null

    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "DisableFeedback" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Enable F8 boot menu options
Function EnableF8BootMenu {
	Write-PSFMessage -Level Debug -Message "Function started"
	& bcdedit /set `{current`} BootMenuPolicy Legacy | Out-Null
    
    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "EnableF8BootMenu" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Set Data Execution Prevention (DEP) policy to OptOut (Turn on DEP for all programs and services except selected)
Function SetDEPOptOut {
	Write-PSFMessage -Level Debug -Message "Function started"
	& bcdedit /set `{current`} nx OptOut | Out-Null
    
    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "SetDEPOptOut" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Enable Local-Link Discovery Protocol (LLDP) for all installed network interfaces
Function EnableLLDP {
	Write-PSFMessage -Level Debug -Message "Function started"
	Enable-NetAdapterBinding -Name "*" -ComponentID "ms_lldp"
    
    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "EnableLLDP" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Enable System Restore for system drive to 5% of storage
Function EnableRestorePoints {
	Write-PSFMessage -Level Debug -Message "Function started"
	Enable-ComputerRestore -Drive "$env:SYSTEMDRIVE"
    & vssadmin Resize ShadowStorage /On=$env:SYSTEMDRIVE /For=$env:SYSTEMDRIVE /MaxSize=5%
    
    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "EnableRestorePoints" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Disable sleep when connected to power
Function DisableSleepOnPower {
	Write-PSFMessage -Level Debug -Message "Function started"
    & powercfg.exe X -standby-timeout-ac 0
    
    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "DisableSleepOnPower" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Start and enable Superfetch service
Function EnableSuperfetch {
	Write-PSFMessage -Level Debug -Message "Function started"
	Set-Service "SysMain" -StartupType Automatic
	Start-Service "SysMain" -WarningAction SilentlyContinue

    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "EnableSuperfetch" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Install .NET Framework 2.0, 3.0 and 3.5 runtimes - Requires internet connection
Function InstallNET23 {
	Write-PSFMessage -Level Debug -Message "Function started"
	If ((Get-CimInstance -Class "Win32_OperatingSystem").ProductType -eq 1) {
		Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -NoRestart -WarningAction SilentlyContinue | Out-Null
	} Else {
		Install-WindowsFeature -Name "NET-Framework-Core" -WarningAction SilentlyContinue | Out-Null
	}

    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "InstallNET23" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Set Photo Viewer association for bmp, gif, jpg, png and tif
Function SetPhotoViewerAssociation {
	Write-PSFMessage -Level Debug -Message "Function started"
	If (!(Test-Path "HKCR:")) {
		New-PSDrive -Name "HKCR" -PSProvider "Registry" -Root "HKEY_CLASSES_ROOT" | Out-Null
	}
	ForEach ($type in @("Paint.Picture", "giffile", "jpegfile", "pngfile")) {
		New-Item -Path $("HKCR:\$type\shell\open") -Force | Out-Null
		New-Item -Path $("HKCR:\$type\shell\open\command") | Out-Null
		Set-ItemProperty -Path $("HKCR:\$type\shell\open") -Name "MuiVerb" -Type ExpandString -Value "@%ProgramFiles%\Windows Photo Viewer\photoviewer.dll,-3043"
		Set-ItemProperty -Path $("HKCR:\$type\shell\open\command") -Name "(Default)" -Type ExpandString -Value "%SystemRoot%\System32\rundll32.exe `"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen %1"
	}

    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "SetPhotoViewerAssociation" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Add Photo Viewer to 'Open with...'
Function AddPhotoViewerOpenWith {
	Write-PSFMessage -Level Debug -Message "Function started"
	If (!(Test-Path "HKCR:")) {
		New-PSDrive -Name "HKCR" -PSProvider "Registry" -Root "HKEY_CLASSES_ROOT" | Out-Null
	}
	New-Item -Path "HKCR:\Applications\photoviewer.dll\shell\open\command" -Force | Out-Null
	New-Item -Path "HKCR:\Applications\photoviewer.dll\shell\open\DropTarget" -Force | Out-Null
	Set-ItemProperty -Path "HKCR:\Applications\photoviewer.dll\shell\open" -Name "MuiVerb" -Type String -Value "@photoviewer.dll,-3043"
	Set-ItemProperty -Path "HKCR:\Applications\photoviewer.dll\shell\open\command" -Name "(Default)" -Type ExpandString -Value "%SystemRoot%\System32\rundll32.exe `"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen %1"
	Set-ItemProperty -Path "HKCR:\Applications\photoviewer.dll\shell\open\DropTarget" -Name "Clsid" -Type String -Value "{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}"
    
    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "AddPhotoViewerOpenWith" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Install Chocolatey & 3rd party apps
# user-agent is "chocolatey command line"
Function InstallChocolateyAndApps {
	Write-PSFMessage -Level Debug -Message "Function started"
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    & choco install pswindowsupdate 7zip flashplayerplugin googlechrome firefox notepadplusplus silverlight paint.net adobeair cisco-proximity ghostscript jre8 jre6 cutepdf visioviewer dymo-label passwordsafe vstor2010 setuserfta setdefaultbrowser choco-upgrade-all-at-startup nircmd dotnet3.5 -y --ignore-checksums
    If(Get-WmiObject -Class:Win32_ComputerSystem -Filter:"MANUFACTURER LIKE 'LENOVO'" -ComputerName:localhost) {
        & choco install lenovo-thinkvantage-system-update -y --ignore-checksums
    }
    If(Get-WmiObject -Class:Win32_ComputerSystem -Filter:"MANUFACTURER LIKE '%DELL%'" -ComputerName:localhost) {
        & choco install DellCommandUpdate -y --ignore-checksums
    }
#    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "InstallChocolateyAndApps" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Install non-chocalatey software
Function InstallNonChocolateyApps {
    Write-PSFMessage -Level Debug -Message "Function started"
	# Install Ofice 365
	Expand-Archive -LiteralPath C:\Windows\SOE\O365.zip -DestinationPath "C:\Windows\SOE\Office" -Force
	Start-Process -wait "C:\Windows\SOE\Office\O365\setup.exe" -ArgumentList '/Configure C:\Windows\SOE\Office\O365\configuration.xml' -WindowStyle Hidden
	
	# Install DjVU
    start-Process msiexec -wait -argumentlist '/i "https://www2.cuminas.jp/wp-content/themes/cuminas/dlfile.php?pid=1&cid=134&lng=en&rev=35472" /q'
	
	# Install Adobe Creative Cloud
	start-Process msiexec -wait -argumentlist '/i "c:\Windows\SOE\Creative Cloud Desktop (User-as-Admin).msi" /qn'
	
	# Install Adobe Reader
	Start-Process C:\Windows\SOE\AcroRdrDC1901020064_MUI.exe -wait -argumentlist '/sAll /msi /norestart /quiet ALLUSERS=1 EULA_ACCEPT=YES'
	Start-Process msiexec -wait -argumentlist '/p "c:\Windows\SOE\AcroRdrDCUpd1902120061_MUI.msp" /norestart /quiet ALLUSERS=1 EULA_ACCEPT=YES'
	
	# Install GlobalProtect
	start-Process msiexec -wait -argumentlist '/i c:\Windows\SOE\GlobalProtect64.msi /qn PORTAL="ra.nswlrs.com.au" CONNECTMETHOD="on-demand" SHOWSYSTEMTRAYNOTIFICATIONS="no" CANSAVEPASSWORD="no"'
    
    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "InstallNonChocolateyApps" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Stop edge from taking over as the default .PDF viewer
Function EdgeStopTakeOver {
	Write-PSFMessage -Level Debug -Message "Function started"
    New-PSDrive HKU Registry HKEY_USERS
    reg load HKU\Default_User C:\Users\Default\NTUSER.DAT
    
    $appBlacklist = 'Edge','Photos'
    
    # regex
    # strip prefix and "\Application" from reg path 
    $pathRegexReplace = ".*(Registry\:\:.*)\\Application"
    
    $regSearchBase = "HKU:\Default_User\SOFTWARE\Classes\*\Application"
    
    # loop over search base 
    Get-ChildItem $regSearchBase -ea SilentlyContinue |  
    ForEach-Object {
        # match blacklisted apps
        foreach($app in $appBlacklist){
            if((get-itemproperty -Path $_.PsPath).AppUserModelID -match $app) 
            {  
                $regPath = $_.PSPath -replace $pathRegexReplace,'$1'
    
                # set NoOpenWith property to blacklisted app
                Set-ItemProperty -Path $regPath -Name NoOpenWith -Force -ea SilentlyContinue | Out-Null
            }
        }
    }
    
    REG UNLOAD HKU\Default_User
    Remove-PSDrive HKU

    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "EdgeStopTakeOver" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Debloat Windows 10 by uninstalling MS useless apps
Function DebloatW10 {
	Write-PSFMessage -Level Debug -Message "Function started"
    #Removes AppxPackages
    #Credit to Reddit user /u/GavinEke for a modified version of my whitelist code
    [regex]$WhitelistedApps = 'Microsoft.ScreenSketch|Microsoft.Paint3D|Microsoft.WindowsCalculator|Microsoft.WindowsStore|Microsoft.Windows.Photos|CanonicalGroupLimited.UbuntuonWindows|Microsoft.MicrosoftStickyNotes|Microsoft.MSPaint|Microsoft.WindowsCamera|.NET|Framework|Microsoft.HEIFImageExtension|Microsoft.ScreenSketch|Microsoft.StorePurchaseApp|Microsoft.VP9VideoExtensions|Microsoft.WebMediaExtensions|Microsoft.WebpImageExtension|Microsoft.DesktopAppInstaller'
    Get-AppxPackage -AllUsers | Where-Object {$_.Name -NotMatch $WhitelistedApps} | Remove-AppxPackage -ErrorAction SilentlyContinue
    # Run this again to avoid error on 1803 or having to reboot.
    Get-AppxPackage -AllUsers | Where-Object {$_.Name -NotMatch $WhitelistedApps} | Remove-AppxPackage -ErrorAction SilentlyContinue
    $AppxRemoval = Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -NotMatch $WhitelistedApps} 
    ForEach ( $App in $AppxRemoval) {
    
        Remove-AppxProvisionedPackage -Online -PackageName $App.PackageName 
        
        }

    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "DebloatW10" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Remove Windows Mail
Function RemoveWinMail {
	Write-PSFMessage -Level Debug -Message "Function started"
    Get-AppxPackage -AllUsers Microsoft.windowscommunicationsapps | Remove-AppxPackage -ErrorAction SilentlyContinue
    
    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "RemoveWinMail" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Debloat Windows 10 by uninstalling MS useless keys
Function DebloatKeysW10 {
	Write-PSFMessage -Level Debug -Message "Function started"
    #These are the registry keys that it will delete.
        
    $Keys = @(
        
        #Remove Background Tasks
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\46928bounde.EclipseManager_2.2.4.51_neutral__a5h4egax66k6y"
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.MicrosoftOfficeHub_17.7909.7600.0_x64__8wekyb3d8bbwe"
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.PPIProjection_10.0.15063.0_neutral_neutral_cw5n1h2txyewy"
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxGameCallableUI_1000.15063.0.0_neutral_neutral_cw5n1h2txyewy"
        "HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\Microsoft.XboxGameCallableUI_1000.16299.15.0_neutral_neutral_cw5n1h2txyewy"
        
        #Windows File
        "HKCR:\Extensions\ContractId\Windows.File\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
        
        #Registry keys to delete if they aren't uninstalled by RemoveAppXPackage/RemoveAppXProvisionedPackage
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\46928bounde.EclipseManager_2.2.4.51_neutral__a5h4egax66k6y"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\Microsoft.PPIProjection_10.0.15063.0_neutral_neutral_cw5n1h2txyewy"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\Microsoft.XboxGameCallableUI_1000.15063.0.0_neutral_neutral_cw5n1h2txyewy"
        "HKCR:\Extensions\ContractId\Windows.Launch\PackageId\Microsoft.XboxGameCallableUI_1000.16299.15.0_neutral_neutral_cw5n1h2txyewy"
        
        #Scheduled Tasks to delete
        "HKCR:\Extensions\ContractId\Windows.PreInstalledConfigTask\PackageId\Microsoft.MicrosoftOfficeHub_17.7909.7600.0_x64__8wekyb3d8bbwe"
        
        #Windows Protocol Keys
        "HKCR:\Extensions\ContractId\Windows.Protocol\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
        "HKCR:\Extensions\ContractId\Windows.Protocol\PackageId\Microsoft.PPIProjection_10.0.15063.0_neutral_neutral_cw5n1h2txyewy"
        "HKCR:\Extensions\ContractId\Windows.Protocol\PackageId\Microsoft.XboxGameCallableUI_1000.15063.0.0_neutral_neutral_cw5n1h2txyewy"
        "HKCR:\Extensions\ContractId\Windows.Protocol\PackageId\Microsoft.XboxGameCallableUI_1000.16299.15.0_neutral_neutral_cw5n1h2txyewy"
           
        #Windows Share Target
        "HKCR:\Extensions\ContractId\Windows.ShareTarget\PackageId\ActiproSoftwareLLC.562882FEEB491_2.6.18.18_neutral__24pqs290vpjk0"
    )
    
    #This removes the keys listed above.
    ForEach ($Key in $Keys) {
        Remove-Item $Key -Recurse -ErrorAction SilentlyContinue
    }

    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "DebloatW10Keys" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}


# Preferences with default profile edits
Function DefaultUserPreferences {
	Write-PSFMessage -Level Debug -Message "Function started"
    New-PSDrive HKU Registry HKEY_USERS
    reg load HKU\Default_User C:\Users\Default\NTUSER.DAT
    
    # Set App Associations
    If (!(Test-Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\RunOnce")) {
		New-Item -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "DefaultBrowser" -Type String -Value "C:\ProgramData\chocolatey\bin\SetDefaultBrowser.exe chrome"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "DefaultPDF" -Type String -Value "C:\ProgramData\chocolatey\bin\SetUserFTA.exe .pdf AcroExch.Document.DC"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "DefaultMail" -Type String -Value "C:\ProgramData\chocolatey\bin\SetUserFTA.exe mailto Outlook.URL.mailto.15"
    
    <# Shows all folders in the left NavPane of File Explorer
    If (!(Test-Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced")) {
		New-Item -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Force | Out-Null
	}
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name NavPaneShowAllFolders -Value 1
    #>
    # Disable Application suggestions and automatic installation
    If (!(Test-Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager")) {
		New-Item -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Force | Out-Null
	}
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name ContentDeliveryAllowed -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name SystemPaneSuggestionsEnabled -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name SilentInstalledAppsEnabled -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name PreInstalledAppsEnabled -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name PreInstalledAppsEverEnabled -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name OemPreInstalledAppsEnabled -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name SubscribedContent-310093Enabled -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name SubscribedContent-314559Enabled -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name SubscribedContent-338387Enabled -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name SubscribedContent-338388Enabled -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name SubscribedContent-338389Enabled -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name SubscribedContent-338393Enabled -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name SubscribedContent-338394Enabled -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name SubscribedContent-338396Enabled -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name SubscribedContent-338398Enabled -Value 0
    
    # Disable Feedback
    If (!(Test-Path "HKU:\Default_User\Software\Microsoft\Siuf\Rules")) {
		New-Item -Path "HKU:\Default_User\Software\Microsoft\Siuf\Rules" -Force | Out-Null
	}
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Siuf\Rules" -Name NumberOfSIUFInPeriod -Value 0
    
    # Set Classic Control Panel views
    If (!(Test-Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel")) {
		New-Item -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Force | Out-Null
	}
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name AllItemsIconView -Value 1
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel" -Name StartupPage -Value 1
    
    # Hide Cortana from taskbar
    If (!(Test-Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Search")) {
		New-Item -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Search" -Force | Out-Null
	}
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Search" -Name SearchboxTaskbarMode -Value 0
    
    # Open Windows Explorer in This PC
    If (!(Test-Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced")) {
		New-Item -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Force | Out-Null
	}
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name LaunchTo -Value 1
    
    # Show Full Address Path in Explorer
    If (!(Test-Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState")) {
		New-Item -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" -Force | Out-Null
	}
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" -Name FullPath -Value 1
    
    # Disable People & Ink Workspace icons in taskbar
    If (!(Test-Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People")) {
		New-Item -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Force | Out-Null
	}
    If (!(Test-Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\PenWorkspace")) {
		New-Item -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\PenWorkspace" -Force | Out-Null
	}
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name PeopleBand -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\PenWorkspace" -Name PenWorkspaceAppSuggestionsEnabled -Value 0
    Set-ItemProperty -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\PenWorkspace" -Name PenWorkspaceButtonDesiredVisibility -Value 0
	
	# Show Search Icon
	If (!(Test-Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Search")) {
		New-Item -Path "HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Search" -Force | Out-Null
	}
    Set-ItemProperty -Path 'HKU:\Default_User\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Value 1

    reg unload HKU\Default_User
    Remove-PSDrive HKU
    
    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "DefaultUserPreferences" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Enable BitLocker
Function EnableBitLocker {
	Write-PSFMessage -Level Debug -Message "Function started"
	Invoke-Gpupdate
	
	$CdriveStatus = Get-BitLockerVolume -MountPoint 'c:'

	if ($CdriveStatus.volumeStatus -eq 'FullyDecrypted') {
		C:\Windows\System32\manage-bde.exe -on c: -recoverypassword -skiphardwaretest
	}
	
    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "EnableBitLocker" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Enabled Automatic TimeZone detection
Function AutoTZ {
    Write-PSFMessage -Level Debug -Message "Function started"

	If (!(Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters")) {
		New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Force | Out-Null
	}
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "Type" -Type String -Value "NTP"
	
    If (!(Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate")) {
		New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate" -Force | Out-Null
	}
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate" -Name "Start" -Value 3
    
    
    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "AutoTZ" -Type String -Value "1909"
    Write-PSFMessage -Level Debug -Message "Function complete"
}

# Complete the SOE
Function CompleteSOE {
	Write-PSFMessage -Level Debug -Message "Function started"
    Set-SOERegistryPath
    Set-ItemProperty -Path $SOERegistryPath -Name "CompleteSOE" -Type String -Value "1909"
	Write-PSFMessage -Level Debug -Message "Function complete"
}

# Disable SSL Certificate Checking
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# Run all Functions
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'WindowsLocale')) {
	WindowsLocale
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: WindowsLocale"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'EnableRandomMAC')) {
	EnableRandomMAC
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: EnableRandomMAC"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'DisableFeedback')) {
	DisableFeedback
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: DisableFeedback"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'EnableF8BootMenu')) {
	EnableF8BootMenu
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: EnableF8BootMenu"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'SetDEPOptOut')) {
	SetDEPOptOut
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: SetDEPOptOut"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'EnableLLDP')) {
	EnableLLDP
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: EnableLLDP"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'EnableRestorePoints')) {
	EnableRestorePoints
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: EnableRestorePoints"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'DisableSleepOnPower')) {
	DisableSleepOnPower
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: DisableSleepOnPower"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'EnableSuperfetch')) {
	EnableSuperfetch
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: EnableSuperfetch"
	}
<#If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'InstallNET23')) {
	InstallNET23
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: InstallNET23"
	}#>
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'SetPhotoViewerAssociation')) {
	SetPhotoViewerAssociation
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: SetPhotoViewerAssociation"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'AddPhotoViewerOpenWith')) {
	AddPhotoViewerOpenWith
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: AddPhotoViewerOpenWith"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'InstallNonChocolateyApps')) {
	InstallNonChocolateyApps
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: InstallNonChocolateyApps"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'InstallChocolateyAndApps')) {
	InstallChocolateyAndApps
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: InstallChocolateyAndApps"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'EdgeStopTakeOver')) {
	EdgeStopTakeOver
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: EdgeStopTakeOver"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'DebloatW10')) {
	DebloatW10
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: DebloatW10"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'RemoveWinMail')) {
	RemoveWinMail
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: RemoveWinMail"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'DebloatKeysW10')) {
	DebloatKeysW10
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: DebloatKeysW10"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'DefaultUserPreferences')) {
	DefaultUserPreferences
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: DefaultUserPreferences"
	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'EnableBitLocker')) {
	EnableBitLocker
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: EnableBitLocker"
	}
#If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'UpdateWin')) {
#	UpdateWin
#	}
#   else {
#       Write-PSFMessage -Level Verbose -Message "Skipping: UpdateWin"
#	}
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'AutoTZ')) {
	AutoTZ
    }
    else {
    Write-PSFMessage -Level Verbose -Message "Skipping: AutoTZ"
    }
If (!(Test-RegistryKeyValue -Path $SOERegistryPath -Name 'CompleteSOE')) {
	CompleteSOE
	}
    else {
        Write-PSFMessage -Level Verbose -Message "Skipping: CompleteSOE"
	}

$ElapsedTime = $(Get-Date) - $StartTime
$ElapsedTimeString = "{0:HH:mm:ss}" -f ([datetime]$ElapsedTime.Ticks)

Write-PSFMessage -Level Verbose -Message "SOE run complete, elapsed time $ElapsedTimeString"