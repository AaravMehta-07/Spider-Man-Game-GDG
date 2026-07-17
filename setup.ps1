param(
    [int]$Camera = 0,
    [switch]$SkipBuild
)
$ErrorActionPreference = "Stop"

function Assert-NativeSuccess([string]$Step) {
    if ($LASTEXITCODE -ne 0) { throw "$Step failed with exit code $LASTEXITCODE." }
}
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root
$Python = $null
try { $Python = (& py -3.11 -c "import sys; print(sys.executable)" 2>$null).Trim() } catch {}
if (-not $Python -or -not (Test-Path -LiteralPath $Python)) {
    throw "Python 3.11 is required. Install with: winget install --id Python.Python.3.11 --exact"
}
if (-not (Test-Path -LiteralPath ".venv\Scripts\python.exe")) { & $Python -m venv .venv }
$VenvPython = Join-Path $Root ".venv\Scripts\python.exe"
& $VenvPython -m pip install --upgrade pip
Assert-NativeSuccess "pip upgrade"
& $VenvPython -m pip install -r requirements.txt
Assert-NativeSuccess "dependency installation"
$GodotJson = & $VenvPython tools\locate_godot.py --project-root $Root | ConvertFrom-Json
Assert-NativeSuccess "Godot detection"
if (-not $GodotJson.path) {
    throw "Godot 4.7 is required. Install with: winget install --id GodotEngine.GodotEngine --exact --version 4.7.1"
}
if (-not $GodotJson.version.StartsWith("4.7")) { throw "Godot 4.7 required; found $($GodotJson.version)." }
$Template = Join-Path $env:APPDATA "Godot\export_templates\4.7.1.stable\windows_release_x86_64.exe"
if (-not (Test-Path -LiteralPath $Template)) {
    throw "Godot 4.7.1 export templates are missing. Install the official templates before building."
}
$GodotPath = $GodotJson.path.Replace([char]92, [char]47)
$LocalConfig = @"
game:
  godot_executable: '$GodotPath'
vision:
  camera_id: $Camera
"@
$LocalConfig | Set-Content -LiteralPath "config\local.yaml" -Encoding UTF8
$ModelUrls = @{
    "vision\models\pose_landmarker_lite.task" = "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task"
    "vision\models\hand_landmarker.task" = "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
}
$ModelHashes = @{
    "vision\models\pose_landmarker_lite.task" = "59929E1D1EE95287735DDD833B19CF4AC46D29BC7AFDDBBF6753C459690D574A"
    "vision\models\hand_landmarker.task" = "FBC2A30080C3C557093B5DDFC334698132EB341044CCEE322CCF8BCF3607CDE1"
}
foreach ($Entry in $ModelUrls.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $Entry.Key)) {
        & curl.exe -L --retry 3 --output $Entry.Key $Entry.Value
        Assert-NativeSuccess "model download $($Entry.Key)"
    }
    $ActualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Entry.Key).Hash
    if ($ActualHash -ne $ModelHashes[$Entry.Key]) {
        throw "Model hash verification failed for $($Entry.Key)."
    }
}
& $VenvPython tools\generate_audio.py
Assert-NativeSuccess "audio generation"
& $VenvPython tools\generate_textures.py
Assert-NativeSuccess "texture generation"
& $VenvPython tools\validate_installation.py
Assert-NativeSuccess "installation validation"
& $VenvPython -m ruff check .
Assert-NativeSuccess "Python lint"
& $VenvPython -m pytest
Assert-NativeSuccess "Python tests"
if (-not $SkipBuild) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
    Assert-NativeSuccess "Windows build"
}
Write-Host "Setup complete. Run: python main.py"
