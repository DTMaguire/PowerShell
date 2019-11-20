Add-Type -Assembly PresentationFramework            
Add-Type -Assembly PresentationCore

[xml]$Xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    x:Name="Window" Title="Maneesha's Uptime Counter" WindowStartupLocation="CenterScreen" ResizeMode="NoResize" SizeToContent="WidthandHeight">   
        <StackPanel>
            <Label Content="" x:Name="Counter" HorizontalAlignment="Center" VerticalAlignment="Top" Foreground="Black" FontFamily="Courier New" FontSize="20" Margin="10,10,10,0"/>
            <Button Name="ButtonClose" Content="Close" HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,0,0,10" Width="120px" Height="32px"/>
        </StackPanel>
</Window>
"@ 

$Reader=(New-Object System.Xml.XmlNodeReader $Xaml)
$Window=[Windows.Markup.XamlReader]::Load( $Reader )
$WindowClosed = $false
$Counter = $Window.FindName("Counter")
$ButtonClose = $Window.FindName("ButtonClose")

$ButtonClose.add_Click.Invoke({
    $Script:WindowClosed = $true
    $Window.Close();
})

$Window.add_Closing({
    $Script:WindowClosed = $true
})

$Window.Add_ContentRendered({    
    $BootTime = ([Management.ManagementDateTimeConverter]::ToDateTime((Get-WmiObject Win32_OperatingSystem -ComputerName 'QSQ-3SCSU5-PC').LastBootUpTime))
    do {
        $UpTime = (New-TimeSpan -Start $BootTime -End (Get-Date))
        $Counter.Content = ($UpTime | Select-Object Days,Hours,Minutes,Seconds | Out-String)
        $Window.Dispatcher.Invoke([Action]{},[Windows.Threading.DispatcherPriority]::ContextIdle);
        Start-Sleep 1
    } until ($WindowClosed)
})

$Window.ShowDialog() | Out-Null