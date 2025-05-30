Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Get version from assembly metadata
function Get-Version {
    try {
        $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        # If running as script, $exePath will be powershell.exe or pwsh.exe
        $exeName = [System.IO.Path]::GetFileName($exePath).ToLower()

        if ($exeName -in @("powershell.exe", "pwsh.exe")) {
            # Running as a script - no version to show
            return "debug"
        }

        $fileVersionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath)
        $version = $fileVersionInfo.ProductVersion
        # If no version info present, return empty string
        if ([string]::IsNullOrWhiteSpace($version)) { return "" }

        return "v$version"
    }
    catch {
        # Any errors fallback to empty string to avoid showing "Unknown"
        return ""
    }
}


$scriptVersion = Get-Version

# Single instance mutex
$mutexName = "Global\USBMonitorMutex"
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($false, $mutexName, [ref]$createdNew)
if (-not $createdNew) {
    $tray = New-Object System.Windows.Forms.NotifyIcon
    $tray.Icon = [System.Drawing.SystemIcons]::Warning
    $tray.Visible = $true
    $tray.BalloonTipIcon = "Warning"
    $tray.BalloonTipTitle = "USB Monitor"
    $tray.BalloonTipText = "Another instance is already running."
    $tray.ShowBalloonTip(3000)
    Start-Sleep -Seconds 1
    $tray.Dispose()
    exit
}

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

# Log application start
Log-USBEvent "Application started."

# Get running executable path (this works whether running as script or bundled exe)
$exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName

# Create tray icon and context menu
$trayIcon = New-Object System.Windows.Forms.NotifyIcon

try {
    # Extract icon from the executable itself (embedded icon)
    $trayIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($exePath)
} catch {
    # Fallback to default system icon if extraction fails
    $trayIcon.Icon = [System.Drawing.SystemIcons]::Information
}

$trayIcon.Text = "USB Monitor"
$trayIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# Add version menu item at top
$versionItem = New-Object System.Windows.Forms.ToolStripMenuItem
$versionItem.Text = "USB Monitor $scriptVersion"
$versionItem.ToolTipText = "Click to open GitHub repository"
$versionItem.Image = [System.Drawing.SystemIcons]::Information.ToBitmap()
$versionItem.Add_Click({
    Start-Process "https://github.com/joanroig/usb-monitor"
})
$contextMenu.Items.Add($versionItem) | Out-Null

# Show Logs menu item
$showLogsItem = New-Object System.Windows.Forms.ToolStripMenuItem
$showLogsItem.Text = "Show Logs"
$showLogsItem.Image = [System.Drawing.SystemIcons]::Application.ToBitmap()
$showLogsItem.Add_Click({
    Start-Process "notepad.exe" -ArgumentList "`"$logFile`""
})
$contextMenu.Items.Add($showLogsItem) | Out-Null

# Exit menu item
$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = "Exit"
$exitItem.Image = [System.Drawing.SystemIcons]::Error.ToBitmap()
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
$psInstance.BeginInvoke() | Out-Null

# Start the Windows Forms message loop to keep tray icon responsive
[System.Windows.Forms.Application]::Run()

# Log application stop
Log-USBEvent "Application stopped."

# Cleanup if the application exits
$psInstance.Dispose()
$runspace.Close()
$runspace.Dispose()
$trayIcon.Dispose()

# Release mutex at exit
if ($mutex.WaitOne(0)) { $mutex.ReleaseMutex() }
