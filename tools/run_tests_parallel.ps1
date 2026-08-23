# EventForge - run the test suite across several Godot processes at once (dev tool, Windows).
#
# The suite is ~600 independent test files that one process walks in 10-20 minutes. This splits
# the parallel-safe files into N shards (tests/run_tests.gd reads EVENTFORGE_TEST_SHARD), runs the
# shards concurrently, then runs the "tail" - the timing-budget tests and the shared-state teardown
# tests - alone, because a loaded machine fails a budget for the wrong reason and a teardown test
# must not pull state from under a neighbour. The verdict is the AND of every process's verdict,
# printed as the same literal line the serial runner prints, so existing greps keep working.
#
# Usage (from the repo root):
#   $env:GODOT = "<path to the Godot 4.7 console binary>"
#   powershell -File tools/run_tests_parallel.ps1            # shards = min(8, cores - 2)
#   powershell -File tools/run_tests_parallel.ps1 -Shards 4
# Logs land in .godot/test_logs/ (ignored by git); each shard's full output is kept there.
param(
	[int]$Shards = 0,
	[string]$Godot = $env:GODOT
)

if (-not $Godot) { Write-Error "Set `$env:GODOT to the Godot 4.7 console binary first."; exit 2 }
if ($Shards -lt 1) { $Shards = [Math]::Max(1, [Math]::Min(8, [Environment]::ProcessorCount - 2)) }
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$logDir = Join-Path $root ".godot\test_logs"
New-Item -ItemType Directory -Force $logDir | Out-Null

# One import up front so the shards never race each other on a cold .godot/ cache.
& $Godot --headless --path $root --import 2>&1 | Out-Null

$procs = @()
for ($k = 0; $k -lt $Shards; $k++) {
	$log = Join-Path $logDir ("shard-$k.txt")
	$psi = New-Object System.Diagnostics.ProcessStartInfo
	$psi.FileName = $Godot
	$psi.Arguments = "--headless --path `"$root`" --script tests/run_tests.gd"
	$psi.UseShellExecute = $false
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError = $true
	$psi.EnvironmentVariables["EVENTFORGE_TEST_SHARD"] = "$k/$Shards"
	$p = New-Object System.Diagnostics.Process
	$p.StartInfo = $psi
	$null = $p.Start()
	$procs += @{ Process = $p; Log = $log; Name = "shard $k/$Shards" }
}
foreach ($entry in $procs) {
	$out = $entry.Process.StandardOutput.ReadToEnd() + $entry.Process.StandardError.ReadToEnd()
	$entry.Process.WaitForExit()
	[IO.File]::WriteAllText($entry.Log, $out)
	$entry.Verdict = if ($out.Contains("All tests passed.")) { "green" } else { "RED" }
	$entry.Fails = ([regex]::Matches($out, "\[FAIL\]")).Count
	$entry.Passes = ([regex]::Matches($out, "\[PASS\]")).Count
}

$tailLog = Join-Path $logDir "tail.txt"
$env:EVENTFORGE_TEST_SHARD = "tail"
$tailOut = & $Godot --headless --path $root --script tests/run_tests.gd 2>&1 | Out-String
Remove-Item Env:\EVENTFORGE_TEST_SHARD
[IO.File]::WriteAllText($tailLog, $tailOut)
$tailVerdict = if ($tailOut.Contains("All tests passed.")) { "green" } else { "RED" }

$allGreen = $tailVerdict -eq "green"
$passes = ([regex]::Matches($tailOut, "\[PASS\]")).Count
$fails = ([regex]::Matches($tailOut, "\[FAIL\]")).Count
foreach ($entry in $procs) {
	"{0,-12} {1,-6} {2,6} pass {3,4} fail  {4}" -f $entry.Name, $entry.Verdict, $entry.Passes, $entry.Fails, $entry.Log
	$passes += $entry.Passes; $fails += $entry.Fails
	if ($entry.Verdict -ne "green") { $allGreen = $false }
}
"{0,-12} {1,-6} {2,6} pass {3,4} fail  {4}" -f "tail", $tailVerdict, ([regex]::Matches($tailOut, "\[PASS\]")).Count, ([regex]::Matches($tailOut, "\[FAIL\]")).Count, $tailLog
"total: $passes pass, $fails fail across $Shards shards + tail"
if ($allGreen) { "All tests passed."; exit 0 } else { "Some tests failed."; exit 1 }
