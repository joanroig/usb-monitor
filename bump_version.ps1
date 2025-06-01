# bump-version.ps1
param (
    [ValidateSet("patch", "minor", "major")]
    [string]$BumpType = "patch"
)

$versionFile = "version.txt"
if (-Not (Test-Path $versionFile)) {
    Write-Error "Version file not found: $versionFile"
    exit 1
}

$version = Get-Content $versionFile
if ($version -notmatch "^\d+\.\d+\.\d+$") {
    Write-Error "Invalid version format: $version"
    exit 1
}

$parts = $version -split "\."
$major = [int]$parts[0]
$minor = [int]$parts[1]
$patch = [int]$parts[2]

switch ($BumpType) {
    "patch" { $patch++ }
    "minor" { $minor++; $patch = 0 }
    "major" { $major++; $minor = 0; $patch = 0 }
}

$newVersion = "$major.$minor.$patch"
"Updating version: $version -> $newVersion"
Set-Content $versionFile $newVersion