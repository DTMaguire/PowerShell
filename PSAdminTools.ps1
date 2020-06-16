# PowerShell GUI form to launch Remote Server Admin Tools (RSAT) running with Domain Admin credentials 
# Version 1.4 - Copyright DM Tech 2020
# 
# This script enables a one-click launching of server admin tools from a workstation with standard domain user account.
# It works by looking for shortcuts (.lnk files) in a specified directory and generating a list of buttons on a form.
# The form itself runs under domain admin credentials - the subsequent shortcuts then run in the same security context.
#
# Usage: Copy regularly used links of Administrative Tools to a specified directory and update $ToolsPath below.
#
# Check the %DEVPATH% environment variable exists and create a shortcut somewhere with the target (one line):
#
#    C:\Windows\System32\runas.exe /user:DOMAIN\ADAdminAccount <--Replace with your Domain Admin--<
#    /savecred "C:\Program Files\PowerShell\7\pwsh.exe -NoProfile -File %DEVPATH%\PSAdminTools.ps1"
#
# Open the shortcut (not the ps1 file), enter your password once to save it in the Windows Credential Vault.
# Shortcuts can be added and removed from the $ToolsPath directory as required, but keep in mind your display height.
#
# The launch method doesn't work if the script or shortcuts are inside a user profile due to a Windows security feature.
# The simple fix is to move it to another folder outside of your profile or another drive.
#
# See also - PowerShell profile setup script which includes the RSAT Tools installation below:
#   https://github.com/DTMaguire/PowerShell/blob/master/Profile/SetupPSProfile.ps1

# Script variables
$ToolsPath = (Split-Path $Env:DevPath -Parent) + '\AdminTools'

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
    $Tools = @(Get-ChildItem -Path $ToolsPath -Filter *.lnk | Select-Object Name,FullName)

    # Create form sizing variables
    $FormWidth = 254
    $ButtonHeight = 40
    $ButtonYSpacing = 44
    $TitleXPos = 2
    $TitleYPos = ($ButtonYSpacing / 3)
    $ButtonWidth = ($FormWidth - 32)
    $ButtonXPos = ($FormWidth - $ButtonWidth) / 4
    $FormHeight = ($ButtonHeight * 2) + ($ButtonYSpacing * $Tools.Count) + 3
    $TitleFont = [System.Drawing.Font]::new('Microsoft Sans Serif', 10)

    # Build form
    $Form = [System.Windows.Forms.Form]::new()
    $Form.Size = [System.Drawing.Size]::new($FormWidth,$FormHeight)
    $Form.FormBorderStyle = 'FixedDialog'
    $Form.Text = 'PSAdminTools'
    $Form.MaximizeBox = $False
    $Form.Topmost = $False   # Sets to always on top

    # Add title
    $Title = [System.Windows.Forms.Label]::new()
    $Title.Text = "DM's PowerShell AdminTools Launcher"
    $Title.AutoSize = $True
    $Title.Font = $TitleFont
    $Title.Location = [System.Drawing.Point]::new($TitleXPos,$TitleYPos)
    $Form.Controls.Add($Title)

    # Dynamically add Buttons
    ForEach ($Tool in $Tools) {

            $ButtonYPos = $ButtonHeight + ($ButtonYSpacing * $Tools.IndexOf($Tool))
            $Button = [System.Windows.Forms.Button]::new()
            $Button.Location = [System.Drawing.Size]::new($ButtonXPos,$ButtonYPos)
            $Button.Size = [System.Drawing.Size]::new($ButtonWidth,$ButtonHeight)
            $Button.Text = $Tool.Name -replace ('.lnk','')
            $LaunchTool = [System.Management.Automation.ScriptBlock]::Create("Invoke-Item '$($Tool.FullName)'")
            $Button.Add_Click($LaunchTool)
            $Form.Controls.Add($Button)
     }

    # Finally, show the Form 
    $Form.ShowDialog()
}

GenerateForm
