param(
    [string]$GodotPath = "godot",
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "build\Windows")
)

$ErrorActionPreference = "Stop"
$engine = Get-Command $GodotPath -ErrorAction Stop
$enginePath = $engine.Source
if (-not $enginePath) { $enginePath = $engine.Path }
$version = (& $enginePath --version | Out-String).Trim()
if ($version -notlike "4.7.2.*") { throw "Godot 4.7.2 is required. Found: $version" }

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$output = (Resolve-Path -LiteralPath $OutputDirectory).Path
& $enginePath --headless --editor --path $PSScriptRoot --import
if ($LASTEXITCODE -ne 0) { throw "Asset import failed ($LASTEXITCODE)." }
& $enginePath --headless --path $PSScriptRoot --export-release "Windows Desktop" (Join-Path $output "ESP-RaDe.exe")
if ($LASTEXITCODE -ne 0) { throw "Windows export failed ($LASTEXITCODE). Install matching Godot export templates." }
foreach ($name in @("README.md", "LICENSE", "GODOT-LICENSES.txt")) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $output $name) -Force
}
Write-Host "Built ESP Ra.De. HD Chapters 1.0.0: $output"
