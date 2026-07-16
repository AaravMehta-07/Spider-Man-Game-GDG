param(
    [int]$Camera = 0,
    [switch]$SkipBuild
)
$ErrorActionPreference = "Stop"
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
& $VenvPython -m pip install -r requirements.txt
$GodotJson = & $VenvPython tools\locate_godot.py | ConvertFrom-Json
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
foreach ($Entry in $ModelUrls.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $Entry.Key)) { & curl.exe -L --retry 3 --output $Entry.Key $Entry.Value }
}
& $VenvPython tools\generate_audio.py
& $VenvPython tools\generate_textures.py
& $VenvPython tools\validate_installation.py
& $VenvPython -m ruff check .
& $VenvPython -m pytest
if (-not $SkipBuild) { & powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 }
Write-Host "Setup complete. Run: python main.py"
