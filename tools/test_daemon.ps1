# EventForge - keep a warm Godot running for tools/test_daemon.gd (dev tool, Windows).
#
# The daemon quits with code 70 when it decides it is no longer worth believing - every 25 tests,
# and immediately when the state-leak sweep fails in it. This is the loop that starts another one.
# Any other exit code (0 from a `quit` request, or a crash) ends the loop.
#
# Usage (from the repo root; Ctrl+C stops it):
#   $env:GODOT = "<path to the Godot 4.7 console binary>"
#   powershell -File tools/test_daemon.ps1
#
# ITERATION ONLY. A warm process carries whatever the last test left in a static, which is the one
# thing a cold run does not. Never quote it as a verdict; run the full suite before committing.
param(
	[string]$Godot = $env:GODOT
)

if (-not $Godot) { Write-Error "Set `$env:GODOT to the Godot 4.7 console binary first."; exit 2 }
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$RESTART_EXIT_CODE = 70

& $Godot --headless --path $root --import 2>&1 | Out-Null
while ($true) {
	& $Godot --headless --path $root --script tools/test_daemon.gd
	if ($LASTEXITCODE -ne $RESTART_EXIT_CODE) {
		"daemon stopped (exit $LASTEXITCODE)"
		break
	}
	"daemon handing over to a fresh process"
}
