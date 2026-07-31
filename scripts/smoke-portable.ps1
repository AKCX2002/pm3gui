[CmdletBinding()]
param([switch]$SkipLaunch)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$portable = Join-Path $root "portable"
$required = @("PM3GUI.exe", "Launch-PM3GUI.bat", "README.txt", "manifest.json")
foreach ($name in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $portable $name) -PathType Leaf)) {
        throw "Missing portable file: $name"
    }
}

$forbidden = Get-ChildItem -LiteralPath $portable -Recurse -File | Where-Object {
    $_.Name -in @("proxmark3.exe", "settings.json") -or
    $_.Extension -in @(".dump", ".key", ".pdb")
}
if ($forbidden) {
    throw "Forbidden portable content: $($forbidden.FullName -join ', ')"
}

$manifest = Get-Content -LiteralPath (Join-Path $portable "manifest.json") -Raw | ConvertFrom-Json
$actual = Get-FileHash -LiteralPath (Join-Path $portable "PM3GUI.exe") -Algorithm SHA256
if ($manifest.sha256 -ne $actual.Hash) {
    throw "Portable SHA-256 does not match manifest"
}

if (-not $SkipLaunch) {
    $process = Start-Process -FilePath (Join-Path $portable "PM3GUI.exe") -PassThru
    Start-Sleep -Seconds 3
    if ($process.HasExited) {
        throw "Portable application exited during startup"
    }
    [void]$process.CloseMainWindow()
    if (-not $process.WaitForExit(5000)) {
        Stop-Process -Id $process.Id -Force
        $process.WaitForExit()
    }
}

Write-Host "Portable smoke checks passed."
