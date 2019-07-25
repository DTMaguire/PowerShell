# PowerShell GUI to launch AdminTools running with Domain Admin credentials version 1.0 - Copyright DM Tech 2019
# 
# This script works by looking for shortcuts (.lnk files) in the current directory and generating a list of buttons on a form for one-click access
# The idea being that you copy regularly used links of Administrative Tools to a directory along side this script
# This script is then run with your Domain Admin account credentials, which in turn launches the tools as a Domain Admin
#
# Assuming the path to this script is "D:\AdminTools\PSAdminTools.ps1" you can create a shortcut like this:
# C:\Windows\System32\runas.exe /user:DOMAIN\ADAdminAccount /savecred "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -File D:\AdminTools\PSAdminTools.ps1"

Function Hide-ConsoleWindow {

    Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("Kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);'
    $ConsolePtr = [Console.Window]::GetConsoleWindow()
    [Console.Window]::ShowWindow($ConsolePtr, 0)
}

Function Generate-Form {

    # Hide background console window

    Hide-ConsoleWindow

    Add-Type -AssemblyName System.Windows.Forms    
    Add-Type -AssemblyName System.Drawing
    
    # Generate Tools array
    
    $Tools = @(Get-ChildItem -Path $PSScriptRoot | where -Property Name -like *.lnk | select Name,FullName)

    # Check OS Version to size form correctly
    
    $WinVer = [version](Get-CimInstance Win32_OperatingSystem).version

    # Create form sizing variables - can be reduced for a more compact interface

    $ButtonHeight = 45
    $ButtonYSpacing = 50
    $TitleYPos = ($ButtonYSpacing / 4)
    If ($WinVer -lt [version]6.2) {
        $FormWidth = 240
        $ButtonWidth = ($FormWidth - 26)
        $FormHeight = ($ButtonHeight * 1.75) + ($ButtonYSpacing * $Tools.Count)
        $TitleXPos = ($FormWidth / 50)
        $TitleFont = 'Microsoft Sans Serif, 9'
        }
    Else {
        $FormWidth = 258
        $ButtonWidth = ($FormWidth - 58)
        $FormHeight = ($ButtonHeight * 2.25) + ($ButtonYSpacing * $Tools.Count)
        $TitleXPos = ($FormWidth / 100)
        $TitleFont = 'Microsoft Sans Serif, 10'
        }
    $ButtonXPos = ($FormWidth - $ButtonWidth) / 3 # Looks about right

    # Build form
    
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "PSAdminTools"
    $Form.Size = New-Object System.Drawing.Size($FormWidth,$FormHeight)
    $Form.StartPosition = "CenterScreen"
    $Form.Topmost = $True
    $Form.FormBorderStyle = 'Fixed3D'
    $Form.MaximizeBox = $False

    # Add title
    
    $Title = New-Object system.Windows.Forms.Label
    $Title.Text = "DM's PowerShell AdminTools Launcher"
    $Title.AutoSize = $True
    $Title.Font = $TitleFont
    $Title.Location = New-Object System.Drawing.Point($TitleXPos,$TitleYPos)
    $Form.Controls.Add($Title)

    # Dynamically add Buttons  
    
    ForEach ($Tool in $Tools) {
            $ButtonYPos = $ButtonHeight + ($ButtonYSpacing * $Tools.IndexOf($Tool))
            $Button = New-Object System.Windows.Forms.Button
            $Button.Location = New-Object System.Drawing.Size($ButtonXPos,$ButtonYPos)
            $Button.Size = New-Object System.Drawing.Size($ButtonWidth,$ButtonHeight)
            $Button.Text = $Tool.Name -replace (".lnk","")
            $LaunchTool = [System.Management.Automation.ScriptBlock]::Create("Invoke-Item '$($Tool.FullName)'")
            $Button.Add_Click($LaunchTool)
            $Form.Controls.Add($Button)
     }

    # Show the Form 

    $Form.ShowDialog()| Out-Null 
}

Generate-Form 
