# PowerShell GUI form to launch Remote Server Admin Tools (RSAT) running with Domain Admin credentials 
# Version 1.2 - Copyright DM Tech 2019
# 
# This script was designed to enable a one-click launching of tools to manage servers from a workstation logged in with a standard user account
# It works by looking for shortcuts (.lnk files) in the current directory and generating a list of buttons on a form
#
# Usage: Copy regularly used links of Administrative Tools to a specified directory such as 'D:\AdminTools' and update the '$ToolsPath' variable
#
# Assuming the path to this script is 'D:\Scripts\PowerShell\PSAdminTools.ps1' create a shortcut somewhere handy with the target:
#   C:\Windows\System32\runas.exe /user:DOMAIN\ADAdminAccount /savecred "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -File D:\Scripts\PowerShell\PSAdminTools.ps1"
#
# Open the shortcut (not the ps1 file), enter your password once and you'll be set
#
# Shortcuts can be added and removed from the directory as desired, although the recommended maximum is 15 for a 1080p display
#
# *** On further testing, it looks like the launch method doesn't work if the script or files are located inside a user profile due to some Windows security feature
# The simple fix is to move it to another folder outside of your profile or another drive as described above!

# Global variables
$ToolsPath = "D:\AdminTools"

# Check OS Version to size form correctly
$WinVer = [version](Get-CimInstance Win32_OperatingSystem).version

Function HideConsoleWindow {

    Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("Kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);'

    $ConsolePtr = [Console.Window]::GetConsoleWindow()

    [Console.Window]::ShowWindow($ConsolePtr, 0)
}

Function GenerateForm {

    # Hide background console window
    HideConsoleWindow

    Add-Type -AssemblyName System.Windows.Forms    
    Add-Type -AssemblyName System.Drawing
    
    # Generate Tools array
    $Tools = @(Get-ChildItem -Path $ToolsPath | Where-Object -Property Name -like *.lnk | Select-Object Name,FullName)

    # Create form sizing variables - can be reduced for a more compact interface
    $ButtonHeight = 44
    $ButtonYSpacing = 50
    $TitleXPos = 0
    $TitleYPos = ($ButtonYSpacing / 4)

    # Windows 7 or earlier
    If ($WinVer -lt [version]6.2) {

        $FormWidth = 240
        $ButtonWidth = ($FormWidth - 40)
        $ButtonXPos = ($FormWidth - $ButtonWidth) / 4 # Looks about right
        $FormHeight = ($ButtonHeight * 2) + ($ButtonYSpacing * $Tools.Count)
        $TitleFont = 'Microsoft Sans Serif, 9'
    }
    Else {

        $FormWidth = 258
        $ButtonWidth = ($FormWidth - 40)
        $ButtonXPos = ($FormWidth - $ButtonWidth) / 3.6 # Looks about right
        $FormHeight = ($ButtonHeight * 2.25) + ($ButtonYSpacing * $Tools.Count)
        $TitleFont = 'Microsoft Sans Serif, 10'
    }

    # Build form
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = "PSAdminTools"
    $Form.Size = New-Object System.Drawing.Size($FormWidth,$FormHeight)
    $Form.Topmost = $True   # Sets to always on top
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

GenerateForm