# EventForge - ask the warm Godot to run some tests (dev tool, Windows).
#
# Writes one request file for tools/test_daemon.gd, waits for its answer, prints it, and exits with
# 0 when every named test was green. The daemon must already be running (tools/test_daemon.ps1).
#
# Usage (from the repo root):
#   powershell -File tools/test_daemon_client.ps1 lighting_lift_test shard_split_test
#   powershell -File tools/test_daemon_client.ps1 quit          # stop the daemon
#
# ITERATION ONLY - see the daemon's own header. The committed verdict is a cold full suite.
[CmdletBinding(PositionalBinding = $false)]
param(
	[Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Tests,
	[int]$TimeoutSeconds = 300,
	[switch]$Retried   # set by this script's own one retry after the daemon hands over
)

if (-not $Tests) { Write-Error "Name at least one test (or 'quit')."; exit 2 }
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$queue = Join-Path $root ".godot\test_daemon"
if (-not (Test-Path $queue)) { Write-Error "No daemon queue at $queue - start tools/test_daemon.ps1 first."; exit 2 }

$token = [Guid]::NewGuid().ToString("N").Substring(0, 8)
$response = Join-Path $queue "response-$token.txt"
Set-Content -Path (Join-Path $queue "request-$token.txt") -Value $Tests -Encoding utf8

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while (-not (Test-Path $response)) {
	if ((Get-Date) -gt $deadline) { Write-Error "No answer in $TimeoutSeconds s - is the daemon running?"; exit 3 }
	Start-Sleep -Milliseconds 100
}
# The daemon writes the file line by line, so a reader can arrive mid-write; one short settle is
# enough, and a missing last line would otherwise read as a test that never answered.
Start-Sleep -Milliseconds 100
$lines = Get-Content $response
Remove-Item $response -ErrorAction SilentlyContinue
$lines

# The daemon hands over to a fresh process when the plugin source has changed under it, and answers
# nothing. Waiting for the new one and asking again is what the caller would do by hand.
if ($lines | Where-Object { $_ -match "Handing over to a fresh one" }) {
	if ($Retried) { "The daemon handed over twice - start it again and retry by hand."; exit 3 }
	Start-Sleep -Seconds 20
	& $PSCommandPath @Tests -TimeoutSeconds $TimeoutSeconds -Retried
	exit $LASTEXITCODE
}
if ($lines | Where-Object { $_ -match "\bRED\b" }) { "Some tests failed."; exit 1 }
"All picked tests passed. (ITERATION ONLY - not the verdict.)"
exit 0
