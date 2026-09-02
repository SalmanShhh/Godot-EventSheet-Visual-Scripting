# EventForge - THE DESCRIPTOR-IDENTITY GATE, as one command (dev tool, Windows).
#
# A vocabulary module rewritten in a terser form is only proved unchanged when the vocabulary it
# publishes is byte-identical to what the verbose form published. This runs that proof: it dumps the
# vocabulary at a BASE commit and at the WORKING TREE in front of you, and reports whether the two
# texts match.
#
# THE GATE IS BOTH TEXTS, and neither alone is enough:
#
#   IDENTITY  tools/dump_registry.gd            key, type, shelf, parameters with their types and
#                                               defaults, forwarding address, emitted template.
#                                               A change here is a frozen-contract break.
#   WORDING   tools/dump_registry.gd -- words   name, description, reads-as sentence and the label
#                                               and description of every parameter. A migration can
#                                               keep every identity line and drop every description:
#                                               the plugin compiles the same code and every picker
#                                               in it goes blank. This is the text that sees that.
#
# HOW THE BASE IS READ: a DETACHED WORKTREE, never `git stash` and never `git checkout --`. Other
# work may be in flight in this checkout, and a gate that moves the tree it is measuring is a gate
# that loses somebody's edits.
#
# TWO WORKTREES OF ONE PROJECT SHARE ONE `user://`, which is why every dump here is written to an
# ABSOLUTE path under the temp folder rather than to `user://something.txt` - two runs writing the
# same `user://` name would compare a text against itself and print a green gate over a real change.
#
# THE WORKTREE IS CACHED per base commit and kept, because a first run pays for a full project
# import and a migration proves one module at a time. `-Clean` removes it when the wave is done.
#
# THE INSTRUMENT IS THE SAME ON BOTH SIDES. Before the base is read, the three files that FORMAT a
# dump - the two tools and EventForgeRegistryDump - are copied from the working tree into the
# worktree, so both halves are written by one formatter. Without that, a base older than the wording
# dump would answer `words` with the identity text and the gate would report every verb reworded.
# It cannot hide anything the gate is for: what is being measured is the VOCABULARY the registration
# modules publish, and none of the three copied files publishes a verb.
#
# USAGE (from the repository root)
#   $env:GODOT = "<path to the Godot 4.7 console binary>"
#   powershell -File tools/prove_registry_identity.ps1 -Base <sha or ref>
#   powershell -File tools/prove_registry_identity.ps1 -Base <sha> -Pack platformer
#   powershell -File tools/prove_registry_identity.ps1 -Base <sha> -Clean
#
# Prints `identity: registry=<same|MOVED> words=<same|MOVED> verbs=<n>` and exits 1 on any move,
# after naming the lines that moved.
param(
	[Parameter(Mandatory = $true)][string]$Base,
	[string]$Pack = "",
	[switch]$Clean
)

$ErrorActionPreference = 'Stop'

$godot = $env:GODOT
if ([string]::IsNullOrWhiteSpace($godot)) {
	Write-Output "set `$env:GODOT to the Godot 4.7 console binary first"
	exit 1
}

$repo = (& git rev-parse --show-toplevel).Trim()
$baseSha = (& git rev-parse $Base).Trim()
$baseShort = $baseSha.Substring(0, 8)
$work = Join-Path $env:TEMP "eventforge-identity"
$tree = Join-Path $work $baseShort
$dumps = Join-Path $work "dumps"
New-Item -ItemType Directory -Force -Path $dumps | Out-Null

$packArg = @()
if (-not [string]::IsNullOrWhiteSpace($Pack)) { $packArg = @("pack=$Pack") }


# One dump out of one project folder, to an absolute file. `--headless --path <folder>` is how both
# halves are read, so the base and the tree are asked the same question by the same binary.
function Write-Dump($ProjectDir, $OutFile, $Words) {
	$userArgs = @("--headless", "--path", $ProjectDir, "--script", "tools/dump_registry.gd", "--", "out=$OutFile")
	$userArgs += $packArg
	if ($Words) { $userArgs += "words" }
	& $godot @userArgs | Out-Null
	if (-not (Test-Path $OutFile)) {
		Write-Output "no dump written for $ProjectDir (words=$Words)"
		exit 1
	}
}


# What moved between two texts, as the lines themselves. Sorted by key already, so a plain
# set difference reads as a diff a person can act on.
function Show-Moves($Name, $BaseFile, $HeadFile) {
	$before = Get-Content -LiteralPath $BaseFile
	$after = Get-Content -LiteralPath $HeadFile
	$moves = Compare-Object -ReferenceObject $before -DifferenceObject $after
	if ($null -eq $moves -or $moves.Count -eq 0) { return $true }
	Write-Output "$Name moved on $($moves.Count) line(s):"
	foreach ($move in ($moves | Select-Object -First 20)) {
		$side = 'base only'
		if ($move.SideIndicator -eq '=>') { $side = 'tree only' }
		Write-Output ("  [{0}] {1}" -f $side, $move.InputObject)
	}
	if ($moves.Count -gt 20) { Write-Output "  ... and $($moves.Count - 20) more" }
	return $false
}


# The formatter, not the vocabulary - see THE INSTRUMENT IS THE SAME ON BOTH SIDES above.
$Instrument = @(
	'tools/dump_registry.gd',
	'tools/registry_wording.gd',
	'addons/eventforge/registration/registry_dump.gd'
)

if (-not (Test-Path $tree)) {
	Write-Output "preparing a detached worktree at $baseShort (first run also imports the project)"
	& git -C $repo worktree add --detach $tree $baseSha | Out-Null
	& $godot --headless --path $tree --import | Out-Null
}

foreach ($file in $Instrument) {
	Copy-Item -LiteralPath (Join-Path $repo $file) -Destination (Join-Path $tree $file) -Force
}

Write-Dump $tree (Join-Path $dumps "$baseShort-registry.txt") $false
Write-Dump $tree (Join-Path $dumps "$baseShort-words.txt") $true
Write-Dump $repo (Join-Path $dumps "tree-registry.txt") $false
Write-Dump $repo (Join-Path $dumps "tree-words.txt") $true

$sameRegistry = Show-Moves "registry" (Join-Path $dumps "$baseShort-registry.txt") (Join-Path $dumps "tree-registry.txt")
$sameWords = Show-Moves "words" (Join-Path $dumps "$baseShort-words.txt") (Join-Path $dumps "tree-words.txt")

$verbs = (Get-Content -LiteralPath (Join-Path $dumps "tree-registry.txt")).Count - 1

$registryWord = 'MOVED'
if ($sameRegistry) { $registryWord = 'same' }
$wordsWord = 'MOVED'
if ($sameWords) { $wordsWord = 'same' }
Write-Output "identity: registry=$registryWord words=$wordsWord verbs=$verbs base=$baseShort"

if ($Clean) {
	& git -C $repo worktree remove --force $tree | Out-Null
	Write-Output "worktree at $baseShort removed"
}

if ($sameRegistry -and $sameWords) { exit 0 }
exit 1
