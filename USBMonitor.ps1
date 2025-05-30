Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Setup paths
$logPath = "$([Environment]::GetFolderPath('ApplicationData'))\USBMonitor"
$logFile = "$logPath\usb_log.txt"
if (!(Test-Path $logPath)) { New-Item -ItemType Directory -Path $logPath -Force | Out-Null }

# Logging function
function Log-USBEvent {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp`t$message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# Create tray icon and context menu
$trayIcon = New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Icon = [System.Drawing.SystemIcons]::Information
$trayIcon.Text = "USB Monitor"
$trayIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# Show Logs menu item
$showLogsItem = New-Object System.Windows.Forms.ToolStripMenuItem
$showLogsItem.Text = "Show Logs"
$showLogsItem.Add_Click({
    Start-Process "notepad.exe" -ArgumentList "`"$logFile`""
})
$contextMenu.Items.Add($showLogsItem) | Out-Null

# Exit menu item
$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = "Exit"
$exitItem.Add_Click({
    $trayIcon.Visible = $false
    $trayIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})
$contextMenu.Items.Add($exitItem) | Out-Null

$trayIcon.ContextMenuStrip = $contextMenu

# Function to get current USB devices
function Get-USBDevices {
    Get-PnpDevice -PresentOnly |
        Where-Object { $_.InstanceId -like 'USB*' } |
        ForEach-Object { $_.InstanceId, $_.FriendlyName -join '|' }
}

# Variables for device tracking
$existingDevices = @{}

# Initial device snapshot
foreach ($dev in Get-USBDevices) { $existingDevices[$dev] = $true }

# Notification function
function Show-Notification {
    param([string]$title, [string]$message)
    $trayIcon.BalloonTipIcon = "Info"
    $trayIcon.BalloonTipTitle = $title
    $trayIcon.BalloonTipText = $message
    $trayIcon.ShowBalloonTip(1000)
}

# Start monitoring in a runspace (separate thread)
$scriptBlock = {
    param($existingDevices, $trayIcon, $logFile)

    while ($true) {
        $currentDevices = @{}
        $devices = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like 'USB*' }
        foreach ($dev in $devices) {
            $key = "$($dev.InstanceId)|$($dev.FriendlyName)"
            $currentDevices[$key] = $true
        }

        # Check for new devices
        foreach ($dev in $currentDevices.Keys) {
            if (-not $existingDevices.ContainsKey($dev)) {
                $name = ($dev -split '\|')[1]
                $trayIcon.BalloonTipIcon = "Info"
                $trayIcon.BalloonTipTitle = "USB Device Connected"
                $trayIcon.BalloonTipText = $name
                $trayIcon.ShowBalloonTip(1000)
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                "$timestamp`tCONNECTED: $name" | Out-File -FilePath $logFile -Append -Encoding UTF8
            }
        }

        # Check for removed devices
        foreach ($dev in $existingDevices.Keys) {
            if (-not $currentDevices.ContainsKey($dev)) {
                $name = ($dev -split '\|')[1]
                $trayIcon.BalloonTipIcon = "Info"
                $trayIcon.BalloonTipTitle = "USB Device Disconnected"
                $trayIcon.BalloonTipText = $name
                $trayIcon.ShowBalloonTip(1000)
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                "$timestamp`tDISCONNECTED: $name" | Out-File -FilePath $logFile -Append -Encoding UTF8
            }
        }

        $existingDevices.Clear()
        $currentDevices.Keys | ForEach-Object { $existingDevices[$_] = $true }

        Start-Sleep -Milliseconds 500
    }
}

# Create a runspace for monitoring so UI stays responsive
$runspace = [runspacefactory]::CreateRunspace()
$runspace.ApartmentState = 'STA'
$runspace.ThreadOptions = 'ReuseThread'
$runspace.Open()

$psInstance = [powershell]::Create()
$psInstance.Runspace = $runspace
$psInstance.AddScript($scriptBlock).AddArgument($existingDevices).AddArgument($trayIcon).AddArgument($logFile) | Out-Null
$psInstance.BeginInvoke()

# Start the Windows Forms message loop to keep tray icon responsive
[System.Windows.Forms.Application]::Run()

# Cleanup if the application exits
$psInstance.Dispose()
$runspace.Close()
$runspace.Dispose()
$trayIcon.Dispose()
