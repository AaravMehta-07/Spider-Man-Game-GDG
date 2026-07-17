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
    & py -3.11 (Join-Path $Root "tools\locate_godot.py") --project-root $Root
} else {
    & $Python (Join-Path $Root "tools\locate_godot.py") --project-root $Root
}
$Locator = $LocatorRaw | ConvertFrom-Json
if (-not $Locator.path) { throw "Godot 4.7 was not found. Run setup.ps1." }
if (-not $Locator.version.StartsWith("4.7")) { throw "Godot 4.7 required; found $($Locator.version)." }
$Godot = $Locator.path
$Project = Join-Path $Root "game"
$BuildLog = Join-Path $Logs "build.log"
$ImportLog = Join-Path $Logs "godot_import.log"
$TestLog = Join-Path $Logs "godot_tests.log"
$ExportLog = Join-Path $Logs "godot_export.log"
$PythonLintLog = Join-Path $Logs "python_lint.log"
$PythonTestLog = Join-Path $Logs "python_tests.log"
Remove-Item -LiteralPath $ImportLog, $TestLog, $ExportLog -Force -ErrorAction SilentlyContinue
("Godot: " + $Godot + [Environment]::NewLine + "Version: " + $Locator.version) | Set-Content -LiteralPath $BuildLog
$PythonPrefix = @()
if ($Python -eq "py") { $PythonPrefix = @("-3.11") }
function Assert-GodotLog {
    param([string]$Path, [string]$SuccessMarker = "")
    $Content = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    if ($Content -match "SCRIPT ERROR|Parse Error|Failed to load script") {
        throw "Godot reported a script failure. Check $Path."
    }
    if ($SuccessMarker -and $Content -notmatch [regex]::Escape($SuccessMarker)) {
        throw "Godot did not report '$SuccessMarker'. Check $Path."
    }
}
& $Python @PythonPrefix -m ruff check . 2>&1 | Tee-Object -FilePath $PythonLintLog
if ($LASTEXITCODE -ne 0) { throw "Python lint failed with exit code $LASTEXITCODE." }
& $Python @PythonPrefix -m pytest 2>&1 | Tee-Object -FilePath $PythonTestLog
if ($LASTEXITCODE -ne 0) { throw "Python tests failed with exit code $LASTEXITCODE." }
& $Godot --headless --path $Project --editor --quit 2>&1 |
    Tee-Object -FilePath $ImportLog |
    Tee-Object -FilePath $BuildLog -Append
if ($LASTEXITCODE -ne 0) { throw "Godot import failed with exit code $LASTEXITCODE." }
Assert-GodotLog -Path $ImportLog
& $Godot --headless --path $Project -s res://tests/test_runner.gd 2>&1 |
    Tee-Object -FilePath $TestLog |
    Tee-Object -FilePath $BuildLog -Append
if ($LASTEXITCODE -ne 0) { throw "GDScript tests failed with exit code $LASTEXITCODE." }
Assert-GodotLog -Path $TestLog -SuccessMarker "GDScript tests passed"
$Mode = if ($DebugExport) { "--export-debug" } else { "--export-release" }
$Exe = Join-Path $Build "WebProtocol.exe"
& $Godot --headless --path $Project $Mode "Windows Desktop" $Exe 2>&1 |
    Tee-Object -FilePath $ExportLog |
    Tee-Object -FilePath $BuildLog -Append
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $Exe)) { throw "Windows export failed. Check $BuildLog." }
Assert-GodotLog -Path $ExportLog
$Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Exe).Hash
$PythonVersion = (& $Python @PythonPrefix -c "import platform; print(platform.python_version())").Trim()
$SourceCommit = (& git -C $Root rev-parse HEAD 2>$null).Trim()
$SourceDirty = [bool](& git -C $Root status --porcelain 2>$null)
$RequirementsHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Root "requirements.txt")).Hash
$PoseHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Root "vision\models\pose_landmarker_lite.task")).Hash
$HandHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Root "vision\models\hand_landmarker.task")).Hash
$Report = [ordered]@{
    timestamp = (Get-Date).ToString("o")
    godot = $Locator.version
    python = $PythonVersion
    source_commit = $SourceCommit
    source_dirty = $SourceDirty
    requirements_sha256 = $RequirementsHash
    pose_model_sha256 = $PoseHash
    hand_model_sha256 = $HandHash
    executable = $Exe
    size_bytes = (Get-Item -LiteralPath $Exe).Length
    sha256 = $Hash
    import = "passed"
    python_lint = "passed"
    python_tests = "passed"
    gdscript_tests = "passed"
    export = "passed"
}
$Report | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Artifacts "latest_build.json")
Write-Host "Built $Exe"
Write-Host "SHA256 $Hash"
