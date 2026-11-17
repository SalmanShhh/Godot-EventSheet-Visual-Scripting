# Godot EventSheets - what each short spelling opens as when a person typed the line.
#
# A row placed from the picker writes a plain number where a template only guards it (`>= 2.0`, not
# `>= maxf(2.0, 0.001)`), and so the reader holds a second, short spelling for every verb that has such a
# guard. A hand-written script is read through those spellings too, and no file the suite opens carries
# them, so nothing would notice a short spelling that began to read as another verb, or stopped reading
# as its own. This writes each short spelling out as a person would type it (the numbers are plain
# decimals, the other slots a plain name) and pins what it opens as, and that the file saves back byte
# for byte. A verb whose spelling spans several lines opens as the plain rows of its first line: that is
# what is pinned for it, so a later change in reading cannot slip by.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "short_spellings_hand_written_test"
const SLOT_PATTERN: String = "[{]([A-Za-z_][A-Za-z0-9_]*)[}]"

## What each short spelling opens as, keyed by the verb and the order of its spellings. The value is the
## verb(s) opened with `true` when the row asks for the short spelling on writing.
const OPENS_AS: Dictionary = {
	"WaitForAnyOf #1": "SetLocalVarTyped false",
	"WaitForAllOf #1": "SetLocalVarTyped false",
	"StartCountdown #1": "SetLocalVarTyped false",
	"PutOnCooldown #1": "SetLocalVarTyped false",
	"WaitUntil #1": "SetLocalVarTyped false",
	"CameraLookAtOverSeconds #1": "SetLocalVarTyped false",
	"IsWithinDistanceMetric #1": "IsWithinDistanceMetric true",
	"PushGroupAwayFrom #1": "",
	"PullGroupToward #1": "",
	"VanishRespawnIn #1": "SetVar false",
	"ApplyPushesWorld #1": "SetLocalVarTyped false",
	"ApplyPushes #1": "SetLocalVarTyped false",
	"OrbitAround #1": "SetLocalVarTyped false",
	"ReduceCooldownBy #1": "SetLocalVarTyped false",
	"HasBeenQuiet #1": "HasBeenQuiet true",
	"BobUpAndDown #1": "",
	"ApplyRadialImpulse #1": "SetLocalVarTyped false",
	"PointBoneAt2D #1": "PointBoneAt2D true",
	"PointBoneAt2D #2": "PointBoneAt2D true",
	"TurnToward #1": "TurnToward true",
	"IsWithinConeOf #1": "IsWithinConeOf true",
	"PushAwayFrom #1": "PushAwayFrom true",
	"PushAwayFrom #2": "PushAwayFrom true",
	"WaitBeforeNextTry #1": "WaitBeforeNextTry true",
	"BufferPress #1": "BufferPress true",
	"RepeatWithDelay #1": "",
	"StartCooldown #1": "StartCooldown true",
	"CallLater #1": "CallLater true",
	"SmoothMoveToward #1": "SmoothMoveToward true",
	"IsNodeWithinDistance #1": "IsNodeWithinDistance true",
	"IsNodeWithinDistance #2": "IsNodeWithinDistance true",
	"ChargeToward #1": "ChargeToward true",
	"SetAimAssistRadius #1": "SetAimAssistRadius true",
	"SetTextSizeScale #1": "SetTextSizeScale true",
	"WasRecentlyTrue #1": "WasRecentlyTrue true",
	"EveryRandomSeconds #1": "EveryRandomSeconds true",
	"AtMostEvery #1": "AtMostEvery true",
	"EveryXSeconds #1": "EveryXSeconds true",
}


static func run() -> bool:
	var ok: bool = true
	var seen: Dictionary = {}
	var opened: Dictionary = {}
	for entry: Variant in EventSheetACELifter._build_reverse_entries():
		var variant_entry: Dictionary = entry as Dictionary
		var floors: Dictionary = variant_entry["fold_floors"]
		if floors.is_empty():
			continue
		var ace_id: String = str(variant_entry["ace_id"])
		seen[ace_id] = int(seen.get(ace_id, 0)) + 1
		var key: String = "%s #%d" % [ace_id, int(seen[ace_id])]
		var source: String = _hand_written(variant_entry, floors)
		var sheet: EventSheetResource = SUPPORT.reopen(source, true, SUPPORT.own_path("short_spelling.gd"))
		opened[key] = _opened_as(sheet)
		ok = SUPPORT.check(P, "%s: the hand-written line saves back byte for byte" % key, SUPPORT.reemit(source, SUPPORT.own_path("short_spelling_back.gd")), source) and ok
	ok = SUPPORT.check(P, "how many short spellings the reader holds", opened.size(), OPENS_AS.size()) and ok
	for key: Variant in OPENS_AS.keys():
		ok = SUPPORT.check(P, "%s: opens as" % str(key), opened.get(key, "missing"), OPENS_AS[key]) and ok
	return ok


## The line a person would type for this spelling: floors filled with a plain decimal above every floor,
## every other slot with a name, and a condition inside an `if`.
static func _hand_written(variant_entry: Dictionary, floors: Dictionary) -> String:
	var line: String = str(variant_entry["variant"]).replace("{uid}", "a1b2c3d4")
	var slot_re: RegEx = RegEx.create_from_string(SLOT_PATTERN)
	for hit: RegExMatch in slot_re.search_all(str(variant_entry["variant"])):
		var slot: String = hit.get_string(1)
		if slot != "uid":
			line = line.replace("{%s}" % slot, "7.5" if floors.has(slot) else "sample_value")
	var source: String = "extends Node2D\n\nvar sample_value: float = 1.0\n\n\nfunc _process(delta: float) -> void:\n"
	if str(variant_entry["kind"]) == "condition":
		return source + "\tif %s:\n\t\tpass\n" % line
	return source + "\t" + line + "\n"


## The ace id and the short-spelling flag of every verb row the file opens as, in order.
static func _opened_as(sheet: EventSheetResource) -> String:
	var found: PackedStringArray = []
	for entry: Variant in sheet.events:
		if not (entry is EventRow):
			continue
		var rows: Array = (entry as EventRow).conditions + (entry as EventRow).actions
		for row: Variant in rows:
			if row is ACECondition or row is ACEAction:
				found.append("%s %s" % [str((row as Resource).get("ace_id")), str((row as Resource).get("folds_literals"))])
	return ", ".join(found)
