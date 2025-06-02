Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Web.Extensions

# Get version from assembly metadata
function Get-Version {
    try {
        $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $exeName = [System.IO.Path]::GetFileName($exePath).ToLower()
        if ($exeName -in @("powershell.exe", "pwsh.exe")) { return "debug" }
        $fileVersionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath)
        $version = $fileVersionInfo.ProductVersion
        if ([string]::IsNullOrWhiteSpace($version)) { return "" }
        return "v$version"
    }
    catch { return "" }
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
$settingsFile = "$logPath\settings.json"
$startupRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$startupName = "USBMonitor"

if (!(Test-Path $logPath)) { New-Item -ItemType Directory -Path $logPath -Force | Out-Null }

# Get running executable path (this works whether running as script or bundled exe)
$exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName

# Load or initialize settings
if (Test-Path $settingsFile) {
    $json = Get-Content $settingsFile -Raw
    $settings = [System.Web.Script.Serialization.JavaScriptSerializer]::new().DeserializeObject($json)
    $global:notificationsEnabled = $settings["notificationsEnabled"]
    $global:startWithWindows = $settings["startWithWindows"]
} else {
    $global:notificationsEnabled = $true
    $global:startWithWindows = $false
    $defaultSettings = @{ notificationsEnabled = $true; startWithWindows = $false }
    $json = (New-Object System.Web.Script.Serialization.JavaScriptSerializer).Serialize($defaultSettings)
    $json | Out-File -FilePath $settingsFile -Encoding UTF8
}

# Save settings
function Save-Settings {
    $settings = @{
        notificationsEnabled = $global:notificationsEnabled
        startWithWindows = $global:startWithWindows
    }
    $json = (New-Object System.Web.Script.Serialization.JavaScriptSerializer).Serialize($settings)
    $json | Out-File -FilePath $settingsFile -Encoding UTF8
}

# Logging function
function Log-USBEvent {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp`t$message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# Function to update the startup entry in the registry
function Update-StartupEntry {
    if ($global:startWithWindows) {
        Set-ItemProperty -Path $startupRegPath -Name $startupName -Value "`"$exePath`"" -Force
    } else {
        Remove-ItemProperty -Path $startupRegPath -Name $startupName -ErrorAction SilentlyContinue
    }
}

# Add app in the registry and log application start
Update-StartupEntry
Log-USBEvent "Application started."

# Create tray icon and context menu
$trayIcon = New-Object System.Windows.Forms.NotifyIcon

try {
    # Extract icon from the executable itself (embedded icon)
    $trayIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($exePath)
} catch {
    $trayIcon.Icon = [System.Drawing.SystemIcons]::Information
}
$trayIcon.Text = "USB Monitor"
$trayIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

# Add version menu item at top
$versionItem = New-Object System.Windows.Forms.ToolStripMenuItem
$versionItem.Text = "USB Monitor $scriptVersion"
$versionItem.ToolTipText = "Click to open GitHub repository"
$versionItem.Image = [System.Drawing.SystemIcons]::Question.ToBitmap()
$versionItem.Add_Click({ Start-Process "https://github.com/joanroig/usb-monitor" })
$contextMenu.Items.Add($versionItem) | Out-Null

# Show Logs menu item
$showLogsItem = New-Object System.Windows.Forms.ToolStripMenuItem
$showLogsItem.Text = "Show Logs"
$showLogsItem.Image = [System.Drawing.SystemIcons]::Application.ToBitmap()
$showLogsItem.Add_Click({ Start-Process "notepad.exe" -ArgumentList "`"$logFile`"" })
$contextMenu.Items.Add($showLogsItem) | Out-Null

# Toggle notifications menu item
$notifyToggleItem = New-Object System.Windows.Forms.ToolStripMenuItem
function Update-NotifyMenuText {
    $notifyToggleItem.Text = if ($global:notificationsEnabled) { "Notifications: ENABLED" } else { "Notifications: DISABLED" }
}
Update-NotifyMenuText
$notifyToggleItem.Image = [System.Drawing.SystemIcons]::Information.ToBitmap()
$notifyToggleItem.Add_Click({
    $global:notificationsEnabled = -not $global:notificationsEnabled
    Update-NotifyMenuText
    Save-Settings
})
$contextMenu.Items.Add($notifyToggleItem) | Out-Null

# Toggle startup with Windows menu item
$startupToggleItem = New-Object System.Windows.Forms.ToolStripMenuItem
function Update-StartupMenuText {
    $startupToggleItem.Text = if ($global:startWithWindows) { "Start with Windows: ENABLED" } else { "Start with Windows: DISABLED" }
}
Update-StartupMenuText
$startupToggleItem.Image = [System.Drawing.SystemIcons]::Shield.ToBitmap()
$startupToggleItem.Add_Click({
    $global:startWithWindows = -not $global:startWithWindows
    Update-StartupMenuText
    Update-StartupEntry
    Save-Settings
})
$contextMenu.Items.Add($startupToggleItem) | Out-Null

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

# Start monitoring in a runspace (separate thread)
$scriptBlock = {
    param($existingDevices, $trayIcon, $logFile, $settingsFile)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Web.Extensions

    function Load-NotificationSetting {
        if (Test-Path $settingsFile) {
            $json = Get-Content $settingsFile -Raw
            $settings = [System.Web.Script.Serialization.JavaScriptSerializer]::new().DeserializeObject($json)
            return $settings["notificationsEnabled"]
        }
        return $true
    }

    while ($true) {
        $currentDevices = @{}
        $devices = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like 'USB*' }
        foreach ($dev in $devices) {
            $key = "$($dev.InstanceId)|$($dev.FriendlyName)"
            $currentDevices[$key] = $true
        }

        $notify = Load-NotificationSetting

        foreach ($dev in $currentDevices.Keys) {
            if (-not $existingDevices.ContainsKey($dev)) {
                $name = ($dev -split '\|')[1]
                if ($notify) {
                    $trayIcon.BalloonTipIcon = "Info"
                    $trayIcon.BalloonTipTitle = "USB Device Connected"
                    $trayIcon.BalloonTipText = $name
                    $trayIcon.ShowBalloonTip(1000)
                }
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                "$timestamp`tCONNECTED: $name" | Out-File -FilePath $logFile -Append -Encoding UTF8
            }
        }

        foreach ($dev in $existingDevices.Keys) {
            if (-not $currentDevices.ContainsKey($dev)) {
                $name = ($dev -split '\|')[1]
                if ($notify) {
                    $trayIcon.BalloonTipIcon = "Info"
                    $trayIcon.BalloonTipTitle = "USB Device Disconnected"
                    $trayIcon.BalloonTipText = $name
                    $trayIcon.ShowBalloonTip(1000)
                }
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
$psInstance.AddScript($scriptBlock).AddArgument($existingDevices).AddArgument($trayIcon).AddArgument($logFile).AddArgument($settingsFile) | Out-Null
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
$mutex.Dispose()
