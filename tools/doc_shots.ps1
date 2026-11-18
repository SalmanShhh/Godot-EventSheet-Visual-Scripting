# Retakes documentation pictures in a REAL Godot editor without touching the developer's own settings.
#
# The editor reads and writes its settings under %APPDATA%\Godot. This launcher points APPDATA at a
# separate folder for the child process only, seeds it from tools/doc_shots/editor_settings_dark.txt
# (single-window mode, 100% display scale, the default dark theme), wipes everything an earlier run
# left behind (the saved session, the picker's recents and favourites, the dock layout), waits until the
# machine is quiet, and starts ONE editor running tools/doc_shots.gd. A hard stop ends only the process
# this script started.
#
#   $env:GODOT = "<path to the _console binary>"
#   powershell -File tools/doc_shots.ps1 -Out <folder> [-Batch sheets] [-Only a,b] [-Install] [-List <file>]
#
#   -Out       the folder the pictures and report.txt are written to
#   -Batch     only the shots of one batch (each batch is one run)
#   -Only      only the named shots
#   -Install   also write each picture over the file it replaces (the shot's `target`)
#   -Fingerprint  afterwards write the fingerprint of what each picture shows into the list
#   -Light     the light theme (the settings template differs in one line)
#   -MaxOthers how many other Godot processes may run beside it (default 4: two Godots)
#   -IgnoreSuites  do not wait for a test suite another checkout is running (a picture run is counted in frames, not seconds)
#
# A run needs about two minutes for the editor to start and settle, then seconds per picture.
param(
	[Parameter(Mandatory = $true)][string]$Out,
	[string]$Batch = "",
	[string]$Only = "",
	[switch]$Install,
	[switch]$Fingerprint,
	[switch]$Light,
	[string]$List = "tools/doc_shots/shots.json",
	[string]$Sandbox = (Join-Path ([System.IO.Path]::GetTempPath()) "eventforge_doc_shots"),
	[int]$LimitMinutes = 40,
	[int]$MaxOthers = 4,
	[switch]$IgnoreSuites
)

$ErrorActionPreference = "Stop"
if (-not $env:GODOT) { throw "Set `$env:GODOT to the Godot console binary first." }
$project = (Get-Location).Path
$variant = if ($Light) { "light" } else { "dark" }
$config = Join-Path $Sandbox $variant
$settings = Join-Path $config "Godot"
New-Item -ItemType Directory -Force -Path $settings | Out-Null

# The settings the editor starts from: a fresh copy every run, so a setting an earlier run changed
# (or the editor saved on its way out) cannot leak into this one.
$lines = Get-Content -Path (Join-Path $project "tools/doc_shots/editor_settings_dark.txt")
if ($Light) { $lines = $lines | ForEach-Object { $_ -replace 'color_preset = "Default"', 'color_preset = "Light"' } }
Set-Content -Path (Join-Path $settings "editor_settings-4.7.tres") -Value $lines -Encoding utf8

# What the plugin and the editor keep between runs: neither may leak into a picture.
Get-ChildItem -Path (Join-Path $settings "app_userdata") -Recurse -File -ErrorAction SilentlyContinue |
	Where-Object { $_.Name -in @("eventsheets_session.cfg", "eventforge_picker_recents.cfg", "eventforge_picker_favorites.cfg") } |
	Remove-Item -Force
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $project ".godot/editor/editor_layout.cfg")
# The strip, the row density and other per-project choices the editor remembers beside the layout.
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $project ".godot/editor/project_metadata.cfg")

# Quiet machine: no test suite or perf run, and at most $MaxOthers other Godot processes (the console launcher and the engine are two
# processes for each Godot) beside this one.
$deadline = (Get-Date).AddMinutes($LimitMinutes)
while ($true) {
	$others = @(Get-CimInstance Win32_Process -Filter "Name like 'Godot%'")
	$suite = @($others | Where-Object { $_.CommandLine -match 'run_tests|run_perf' }).Count
	if ($IgnoreSuites) { $suite = 0 }
	if ($others.Count -le $MaxOthers -and $suite -eq 0) { break }
	if ((Get-Date) -gt $deadline) { Write-Output "gave up waiting for a quiet machine"; exit 9 }
	Start-Sleep -Seconds 10
}

New-Item -ItemType Directory -Force -Path $Out | Out-Null
$outFull = (Resolve-Path $Out).Path -replace '\\', '/'
$arguments = @("--editor", "--path", $project, "--script", "tools/doc_shots.gd", "--",
	"list=$List", "out=$outFull", "config=$($config -replace '\\','/')")
if ($Batch) { $arguments += "batch=$Batch" }
if ($Only) { $arguments += "only=$Only" }
if ($Install) { $arguments += "install=1" }

$realAppData = $env:APPDATA
$env:APPDATA = $config
$log = Join-Path $outFull "run.log"
$errLog = Join-Path $outFull "run.err"
try {
	$process = Start-Process -FilePath $env:GODOT -ArgumentList $arguments -PassThru -NoNewWindow `
		-RedirectStandardOutput $log -RedirectStandardError $errLog
	# A game the run started (play_scene) can leave the editor waiting for it; the game is ended after it has
	# been up for a minute, which is long enough for a picture of the strip reading Stop.
	$stopAt = (Get-Date).AddMinutes($LimitMinutes)
	while (-not $process.HasExited -and (Get-Date) -lt $stopAt) {
		Start-Sleep -Seconds 5
		Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" |
			Where-Object { $_.CommandLine -match "--remote-debug" -and $_.CommandLine.Replace([string][char]92, "/") -like "*$($project.Replace([string][char]92, '/'))*" -and ((Get-Date) - $_.CreationDate).TotalSeconds -gt 60 } |
			ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
	}
	if (-not $process.HasExited) {
		Write-Output "hard stop"
		Get-CimInstance Win32_Process -Filter "ParentProcessId=$($process.Id)" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
		Stop-Process -Id $process.Id -Force
	}
	Write-Output "editor exit code $($process.ExitCode)"
}
finally {
	$env:APPDATA = $realAppData
}

if ($Fingerprint -and $process.ExitCode -eq 0) {
	& $env:GODOT --headless --path $project --script tools/doc_shots_fingerprint.gd -- "list=$List" "write=1"
}
