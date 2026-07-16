param([switch]$DebugExport)
$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Artifacts = Join-Path $Root "artifacts\build_reports"
$Logs = Join-Path $Root "logs"
$Build = Join-Path $Root "Build"
New-Item -ItemType Directory -Force -Path $Artifacts, $Logs, $Build | Out-Null
$Python = Join-Path $Root ".venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $Python)) { $Python = "py" }
$LocatorRaw = if ($Python -eq "py") {
    & py -3.11 (Join-Path $Root "tools\locate_godot.py")
} else {
    & $Python (Join-Path $Root "tools\locate_godot.py")
}
$Locator = $LocatorRaw | ConvertFrom-Json
if (-not $Locator.path) { throw "Godot 4.7 was not found. Run setup.ps1." }
if (-not $Locator.version.StartsWith("4.7")) { throw "Godot 4.7 required; found $($Locator.version)." }
$Godot = $Locator.path
$Project = Join-Path $Root "game"
$BuildLog = Join-Path $Logs "build.log"
("Godot: " + $Godot + [Environment]::NewLine + "Version: " + $Locator.version) | Set-Content -LiteralPath $BuildLog
& $Godot --headless --path $Project --editor --quit 2>&1 | Tee-Object -FilePath $BuildLog -Append
if ($LASTEXITCODE -ne 0) { throw "Godot import failed with exit code $LASTEXITCODE." }
& $Godot --headless --path $Project -s res://tests/test_runner.gd 2>&1 | Tee-Object -FilePath $BuildLog -Append
if ($LASTEXITCODE -ne 0) { throw "GDScript tests failed with exit code $LASTEXITCODE." }
$Mode = if ($DebugExport) { "--export-debug" } else { "--export-release" }
$Exe = Join-Path $Build "WebProtocol.exe"
& $Godot --headless --path $Project $Mode "Windows Desktop" $Exe 2>&1 | Tee-Object -FilePath $BuildLog -Append
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $Exe)) { throw "Windows export failed. Check $BuildLog." }
$Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Exe).Hash
$Report = [ordered]@{
    timestamp = (Get-Date).ToString("o")
    godot = $Locator.version
    executable = $Exe
    size_bytes = (Get-Item -LiteralPath $Exe).Length
    sha256 = $Hash
    import = "passed"
    gdscript_tests = "passed"
    export = "passed"
}
$Report | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Artifacts "latest_build.json")
Write-Host "Built $Exe"
Write-Host "SHA256 $Hash"