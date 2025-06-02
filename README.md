<p align="center">
  <a href="https://github.com/joanroig/usb-monitor">
      <img alt="USB Monitor logo" src="logo.png" width="140px">
  </a>
</p>

<h1 align="center">
  USB Monitor
</h1>

<p align="center">
  Lightweight USB activity tracker for Windows, with system tray integration and logging.
</p>

<p align="center">
  <a href="https://docs.microsoft.com/powershell/">
    <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-3178C6?style=flat&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgaWQ9InBvd2Vyc2hlbGwiPgogIDxwYXRoIGZpbGw9IiMxNDZGQkYiIGQ9Ik0uODE5IDIxaDE4LjIzYy41NjggMCAxLjEzNS0uNDYyIDEuMjY1LTEuMDMybDMuNjU5LTE1LjkzNmMuMTMxLS41Ny0uMjI0LTEuMDMyLS43OTItMS4wMzJINC45NTFjLS41NjggMC0xLjEzNS40NjItMS4yNjUgMS4wMzJMLjAyNyAxOS45NjhDLS4xMDQgMjAuNTM4LjI1MSAyMSAuODE5IDIxem0xNS42My00LjI5NWMuNTExIDAgLjkyNS40MTIuOTI4LjkyYS45MjYuOTI2IDAgMCAxLS45MjguOTJIMTIuMDFhLjkyNy45MjcgMCAwIDEtLjkzNC0uOTIuOTI2LjkyNiAwIDAgMSAuOTI4LS45Mmg0LjQ0NXptLTExLjYzOS4zMDYgNy40Mi01LjM1OHYtLjExTDcuNTY4IDYuNTk4Yy0uMzgtLjQwMy0uMzQxLTEuMDU1LjA4OC0xLjQ1Ny40MjktLjQwMiAxLjA4Ni0uNCAxLjQ2Ni4wMDRsNS41OTQgNS45MzRjLjMxNy4zMzcuMzQxLjg0Ni4wOSAxLjIzOS0uMDc2LjE1NC0uMjM0LjMyMi0uNTE0LjUxOWwtOC4yMjkgNS44OTJjLS40NDkuMzI2LTEuMDk0LjIwNS0xLjQ0LS4yNjktLjM0Ni0uNDc1LS4yNjMtMS4xMjMuMTg3LTEuNDQ5eiI+PC9wYXRoPgo8L3N2Zz4K&color=blue&labelColor=white"/>
  </a>
  <a href="https://github.com/joanroig/usb-monitor/releases">
    <img src="https://img.shields.io/github/v/release/joanroig/usb-monitor?&include_prereleases&label=version"/>
  </a>
  <a href="https://github.com/joanroig/usb-monitor/actions">
    <img alt="GitHub Actions Status" src="https://img.shields.io/github/actions/workflow/status/joanroig/usb-monitor/create-release.yml?branch=main"/>
  </a>
  <a href="https://github.com/joanroig/usb-monitor/blob/main/LICENSE">
    <img alt="MIT License" src="https://img.shields.io/github/license/joanroig/usb-monitor?color=blue">
  </a>
  <a href="https://github.com/joanroig/usb-monitor/issues">
    <img src="https://img.shields.io/github/issues/joanroig/usb-monitor"/>
  </a>
  <a href="https://github.com/joanroig/usb-monitor/stargazers">
    <img src="https://img.shields.io/github/stars/joanroig/usb-monitor">
  </a>
</p>

<p align="center">
  <img alt="Example" src="docs/example.png">
    <em>Example of a notification, and some contents of the log file</em>
</p>

## Features

- ⚡ Real-time monitoring of USB device connections and disconnections
- 💬 User-friendly balloon notifications displaying device names
- 🔄 Optional automatic startup with Windows for continuous monitoring
- 🖱️ Tray icon menu providing quick access to all functions
- 🗃️ Comprehensive log file saved at `%AppData%\USBMonitor\usb_log.txt`
- 💾 Persistent preferences stored in JSON
- 🧠 Single-instance enforcement to prevent multiple runs
- 🧩 No external dependencies, pure PowerShell

## How to use

### Installation

1. Download the latest version from the [Releases page](https://github.com/joanroig/usb-monitor/releases).
2. Unzip the `.exe` file and double-click it to run. The app sits in your system tray.

### Usage

- Right-click the tray icon to open the log file, configure the settings or quit the app.
- You’ll receive a balloon notification for each USB connection or disconnection if the notifications are activated. All activity is always stored in the log file.

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

Releases are fully automated via GitHub Actions. Check out the workflow defined in [`create-release.yml`](.github/workflows/create-release.yml), which builds and publishes new executables on the GitHub releases page.

## Credits

Icon from <a href="https://www.flaticon.com/free-icons/usb-flash-drive" title="usb-flash-drive icons">Flaticon</a> by Freepik.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more information.
