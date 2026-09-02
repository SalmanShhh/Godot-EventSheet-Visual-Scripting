# EventForge - A tween chain reads as Tween actions on the object being tweened, one action per
# row: `Player ▸ Tween position to target in 0.5 seconds  ease = Sine out`, the next step wearing
# "(after the previous)", a parallel run "(at the same time)", the callback "Tween then <action>",
# `await t.finished` the System wait and `kill()` the stop. The chain is joined across lines by the
# local's name, so the pre-pass that walks the file in ORDER is pinned here too, together with the
# refusals: a receiver that cannot prove it holds a tween keeps its own call reading.
#
# Display only - the file keeps its lines, so what this pins is the WORDS and the refusals.
@tool
class_name TweenReadingTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	var context: Dictionary = {
		"script_object": "Player", "self_object": "Player", "tween_locals": {"t": true},
		"tween_notes": {
			"t.tween_property(self, \"modulate:a\", 0.0, 0.3)": "after",
			"t.tween_property(self, \"scale\", big, 0.2)": "parallel"
		}
	}

	# ── The tween the local holds, and the row it declares ──
	ok = _check("a tween local declares an object", _statement("var t = create_tween()", context),
		" ▸ Local object t = a new tween") and ok
	ok = _check("the tree's spelling declares the same thing",
		_statement("var t := get_tree().create_tween()", context),
		" ▸ Local object t = a new tween") and ok

	# ── One action per step, on the object being tweened ──
	ok = _check("the one-line spelling",
		_statement("create_tween().tween_property(self, \"position\", target, 0.5)", context),
		"Player ▸ Tween position to target in 0.5 seconds") and ok
	ok = _check("easing is a chip",
		_statement("t.tween_property(self, \"position\", target, 0.5)"
			+ ".set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)", context),
		"Player ▸ Tween position to target in 0.5 seconds ease = Sine out") and ok
	ok = _check("the property words are the sheet's own",
		_statement("t.tween_property(self, \"modulate:a\", 0.0, 0.3)", context),
		"Player ▸ Tween opacity to 0 in 0.3 seconds (after the previous)") and ok
	ok = _check("a parallel step says so",
		_statement("t.tween_property(self, \"scale\", big, 0.2)", context),
		"Player ▸ Tween size to big in 0.2 seconds (at the same time)") and ok
	ok = _check("a tween on ANOTHER object names that object",
		_statement("t.tween_property($Hud/Label, \"rotation\", 0.0, 1.0)", context),
		"Label ▸ Tween angle to 0 in 1 seconds") and ok

	# ── The rest of the chain ──
	ok = _check("a callback is what it does", _statement("t.tween_callback(queue_free)", context),
		"Player ▸ Tween then Destroy") and ok
	ok = _check("loops repeat", _statement("t.set_loops(3)", context), "Player ▸ Tween repeat 3 times") and ok
	ok = _check("parallel is its own step", _statement("t.set_parallel()", context),
		"Player ▸ Tween the next steps at the same time") and ok
	ok = _check("kill stops the tween", _statement("t.kill()", context), "Player ▸ Stop tween") and ok
	ok = _check("waiting on a tween is waiting for the animation",
		_statement("await t.finished", context), "System ▸ ⏳ Wait for tween to finish") and ok

	# ── A statement written across lines with a trailing backslash is ONE statement ──
	ok = _check("a continued chain is one row",
		_statement("t.tween_property(self, \"position\", target, 0.5) \\\n\t.set_ease(Tween.EASE_IN)", context),
		"Player ▸ Tween position to target in 0.5 seconds ease = in") and ok

	# ── Refusals: nothing is claimed for a receiver that cannot prove it holds a tween ──
	ok = _check("an unknown receiver keeps its call reading",
		EventSheetSentence.tween_chain_parts("anim.tween_property(self, \"position\", target, 0.5)", context).is_empty(),
		true) and ok
	ok = _check("an await on an unknown receiver is not a tween wait",
		_statement("await anim.finished", context), "System ▸ ⏳ Wait for signal anim On Finished") and ok

	# ── The chain map is read off the file's own lines, in file order ──
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(
		"extends Node\n\nfunc _ready() -> void:\n\tvar t = create_tween()\n"
		+ "\tt.tween_property(self, \"position\", Vector2.ZERO, 0.5)\n"
		+ "\tt.tween_property(self, \"modulate:a\", 0.0, 0.3)\n"
		+ "\tt.set_parallel()\n"
		+ "\tt.tween_property(self, \"scale\", Vector2.ONE, 0.2)\n")
	var facts: Dictionary = EventSheetViewportReadingRows.tween_chain_facts(sheet)
	ok = _check("the local is recognised", (facts.get("locals", {}) as Dictionary).has("t"), true) and ok
	var notes: Dictionary = facts.get("notes", {})
	ok = _check("the first step wears no note",
		notes.has("t.tween_property(self, \"position\", Vector2.ZERO, 0.5)"), false) and ok
	ok = _check("the second step follows the first",
		notes.get("t.tween_property(self, \"modulate:a\", 0.0, 0.3)", ""), "after") and ok
	ok = _check("a step after set_parallel runs beside it",
		notes.get("t.tween_property(self, \"scale\", Vector2.ONE, 0.2)", ""), "parallel") and ok
	return ok


static func _statement(code: String, context: Dictionary) -> String:
	return _read(EventSheetSentence.statement(code, context))


static func _read(result: Dictionary) -> String:
	if result.is_empty():
		return "<none>"
	var out: String = "%s ▸ " % str(result.get("object", ""))
	for segment: Variant in result.get("segments", []):
		out += str((segment as Dictionary).get("text", ""))
	return out


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("tween_reading_test", label, actual, expected)
