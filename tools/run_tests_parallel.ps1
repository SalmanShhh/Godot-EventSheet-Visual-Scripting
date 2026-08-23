# EventForge - run the test suite across several Godot processes at once (dev tool, Windows).
#
# The suite is ~600 independent test files that one process walks in 10-20 minutes. This splits
# the parallel-safe files into N shards (tests/run_tests.gd reads EVENTFORGE_TEST_SHARD), runs the
# shards concurrently, then runs the "tail" - the timing tests and the shared-state teardown tests -
# alone, because a loaded machine fails a budget for the wrong reason and a teardown test must not
# pull state from under a neighbour. A test joins the tail by DECLARING it (a `*BUDGET_MS*` or
# `PARALLEL_UNSAFE` constant), never by what its file is called. The verdict is the AND of every
# process's verdict, printed as the same literal line the serial runner prints, so greps keep working.
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

function Count-Of([string]$text, [string]$needle) { ([regex]::Matches($text, [regex]::Escape($needle))).Count }

# One import up front so the shards never race each other on a cold .godot/ cache.
& $Godot --headless --path $root --import 2>&1 | Out-Null

$jobs = @()
for ($k = 0; $k -lt $Shards; $k++) {
	$log = Join-Path $logDir ("shard-$k.txt")
	$err = Join-Path $logDir ("shard-$k.err.txt")
	$env:EVENTFORGE_TEST_SHARD = "$k/$Shards"
	$p = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", "`"$root`"", "--script", "tests/run_tests.gd") `
		-RedirectStandardOutput $log -RedirectStandardError $err -PassThru -WindowStyle Hidden
	$jobs += @{ Process = $p; Log = $log; Err = $err; Name = "shard $k/$Shards" }
	Start-Sleep -Seconds 2   # stagger the starts so no two processes open the project cache at once
}
Remove-Item Env:\EVENTFORGE_TEST_SHARD -ErrorAction SilentlyContinue
foreach ($job in $jobs) { $job.Process.WaitForExit() }

$tailLog = Join-Path $logDir "tail.txt"
$tailErr = Join-Path $logDir "tail.err.txt"
$env:EVENTFORGE_TEST_SHARD = "tail"
$tail = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", "`"$root`"", "--script", "tests/run_tests.gd") `
	-RedirectStandardOutput $tailLog -RedirectStandardError $tailErr -PassThru -WindowStyle Hidden -Wait
Remove-Item Env:\EVENTFORGE_TEST_SHARD -ErrorAction SilentlyContinue

$allGreen = $true
$passes = 0; $fails = 0
foreach ($job in ($jobs + @(@{ Log = $tailLog; Err = $tailErr; Name = "tail" }))) {
	$out = (Get-Content $job.Log -Raw -ErrorAction SilentlyContinue) + "`n" + (Get-Content $job.Err -Raw -ErrorAction SilentlyContinue)
	$verdict = if ($out -and $out.Contains("All tests passed.")) { "green" } else { "RED" }
	$p = Count-Of $out "[PASS]"; $f = Count-Of $out "[FAIL]"
	"{0,-12} {1,-6} {2,6} pass {3,4} fail  {4}" -f $job.Name, $verdict, $p, $f, $job.Log
	$passes += $p; $fails += $f
	if ($verdict -ne "green") { $allGreen = $false }
}
"total: $passes pass, $fails fail across $Shards shards + tail"
if ($allGreen) { "All tests passed."; exit 0 } else { "Some tests failed."; exit 1 }
