# EventForge — the Publishes Manifest census. SheetIdentityBanner.manifest_for counts
# what a behaviour publishes — trigger signals, exposed functions by return type, exported knobs — from
# both structured rows AND un-lifted `## @ace_*` RawCode. Pins the counts + that _build_manifest_segments
# drops zero roles and pluralises.
@tool
extends RefCounted
class_name BannerManifestCountsTest

static func run() -> bool:
	var ok: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(_sig("jumped", true))
	sheet.events.append(_sig("landed", true))
	sheet.events.append(_sig("plain", false))          # a non-trigger signal is not published as an ACE
	sheet.events.append(_var("max_health", true))      # an exported knob
	sheet.events.append(_var("_internal", false))       # internal state is not a knob
	sheet.functions.append(_fn(TYPE_NIL, true))         # exposed void → action
	sheet.functions.append(_fn(TYPE_BOOL, true))        # exposed bool → condition
	sheet.functions.append(_fn(TYPE_FLOAT, true))       # exposed value → expression
	sheet.functions.append(_fn(TYPE_NIL, false))        # un-exposed helper is not published
	sheet.variables = {"speed": {"type": "float", "exported": true}, "hidden": {"exported": false}}
	var m: Dictionary = SheetIdentityBanner.manifest_for(sheet)
	ok = _check("triggers", int(m["triggers"]), 2) and ok
	ok = _check("actions", int(m["actions"]), 1) and ok
	ok = _check("conditions", int(m["conditions"]), 1) and ok
	ok = _check("expressions", int(m["expressions"]), 1) and ok
	ok = _check("knobs (1 tree + 1 dict exported)", int(m["knobs"]), 2) and ok

	# Un-lifted packs keep their verbs as annotated GDScript — the census counts those too.
	var raw_sheet: EventSheetResource = EventSheetResource.new()
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = "## @ace_action\nfunc a() -> void:\n\tpass\n## @ace_condition\nfunc b() -> bool:\n\treturn true\n## @ace_trigger\nsignal s"
	raw_sheet.events.append(raw)
	var rm: Dictionary = SheetIdentityBanner.manifest_for(raw_sheet)
	ok = _check("raw @ace_action counted", int(rm["actions"]), 1) and ok
	ok = _check("raw @ace_condition counted", int(rm["conditions"]), 1) and ok
	ok = _check("raw @ace_trigger counted", int(rm["triggers"]), 1) and ok

	# Segments drop zero roles and pluralise.
	var segments: Array = SheetIdentityBanner._build_manifest_segments({"triggers": 1, "actions": 0, "conditions": 0, "expressions": 0, "knobs": 3})
	ok = _check("only non-zero roles become segments", segments.size(), 2) and ok
	ok = _check("singular trigger", str(segments[0]["text"]), "➜ 1 trigger") and ok
	ok = _check("plural knobs", str(segments[1]["text"]), "@ 3 knobs") and ok
	ok = _check("null sheet → all zero", int(SheetIdentityBanner.manifest_for(null)["triggers"]), 0) and ok

	# Health chip: calm green when clean, amber flag count otherwise; save-time push only.
	ok = _check("clean health chip text", str(SheetIdentityBanner.health_chip(0)["text"]), "✓ no issues") and ok
	ok = _check("flagged health chip text", str(SheetIdentityBanner.health_chip(3)["text"]), "⚠ 3 flagged") and ok
	var banner: SheetIdentityBanner = SheetIdentityBanner.new()
	ok = _check("health starts unknown (no false green before a check)", banner._health_known, false) and ok
	banner.set_health(2)
	ok = _check("set_health records the count", banner._health_count, 2) and ok
	ok = _check("set_health marks it known", banner._health_known, true) and ok
	banner.free()

	return ok

static func _sig(name: String, trigger: bool) -> SignalRow:
	var signal_row: SignalRow = SignalRow.new()
	signal_row.signal_name = name
	signal_row.trigger = trigger
	return signal_row

static func _var(name: String, exported: bool) -> LocalVariable:
	var local_variable: LocalVariable = LocalVariable.new()
	local_variable.name = name
	local_variable.exported = exported
	return local_variable

static func _fn(return_type: int, expose: bool) -> EventFunction:
	var function: EventFunction = EventFunction.new()
	function.return_type = return_type
	function.expose_as_ace = expose
	return function

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] banner_manifest_counts_test: %s" % label)
		return true
	print("[FAIL] banner_manifest_counts_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
