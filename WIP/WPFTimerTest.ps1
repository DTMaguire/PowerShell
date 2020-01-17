# PowerShell WPF Timer GUI - Displays a window with a counter tracking the EOL of Windows 7
# Version 1.0 - Copyright DM Tech 2019

# Hides the background console when launched
Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);'
[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0)

Add-Type -Assembly PresentationFramework            
Add-Type -Assembly PresentationCore

# Define the elements of the form
# Remember - Margin="left,top,right,bottom"
[xml]$Xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    x:Name="CountdownTimer" Title="Windows 7 EOL Counter" WindowStartupLocation="CenterScreen"
    ResizeMode="NoResize" SizeToContent="WidthAndHeight">
    <StackPanel Margin="10">
        <Label x:Name="Heading" Content="Windows 7 EOL Countdown"  HorizontalAlignment="Center" VerticalAlignment="Top"
        Foreground="Black" FontFamily="Courier New" FontSize="24" Margin="16,8,20,0"/>
        <Label x:Name="Counter" Content="" HorizontalAlignment="Center" VerticalAlignment="Bottom"
        Foreground="Black" FontFamily="Courier New" FontSize="24" Margin="16,0,20,8"/>
    </StackPanel>
</Window>
"@

$Window=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $Xaml))

$Window.TopMost = $true
$TimerBox = $Window.FindName('Counter')

#Event handlers             
$Window.Add_SourceInitialized({
    # Specify Windows 7 EOL date variable         
    $Script:EndTime = (Get-Date -Year 2020 -Month 01 -Day 14 -Hour 12 -Minute 00 -Second 00)
    $Script:Timer = New-Object System.Windows.Threading.DispatcherTimer
    $Timer.Interval = [TimeSpan]'0:0:1.0'         
    $Timer.Add_Tick.Invoke($UpdateBlock)        
    $Timer.Start()
    if ($Timer.IsEnabled -eq $false) {
        Write-Warning "Timer didn't start!"
    }
})

$Window.add_Closing({
    $Script:Timer.Stop()
})

$UpdateBlock = ({
    $Script:Display = ((New-TimeSpan -End $Script:EndTime) | Select-Object Days,Hours,Minutes,Seconds | Out-String).TrimEnd()
    $Timerbox.Content = $Script:Display
})

$Window.ShowDialog() | Out-Null
