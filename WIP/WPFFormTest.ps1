# PowerShell WPF GUI - Displays a window with a counter tracking the uptime of the hardest working PC in the Ops Team!
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
[xml]$Xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    x:Name="Window" Title="Maneesha's Uptime Counter" WindowStartupLocation="CenterScreen"
    ResizeMode="NoResize" SizeToContent="Width" Height="200">
        <Label Content="" x:Name="Counter" HorizontalAlignment="Center" VerticalAlignment="Top"
        Foreground="Black" FontFamily="Courier New" FontSize="24" Margin="10,0,10,0"/>
</Window>
"@

# Create a new window object with the form parameters above
$Window=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $Xaml))

$Window.TopMost = $true
$WindowClosed = $false

# Handle the window being closed by the 'X' button
$Window.add_Closing({
    $Script:WindowClosed = $true
})

$Counter = $Window.FindName("Counter")

# Generate and display the dynamically updating content
$Window.Add_ContentRendered({
    $BootTime = ([Management.ManagementDateTimeConverter]::ToDateTime((Get-WmiObject `
        Win32_OperatingSystem -ComputerName 'QSQ-3SCSU5-PC').LastBootUpTime))
    do {
        $UpTime = (New-TimeSpan -Start $BootTime -End (Get-Date))
        $Counter.Content = ($UpTime | Select-Object Days,Hours,Minutes,Seconds | Out-String)
        $Window.Dispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::ContextIdle);
        Start-Sleep 1
    } until ($WindowClosed)
})

$Window.ShowDialog() | Out-Null
