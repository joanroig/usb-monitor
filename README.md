<p align="center">
  <a href="https://github.com/joanroig/usb-monitor">
      <img alt="USB Monitor logo" src="logo.png" width="140px">
  </a>
</p>

<h1 align="center">
  USB Monitor
</h1>

<p align="center">
  Lightweight USB device activity tracker with tray notifications and logging for Windows.
</p>

## Features

- Real-time detection and logging of USB device connections and disconnections on Windows.
- System tray balloon notifications display the events and device names.
- Single-instance enforcement with a notification if another instance is launched.
- Logs saved per user at `%AppData%\USBMonitor\usb_log.txt`.
- Easy tray icon menu to access logs or exit the application.
- No external dependencies; fully implemented in PowerShell.

## How to use

Download and execute the exe from the [releases page](https://github.com/joanroig/usb-monitor/releases).

- Once launched, USB Monitor runs in the system tray.
- Right-click the tray icon to open logs or exit the application.
- USB connection or disconnection events will trigger balloon notifications.

## Development

### Prerequisites

- Ensure you have **PowerShell 5.1 or later** installed on your Windows machine.  
  Windows 10+ includes this by default, but you can also use [PowerShell 7+](https://aka.ms/powershell) for enhanced features.

- Clone the repository locally:  
  `git clone https://github.com/joanroig/usb-monitor.git`  
  `cd usb-monitor`

### Running the Application

To run the USB Monitor script directly without building an executable, execute:

`powershell -ExecutionPolicy Bypass -File .\USBMonitor.ps1`

This starts the application in your current session.

### Building the Executable

USB Monitor uses **ps2exe** to package the PowerShell script as a standalone `.exe`:

1. Install the ps2exe module (requires internet):
   `Install-Module -Name ps2exe -Scope CurrentUser -Force`

2. Run the build script to generate the executable:  
   `.\bundle.ps1`  
   This script packages `USBMonitor.ps1` into an optimized executable located in the `dist` folder.

### Debugging with VSCode

VSCode launch configurations are provided in `.vscode/launch.json`:

- **PowerShell: Launch USBMonitor**  
  Runs `USBMonitor.ps1` directly for live debugging with breakpoints and console output.

- **PowerShell: Bundle USBMonitor**  
  Executes the build script (`bundle.ps1`) to create the executable, useful for verifying packaging steps.

To use these, open VSCode in the project directory, then open the Run and Debug panel and select the desired configuration.

### Automated Release

Releases are fully automated via GitHub Actions. Check out the workflow defined in [create-release.yml](.github/workflows/create-release.yml), which builds and publishes new executables on the GitHub releases page.

## Credits

Icon from <a href="https://www.flaticon.com/free-icons/usb-flash-drive" title="usb-flash-drive icons">Flaticon</a> by Freepik.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more information.
