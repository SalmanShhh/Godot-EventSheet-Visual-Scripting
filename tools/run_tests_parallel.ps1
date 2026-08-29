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
# A RED RUN IS PRE-INVESTIGATED. When anything fails or crashes, tools/test_report.gd runs at the end
# and prints, per failing test, the assertion with its expected and its got, the files you changed
# that map to that test, and the line that runs it alone. A test that CRASHED prints no [FAIL] line
# at all - the runner's start/finish trail is what names it.
#
# Usage (from the repo root):
#   $env:GODOT = "<path to the Godot 4.7 console binary>"
#   powershell -File tools/run_tests_parallel.ps1            # shards = min(8, cores - 2)
#   powershell -File tools/run_tests_parallel.ps1 -Shards 4
#   powershell -File tools/run_tests_parallel.ps1 -Iterate   # see below; NEVER a verdict
#   powershell -File tools/run_tests_parallel.ps1 -Force     # ignore the stamped verdict below
#
# A green run STAMPS the working tree's content identity, and an identical tree gets that verdict
# printed back instead of run again. One run at a time, too: the suite holds a lock file for its
# duration and a second invocation waits, because two suites on one machine fail each other's perf
# budgets. Every green summary ends with the ten slowest tests, so suite growth polices itself.
#
# -Iterate is the ITERATION shape of this launcher, for use while a change is still moving: the
# tests tools/pick_tests.gd says your edits could have broken run FIRST, alone, and the run STOPS
# there if any of them fails. It reaches a red answer in seconds instead of minutes. It is not a
# verdict and must never be quoted as one - the committed verdict is the full blind run above.
# Logs land in .godot/test_logs/ (ignored by git); each shard's full output is kept there.
param(
	[int]$Shards = 0,
	[switch]$Iterate,
	[switch]$Force,
	[switch]$IdentityOnly,
	[string]$Godot = $env:GODOT
)

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# THE TREE'S CONTENT IDENTITY: the commit, plus everything the working tree says on top of it -
# the porcelain status, the full diff against HEAD (staged and unstaged both), and the CONTENT hash
# of every untracked file, because porcelain reports an untracked file by name only and a name does
# not change when the file does. One byte anywhere in that set gives a different identity, which is
# the whole point: the stamp below may only answer for the exact tree it was recorded on.
function Get-TreeIdentity {
	$head = & git -C $root rev-parse HEAD 2>$null
	if (-not $head) { return "" }
	$parts = @($head) + @(& git -C $root status --porcelain 2>$null) + @(& git -C $root diff HEAD 2>$null)
	foreach ($untracked in @(& git -C $root ls-files --others --exclude-standard 2>$null)) {
		$full = Join-Path $root $untracked
		if (Test-Path -PathType Leaf $full) { $parts += "$untracked $((Get-FileHash -Algorithm SHA256 $full).Hash)" }
	}
	$bytes = [Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))
	return ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes))).Replace("-", "")
}

$identity = Get-TreeIdentity
if ($IdentityOnly) { $identity; exit 0 }   # the identity rule, asked directly (tests/verdict_stamp_test.gd)

if (-not $Godot) { Write-Error "Set `$env:GODOT to the Godot 4.7 console binary first."; exit 2 }
if ($Shards -lt 1) { $Shards = [Math]::Max(1, [Math]::Min(8, [Environment]::ProcessorCount - 2)) }
$logDir = Join-Path $root ".godot\test_logs"
New-Item -ItemType Directory -Force $logDir | Out-Null

# THE STAMP. A green run records the identity it was green FOR; an identical tree gets that verdict
# back instead of five more minutes of the same answer. Any difference at all misses, and -Force
# always runs. Machine-local, under .godot/, never committed.
$stampFile = Join-Path $root ".godot\verdict_stamp.txt"
if (-not $Force -and $identity -and (Test-Path $stampFile)) {
	$stamp = @(Get-Content $stampFile)
	if ($stamp.Count -ge 3 -and $stamp[0] -eq $identity) {
		$ago = [datetime]::UtcNow - [datetime]::Parse($stamp[1], $null, [Globalization.DateTimeStyles]::RoundtripKind)
		$minutes = [int][Math]::Round($ago.TotalMinutes)
		$stamp[2]
		"All tests passed."
		"(unchanged tree, stamped verdict from $minutes minutes ago - run with -Force to run it again.)"
		exit 0
	}
}

# THE SINGLE-FLIGHT LOCK. Two suites on one machine fail each other's perf budgets, and the red that
# produces looks exactly like a real regression. So a run holds this file exclusively and a second
# invocation waits for it rather than overlapping. The handle dies with the process, so a stale lock
# needs a holder that is gone: that one is broken with a note.
$lockPath = Join-Path $root ".godot\suite.lock"
$lock = $null
$announced = $false
while (-not $lock) {
	# Shared for READING, so a waiting run can say whose lock it is; a second writer is still refused,
	# which is the exclusion itself.
	try { $lock = [IO.File]::Open($lockPath, "OpenOrCreate", "ReadWrite", "Read") }
	catch {
		$holder = @(Get-Content $lockPath -ErrorAction SilentlyContinue)[0]
		if ($holder -match "^\d+$" -and -not (Get-Process -Id ([int]$holder) -ErrorAction SilentlyContinue)) {
			"suite lock: holder process $holder is gone - breaking the stale lock."
			Remove-Item $lockPath -Force -ErrorAction SilentlyContinue
		} else {
			if (-not $announced) { "suite lock: held by process $holder - waiting for it to finish."; $announced = $true }
			Start-Sleep -Seconds 5
		}
	}
}
$lock.SetLength(0)   # a shorter pid must not leave the tail of a longer one behind
$writer = New-Object IO.StreamWriter($lock)
$writer.WriteLine($PID)
$writer.Flush()

# The crash trail is read back at the end, so it starts empty: a trail left by a run that is not
# this one would otherwise be reported as this run's crash.
Remove-Item (Join-Path $root ".godot\test_progress\*.log") -ErrorAction SilentlyContinue

# A test may print a [FAIL] line ON PURPOSE, to prove tools/test_report.gd formats one correctly.
# Such a line names itself with this marker, and is not counted as a failure here: a shard printing
# "2 fail" beside its own green verdict is exactly what teaches a reader to distrust the verdict
# line, and the verdict line is the only thing in this output that is always right.
$DeliberateProbeMarker = "deliberate_probe_not_a_failure"

function Count-Of([string]$text, [string]$needle) { ([regex]::Matches($text, [regex]::Escape($needle))).Count }

function Count-Failures([string]$text) {
	if (-not $text) { return 0 }
	@($text -split "`n" | Where-Object {
		$_.Contains("[FAIL]") -and -not $_.Contains($DeliberateProbeMarker)
	}).Count
}

function Run-Godot([string]$log, [string]$err) {
	Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", "`"$root`"", "--script", "tests/run_tests.gd") `
		-RedirectStandardOutput $log -RedirectStandardError $err -PassThru -WindowStyle Hidden
}

function Verdict-Of($job) {
	$out = (Get-Content $job.Log -Raw -ErrorAction SilentlyContinue) + "`n" + (Get-Content $job.Err -Raw -ErrorAction SilentlyContinue)
	$verdict = if ($out -and $out.Contains("All tests passed.")) { "green" } else { "RED" }
	@{ Verdict = $verdict; Pass = (Count-Of $out "[PASS]"); Fail = (Count-Failures $out) }
}

# One import up front so the shards never race each other on a cold .godot/ cache.
& $Godot --headless --path $root --import 2>&1 | Out-Null

# The iteration pass: what a change could plausibly have broken, first and alone.
if ($Iterate) {
	$picked = & $Godot --headless --path $root --script tools/pick_tests.gd 2>&1 |
		Where-Object { $_ -match "^\s{2}\S+_test$" } | ForEach-Object { $_.Trim() }
	if ($picked) {
		$log = Join-Path $logDir "iterate.txt"
		$err = Join-Path $logDir "iterate.err.txt"
		$env:EVENTFORGE_TEST_ONLY = ($picked -join ",")
		$job = @{ Process = (Run-Godot $log $err); Log = $log; Err = $err; Name = "impacted" }
		$job.Process.WaitForExit()
		Remove-Item Env:\EVENTFORGE_TEST_ONLY -ErrorAction SilentlyContinue
		$result = Verdict-Of $job
		"{0,-12} {1,-6} {2,6} pass {3,4} fail  {4}" -f "impacted", $result.Verdict, $result.Pass, $result.Fail, $log
		if ($result.Verdict -ne "green") {
			& $Godot --headless --path $root --script tools/test_report.gd
			"Some tests failed."
			"(-Iterate stopped at the impacted tests. This is NOT the verdict - run without it before committing.)"
			exit 1
		}
	} else {
		"impacted   none  (nothing changed, or git could not be reached)"
	}
}

$jobs = @()
for ($k = 0; $k -lt $Shards; $k++) {
	$log = Join-Path $logDir ("shard-$k.txt")
	$err = Join-Path $logDir ("shard-$k.err.txt")
	$env:EVENTFORGE_TEST_SHARD = "$k/$Shards"
	$jobs += @{ Process = (Run-Godot $log $err); Log = $log; Err = $err; Name = "shard $k/$Shards" }
	Start-Sleep -Seconds 2   # stagger the starts so no two processes open the project cache at once
}
Remove-Item Env:\EVENTFORGE_TEST_SHARD -ErrorAction SilentlyContinue
foreach ($job in $jobs) { $job.Process.WaitForExit() }

$tailLog = Join-Path $logDir "tail.txt"
$tailErr = Join-Path $logDir "tail.err.txt"
$env:EVENTFORGE_TEST_SHARD = "tail"
$tail = Run-Godot $tailLog $tailErr
$tail.WaitForExit()
Remove-Item Env:\EVENTFORGE_TEST_SHARD -ErrorAction SilentlyContinue

$allGreen = $true
$passes = 0; $fails = 0
foreach ($job in ($jobs + @(@{ Log = $tailLog; Err = $tailErr; Name = "tail" }))) {
	$result = Verdict-Of $job
	"{0,-12} {1,-6} {2,6} pass {3,4} fail  {4}" -f $job.Name, $result.Verdict, $result.Pass, $result.Fail, $job.Log
	$passes += $result.Pass; $fails += $result.Fail
	if ($result.Verdict -ne "green") { $allGreen = $false }
}
"total: $passes pass, $fails fail across $Shards shards + tail"

# A process that CRASHED reports no failure at all - its log simply stops. The trail the runner
# leaves is what turns that into a named test, so it is checked on every run, green or not.
$crashed = @()
$seconds = @{}
foreach ($trail in (Get-ChildItem (Join-Path $root ".godot\test_progress") -Filter *.log -ErrorAction SilentlyContinue)) {
	$lines = @(Get-Content $trail.FullName -ErrorAction SilentlyContinue | Where-Object { $_.Trim() })
	if ($lines.Count -gt 0 -and $lines[-1].StartsWith("START ")) { $crashed += $lines[-1].Substring(6) }
	# The same trail carries each test's own milliseconds on its DONE line, so the slowest-ten footer
	# below costs one more match on a walk that was happening anyway.
	foreach ($line in $lines) { if ($line -match "^DONE (\S+) (\d+)$") { $seconds[$matches[1]] = [int]$matches[2] / 1000 } }
}
if ($crashed.Count -gt 0) {
	"CRASHED (started, never finished): $($crashed -join ', ')"
	$allGreen = $false
}

if (-not $allGreen) { & $Godot --headless --path $root --script tools/test_report.gd }

# THE SLOWEST TEN. No gate and no threshold: a list, every green run, so that a test which grows
# into a minute is noticed by whoever added it rather than by whoever bisects the suite next year.
if ($allGreen -and $seconds.Count -gt 0) {
	"slowest ten:"
	$seconds.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 10 |
		ForEach-Object { "  {0,6}s  {1}" -f ([Math]::Round($_.Value, 1)), $_.Key }
}

# Asked again at the END: a tree edited while the suite ran was never green as a whole, so it gets
# no stamp rather than a stamp for a state half of the run never saw.
if ($allGreen -and $identity -and (Get-TreeIdentity) -eq $identity) {
	Set-Content -Encoding utf8 $stampFile @($identity, [datetime]::UtcNow.ToString("o"),
		"total: $passes pass, $fails fail across $Shards shards + tail")
}
$lock.Dispose()
if ($allGreen) { "All tests passed."; exit 0 } else { "Some tests failed."; exit 1 }
