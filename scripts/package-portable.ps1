[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root "src-tauri\target\release\pm3gui-tauri.exe"
$output = Join-Path $root "portable"

if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Release executable not found: $source"
}

if (Test-Path -LiteralPath $output) {
    Get-ChildItem -LiteralPath $output -Force | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $output | Out-Null
}

$target = Join-Path $output "PM3GUI.exe"
Copy-Item -LiteralPath $source -Destination $target

@'
@echo off
cd /d "%~dp0"
start "" "%~dp0PM3GUI.exe"
'@ | Set-Content -LiteralPath (Join-Path $output "Launch-PM3GUI.bat") -Encoding ascii

@'
PM3 GUI 0.1.0 RC

Requires Windows 10 21H2+ or Windows 11 x64 and WebView2.
This package does not contain Proxmark3 Client. Select an existing Windows
PM3 Client directory containing pm3 and libs\shell\bash.exe.

Write, restore, wipe, and simulation actions require confirmation.
Use disposable test cards for write operations.
Real PM3 hardware acceptance is required before this RC is called stable.
'@ | Set-Content -LiteralPath (Join-Path $output "README.txt") -Encoding utf8

$hash = Get-FileHash -LiteralPath $target -Algorithm SHA256
$manifest = [ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    file = "PM3GUI.exe"
    bytes = (Get-Item -LiteralPath $target).Length
    sha256 = $hash.Hash
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output "manifest.json") -Encoding utf8
$manifest | Format-List
