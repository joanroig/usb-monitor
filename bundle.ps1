# Read version from version.txt
$versionFile = ".\version.txt"
if (-not (Test-Path $versionFile)) {
    Write-Error "Version file not found at $versionFile"
    exit 1
}
$version = Get-Content $versionFile -Raw
$version = $version.Trim()

# Validate version format (basic check)
if (-not ($version -match '^\d+\.\d+\.\d+')) {
    Write-Warning "Version string '$version' does not appear to be in valid format (e.g. 1.0.0)"
}

# Create the dist directory if it doesn't exist
if (-not (Test-Path -Path ".\dist")) {
    New-Item -ItemType Directory -Path ".\dist" | Out-Null
}

# Compile the PowerShell script into an executable with explicit parameters and versioning
Invoke-ps2exe -InputFile ".\src\USBMonitor.ps1" `
             -OutputFile ".\dist\USBMonitor.exe" `
             -NoConsole `
             -IconFile ".\src\icon.ico" `
             -Product "USB Monitor" `
             -Title "USB Monitor" `
             -Copyright "Joan Roig" `
             -Version $version `
             -Verbose
