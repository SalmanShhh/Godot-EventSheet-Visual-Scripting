# Godot EventSheets - demo/showcase/ must be exactly what tools/build_examples.gd emits today.
#
# The showcase tree is compiler output, exactly as eventsheet_addons/ is. eventsheet_addons/ has had
# a drift gate for a long time (tools/audit_addons.gd, plus a builder-versus-shipped test beside this
# one); the showcase tree had nothing, and it showed: a pack member-order change landed without a
# showcase regeneration and five .tscn files sat stale, over the order exported properties are
# written inside behavior nodes. Nobody noticed, because that disagreement only surfaces when
# somebody runs the rebuild - and then it looks like their change rather than like a debt that was
# already sitting there.
#
# This runs the real gate - `tools/build_examples.gd -- --check`, which snapshots the tree, runs the
# ORDINARY build over it, compares every byte and puts the committed bytes back - and pins its
# verdict at zero. Two pins, not one: a run that printed no verdict at all is a gate that did not
# run, and pinning only the drift count would read that as a pass.
#
# WHEN THIS FAILS the builder is the source and the committed tree is stale, so the fix is to
# regenerate (`godot --headless --path . --script tools/build_examples.gd`) and commit what moves -
# never to hand-edit a file under demo/showcase/. The failing lines name every drifted file.
#
# IT COSTS A WHOLE REBUILD, about seventy seconds, in a process of its own. That is why the gate is
# the build tool rather than a re-implementation of it: a cheaper check that read the committed bytes
# some other way would be a second answer waiting to disagree with the builder, which is the exact
# failure this exists to catch.
@tool
class_name ShowcaseDriftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

## The gate rewrites files under demo/showcase/ for the length of the check before putting them back,
## so it must never run beside a shard that is reading them. Declaring this joins the serial tail.
const PARALLEL_UNSAFE := true

## The gate, and the one word that turns the release-ritual builder into it.
const GATE: String = "res://tools/build_examples.gd"
const CHECK_FLAG: String = "--check"

## The verdict line the gate prints, and the key inside it this test reads.
const VERDICT_PREFIX: String = "showcases="
const DRIFT_KEY: String = "drifted="


static func run() -> bool:
	var output: Array = []
	var arguments: PackedStringArray = PackedStringArray(["--headless", "--path",
		ProjectSettings.globalize_path("res://"), "--script", GATE, "--", CHECK_FLAG])
	OS.execute(OS.get_executable_path(), arguments, output, true)
	var verdict: String = _verdict_line(output)
	# Every DRIFT line the gate printed, echoed here so a red run in a log names the files rather
	# than sending a reader to a second log to find out which ones moved.
	for line: String in _lines(output):
		if line.begins_with("DRIFT: "):
			print("  showcase_drift_test: %s" % line)
	return SUPPORT.pins("showcase_drift_test", [
		["the gate ran and printed its verdict", not verdict.is_empty(), true],
		["demo/showcase/ is what tools/build_examples.gd emits today (%s)" % verdict,
			_drift_count(verdict), 0],
	])


## The gate's verdict line, or "" when it printed none - which is what a crashed or unbuilt gate
## looks like, and is pinned as its own failure rather than folded into a drift count of zero.
static func _verdict_line(output: Array) -> String:
	for line: String in _lines(output):
		if line.begins_with(VERDICT_PREFIX):
			return line
	return ""


## The `drifted=` figure on that line, or -1 when there is no line to read it off, so a missing
## verdict can never be mistaken for a clean one.
static func _drift_count(verdict: String) -> int:
	for field: String in verdict.split(" ", false):
		if field.begins_with(DRIFT_KEY):
			return int(field.trim_prefix(DRIFT_KEY))
	return -1


## The subprocess output as whole lines. OS.execute hands back chunks rather than lines, and a
## chunk boundary lands mid-line often enough that a per-chunk match misses the verdict.
static func _lines(output: Array) -> PackedStringArray:
	var text: String = ""
	for chunk: Variant in output:
		text += "%s\n" % str(chunk)
	var lines: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		lines.append(line.strip_edges())
	return lines
