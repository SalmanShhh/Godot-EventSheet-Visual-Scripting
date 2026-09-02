# EventForge - THE DESCRIPTOR-IDENTITY GATE, as one command (dev tool, Windows).
#
# A vocabulary module rewritten in a terser form is only proved unchanged when the vocabulary it
# publishes is byte-identical to what the verbose form published. This runs that proof: it dumps the
# vocabulary at a BASE commit and at the WORKING TREE in front of you, and reports whether the two
# texts match.
#
# THE GATE IS FOUR TEXTS, and no three of them are enough:
#
#   IDENTITY  tools/dump_registry.gd            key, type, shelf, parameters with their types and
#                                               defaults, forwarding address, emitted template.
#                                               A change here is a frozen-contract break.
#   WORDING   tools/dump_registry.gd -- words   name, description, reads-as sentence and the label
#                                               and description of every parameter. A migration can
#                                               keep every identity line and drop every description:
#                                               the plugin compiles the same code and every picker
#                                               in it goes blank. This is the text that sees that.
#   FIELDS    tools/dump_registry.gd -- fields  what a verb OFFERS: each parameter's hint, options,
#                                               autocomplete, reading lens, option-label flag and
#                                               required flag, and the descriptor's own node type,
#                                               signal, return type and the featured /
#                                               project-scoped / deprecated flags. None of it moves
#                                               an emitted byte or a word, so the two texts above
#                                               are blind to it - and a dropdown that went away, a
#                                               required flag that went false or a lost
#                                               .project_scoped() is an editor broken in front of a
#                                               user while both of them read `same`.
#   ORDER     tools/dump_registry.gd -- order   the registration SEQUENCE of every built-in
#                                               descriptor, and the reverse index in the exact
#                                               order the lifter walks it. The three texts above are
#                                               each SORTED BY KEY, which is what makes them
#                                               diffable and what makes them structurally blind to
#                                               order - and order is what decides which of two verbs
#                                               sharing an id shadows the other in the picker index,
#                                               and it is the reverse-lifter's TIE-BREAK where two
#                                               templates are equally specific. Split a module in
#                                               three and a hand-written line can come back as a
#                                               different row: identical bytes, a different sentence,
#                                               three sorted texts saying `same`. This is the
#                                               unsorted text that sees it.
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
# modules publish, and none of the copied files publishes a verb. It IS a blind spot all the same -
# a change to one of them between the base and the tree is a change both halves are read through, so
# the gate can no longer see it. The run therefore PRINTS what each copied file did between the two,
# as added and removed lines, so the one thing the gate cannot measure is the one thing it says out
# loud. A reviewer reads that list; a copied file that grew a rule rather than a field is a gate
# result to distrust.
#
# USAGE (from the repository root)
#   $env:GODOT = "<path to the Godot 4.7 console binary>"
#   powershell -File tools/prove_registry_identity.ps1 -Base <sha or ref>
#   powershell -File tools/prove_registry_identity.ps1 -Base <sha> -Pack platformer
#   powershell -File tools/prove_registry_identity.ps1 -Base <sha> -Clean
#
# Prints `identity: registry=<same|MOVED> words=<same|MOVED> fields=<same|MOVED>
# order=<same|MOVED> verbs=<n>` and exits 1 on any move, after naming the lines that moved.
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


# THE FOUR TEXTS, as a table rather than four copies of one call. `Word` is the argument that names
# the text on the dump tool's command line (blank for the identity dump, which is the default), and
# `Whole` says the text is a property of the WHOLE registry rather than of a set of verbs - which is
# true of `order` alone, and is why a -Pack run does not narrow it.
$Texts = @(
	@{ Name = 'registry'; Word = '';       Whole = $false },
	@{ Name = 'words';    Word = 'words';  Whole = $false },
	@{ Name = 'fields';   Word = 'fields'; Whole = $false },
	@{ Name = 'order';    Word = 'order';  Whole = $true }
)


# One dump out of one project folder, to an absolute file. `--headless --path <folder>` is how both
# halves are read, so the base and the tree are asked the same question by the same binary.
function Write-Dump($ProjectDir, $OutFile, $Text) {
	$userArgs = @("--headless", "--path", $ProjectDir, "--script", "tools/dump_registry.gd", "--", "out=$OutFile")
	if (-not $Text.Whole) { $userArgs += $packArg }
	if (-not [string]::IsNullOrWhiteSpace($Text.Word)) { $userArgs += $Text.Word }
	& $godot @userArgs | Out-Null
	if (-not (Test-Path $OutFile)) {
		Write-Output "no dump written for $ProjectDir ($($Text.Name))"
		exit 1
	}
}


# What moved between two texts, as the lines themselves - one record per line that is not the line
# at the same place in the other text.
#
# IT RETURNS THE MOVES AND PRINTS NOTHING, which is not a style choice. A PowerShell function
# returns everything it wrote to the output stream, so a function that both PRINTS its findings and
# `return $false`es hands its caller the printed lines AND the boolean as one array - and a non-empty
# array is true. Written that way this gate reported `same` over every real move it found, printed
# none of them, and could not fail. The caller below prints, and decides.
#
# THE COMPARISON IS CASE-SENSITIVE AND POSITIONAL. `Compare-Object` defaults to case-insensitive
# equality, which would call a re-cased description the same words; and it compares two texts as
# SETS, which cannot see two lines that swapped places. Three of the four texts are sorted by key and
# the fourth is deliberately not, so a positional walk is the honest reading of all four - and a
# length difference is itself a move.
function Get-Moves($BaseFile, $HeadFile) {
	$before = @(Get-Content -LiteralPath $BaseFile)
	$after = @(Get-Content -LiteralPath $HeadFile)
	$moves = New-Object System.Collections.ArrayList
	$longest = [Math]::Max($before.Count, $after.Count)
	for ($index = 0; $index -lt $longest; $index++) {
		$baseLine = if ($index -lt $before.Count) { $before[$index] } else { $null }
		$headLine = if ($index -lt $after.Count) { $after[$index] } else { $null }
		if ($baseLine -cne $headLine) {
			[void]$moves.Add([PSCustomObject]@{ Line = $index + 1; Base = $baseLine; Head = $headLine })
		}
	}
	return , $moves.ToArray()
}


# The moves as lines a person can act on. Prints only; the caller already holds the verdict.
function Show-Moves($Name, $Moves) {
	if ($Moves.Count -eq 0) { return }
	Write-Output "$Name moved on $($Moves.Count) line(s):"
	foreach ($move in ($Moves | Select-Object -First 20)) {
		Write-Output ("  line {0}" -f $move.Line)
		Write-Output ("    [base] {0}" -f $move.Base)
		Write-Output ("    [tree] {0}" -f $move.Head)
	}
	if ($Moves.Count -gt 20) { Write-Output "  ... and $($Moves.Count - 20) more" }
}


# The formatter, not the vocabulary - see THE INSTRUMENT IS THE SAME ON BOTH SIDES above.
$Instrument = @(
	'tools/dump_registry.gd',
	'tools/registry_wording.gd',
	'tools/registry_fields.gd',
	'tools/registry_order.gd',
	'addons/eventforge/registration/registry_dump.gd',
	# The reduction three of the four texts are written off. It gained the four WORDING fields when
	# the wording dump landed and the eleven FIELDS facts when the fields dump did, so a base older
	# than either answers that text with a text of blanks - which is not a vocabulary that lost its
	# words or its dropdowns, it is an instrument that cannot read them. It publishes no verb, so
	# copying it hides nothing this gate is for.
	'addons/eventforge/registration/ace_successors.gd'
)

if (-not (Test-Path $tree)) {
	Write-Output "preparing a detached worktree at $baseShort (first run also imports the project)"
	& git -C $repo worktree add --detach $tree $baseSha | Out-Null
	& $godot --headless --path $tree --import | Out-Null
}

foreach ($file in $Instrument) {
	Copy-Item -LiteralPath (Join-Path $repo $file) -Destination (Join-Path $tree $file) -Force
}

# The blind spot, named. `git diff <base>` reads the base against the WORKING TREE, which is the
# half the copies come from, so this is exactly what the gate is reading both sides through.
Write-Output "instrument (copied into the base worktree, so the gate reads both sides through the tree's copy):"
foreach ($file in $Instrument) {
	# A FILE THE BASE DOES NOT HAVE IS NOT AN UNCHANGED FILE. `git diff --numstat <sha> -- <path>`
	# prints nothing for a path that is untracked in the working tree, which is exactly what a
	# newly written instrument is - so the honest-blind-spot report used to say `unchanged` about the
	# two files that had just been invented. Ask the base whether it has the path at all first.
	$atBase = (& git -C $repo ls-tree -r --name-only $baseSha -- $file) | Select-Object -First 1
	if ([string]::IsNullOrWhiteSpace($atBase)) {
		$lines = @(Get-Content -LiteralPath (Join-Path $repo $file)).Count
		Write-Output ("  {0}  NEW since {1} ({2} lines, and the base is read through it)" -f $file, $baseShort, $lines)
		continue
	}
	$stat = (& git -C $repo diff --numstat $baseSha -- $file) | Select-Object -First 1
	if ([string]::IsNullOrWhiteSpace($stat)) {
		Write-Output ("  {0}  unchanged since {1}" -f $file, $baseShort)
		continue
	}
	$parts = $stat -split "`t"
	Write-Output ("  {0}  +{1}/-{2} since {3}" -f $file, $parts[0], $parts[1], $baseShort)
}

$verdicts = @()
$allSame = $true
foreach ($text in $Texts) {
	$baseFile = Join-Path $dumps "$baseShort-$($text.Name).txt"
	$treeFile = Join-Path $dumps "tree-$($text.Name).txt"
	Write-Dump $tree $baseFile $text
	Write-Dump $repo $treeFile $text
	$moves = Get-Moves $baseFile $treeFile
	Show-Moves $text.Name $moves
	if ($moves.Count -eq 0) {
		$verdicts += "$($text.Name)=same"
	} else {
		$verdicts += "$($text.Name)=MOVED"
		$allSame = $false
	}
}

$verbs = (Get-Content -LiteralPath (Join-Path $dumps "tree-registry.txt")).Count - 1

Write-Output "identity: $($verdicts -join ' ') verbs=$verbs base=$baseShort"

if ($Clean) {
	& git -C $repo worktree remove --force $tree | Out-Null
	Write-Output "worktree at $baseShort removed"
}

if ($allSame) { exit 0 }
exit 1
