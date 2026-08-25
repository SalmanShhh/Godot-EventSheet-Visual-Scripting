# EventForge - find the commit that turned one test red (dev tool, Windows).
#
# `git bisect run` needs a command that exits 0 for good and non-zero for bad, and the suite is the
# wrong command for that: it takes minutes, and half the commits it walks fail for some unrelated
# reason of their own. One test takes seconds and answers about itself, which is what a bisect
# actually wants.
#
# So this is that command. It runs ONE test through the runner's single-test path
# (EVENTFORGE_TEST_ONLY), and exits 0 or 1 on that test alone.
#
# Usage (from the repo root):
#   $env:GODOT = "<path to the Godot 4.7 console binary>"
#   git bisect start HEAD <a commit where it passed>
#   git bisect run powershell -File tools/bisect_test.ps1 lighting_lift_test
#   git bisect reset
#
# WHAT TO WATCH FOR, from the one that cost an afternoon: a test can be red for a reason that is not
# in the diff at all. `doc_library_test` carries a 12-second parse budget and was being run inside a
# shard beside seven other Godot processes, so it failed on load rather than on any commit - and a
# bisect over that walks the whole history and blames whichever commit it lands on. Before bisecting,
# run the test ALONE at HEAD twice: if it is red once and green once, the cause is the machine or
# the split, and no commit will explain it.
#
# Exit codes are git bisect's own: 0 good, 1 bad, 125 "cannot test this commit" (the project would
# not import, so the answer is neither).
param(
	[Parameter(Mandatory = $true)][string]$Test,
	[string]$Godot = $env:GODOT
)

if (-not $Godot) { Write-Error "Set `$env:GODOT to the Godot 4.7 console binary first."; exit 125 }
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# A commit whose project will not import cannot answer the question either way.
& $Godot --headless --path $root --import 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { "cannot test this commit: the project did not import"; exit 125 }

$env:EVENTFORGE_TEST_ONLY = $Test
$output = & $Godot --headless --path $root --script tests/run_tests.gd 2>&1
Remove-Item Env:\EVENTFORGE_TEST_ONLY -ErrorAction SilentlyContinue

$text = ($output | Out-String)
# A test file that does not exist at this commit ran nothing, and "nothing failed" is not "good".
if ($text -notmatch "\[(PASS|FAIL)\]") { "cannot test this commit: $Test ran no assertions"; exit 125 }
if ($text.Contains("All tests passed.")) { "good: $Test passes here"; exit 0 }
"bad: $Test fails here"
$text -split "`n" | Where-Object { $_ -match "\[FAIL\]" } | Select-Object -First 4
exit 1
