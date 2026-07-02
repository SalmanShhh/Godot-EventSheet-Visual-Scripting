# EventForge — the Behaviour Anatomy panel: a left-rail read model showing the active sheet as seven
# organs (Properties · State · Triggers · Actions · Conditions · Expressions · Uses), fed by a pure
# static census. Pins: variables split by exported flag, SignalRow triggers with friendly names,
# exposed EventFunctions classified like the Studio cards (internal helpers excluded), opened-pack
# annotation shells feeding the same organs, Uses listing outside providers only (never Core), the
# dock wiring (refresh on tab activate; entry click reveals the row), and that the census never
# writes (an opened pack still round-trips byte-identically after a census).
@tool
extends RefCounted
class_name AnatomyPanelTest

static func run() -> bool:
	var ok: bool = true

	# ── The census over an editor-authored sheet ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {
		"max_health": {"type": "float", "default": 100.0, "exported": true},
		"cooldown_left": {"type": "float", "default": 0.0, "exported": false},
	}
	var jumped: SignalRow = SignalRow.new()
	jumped.signal_name = "jumped"
	jumped.trigger = true
	jumped.ace_name = "On Jumped"
	sheet.events.append(jumped)
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var outside: ACEAction = ACEAction.new()
	outside.provider_id = "SimpleHealthBehavior"
	outside.ace_id = "method:heal"
	event.actions.append(outside)
	sheet.events.append(event)
	var heal: EventFunction = EventFunction.new()
	heal.function_name = "heal"
	heal.return_type = TYPE_NIL
	heal.expose_as_ace = true
	heal.ace_display_name = "Heal"
	sheet.functions.append(heal)
	var is_dead: EventFunction = EventFunction.new()
	is_dead.function_name = "is_dead"
	is_dead.return_type = TYPE_BOOL
	is_dead.expose_as_ace = true
	sheet.functions.append(is_dead)
	var helper: EventFunction = EventFunction.new()
	helper.function_name = "recalc"
	helper.return_type = TYPE_NIL
	helper.expose_as_ace = false
	sheet.functions.append(helper)

	var organs: Dictionary = _by_id(BehaviourAnatomyPanel.collect_anatomy(sheet))
	ok = _check("exported var → Properties", _labels(organs["properties"]), ["max_health : float"]) and ok
	ok = _check("internal var → State", _labels(organs["state"]), ["cooldown_left : float"]) and ok
	ok = _check("trigger signal listed by friendly name", _labels(organs["triggers"]), ["On Jumped"]) and ok
	ok = _check("exposed void fn → Actions", _labels(organs["actions"]), ["Heal"]) and ok
	ok = _check("exposed bool fn → Conditions (humanized)", _labels(organs["conditions"]), ["Is Dead"]) and ok
	ok = _check("internal helper NOT part of the anatomy",
		_labels(organs["actions"]).has("Recalc") or _labels(organs["conditions"]).has("Recalc"), false) and ok
	ok = _check("Uses lists the outside provider, never Core", _labels(organs["uses"]), ["SimpleHealthBehavior"]) and ok
	ok = _check("trigger entry carries its resource (click-to-jump)",
		(organs["triggers"] as Array)[0].get("resource") == jumped, true) and ok

	# ── The census over a REAL opened pack (annotation shells feed the same organs) ──
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	var pack_path: String = "res://eventsheet_addons/health/health_behavior.gd"
	var source: String = (FileAccess.open(pack_path, FileAccess.READ)).get_as_text()
	dock._load_sheet_from_path(pack_path)
	var pack_organs: Dictionary = _by_id(BehaviourAnatomyPanel.collect_anatomy(dock.get_current_sheet()))
	ok = _check("pack triggers found", (pack_organs["triggers"] as Array).size() > 0, true) and ok
	ok = _check("pack knobs found (exported tree variables → Properties)",
		(pack_organs["properties"] as Array).size() > 0, true) and ok
	ok = _check("pack actions found via annotation shells", (pack_organs["actions"] as Array).size() > 10, true) and ok
	ok = _check("pack expressions found", (pack_organs["expressions"] as Array).size() > 5, true) and ok
	ok = _check("Take Damage is an Action entry", _labels(pack_organs["actions"]).has("Take Damage"), true) and ok
	var reemitted: String = str(SheetCompiler.compile(dock.get_current_sheet(), pack_path).get("output", ""))
	ok = _check("the census never writes (drift stays 0)", reemitted == source, true) and ok

	# ── The panel + dock wiring (v2: custom-drawn rows, not a Tree) ──
	ok = _check("the dock built the panel", dock._anatomy_panel != null, true) and ok
	var header_count: int = 0
	var entry_with_resource: int = 0
	for row: Variant in dock._anatomy_panel._rows:
		if bool((row as Dictionary).get("header")):
			header_count += 1
		elif (row as Dictionary).get("resource") is Resource:
			entry_with_resource += 1
	ok = _check("seven organ headers always visible", header_count, 7) and ok
	ok = _check("entries carry jumpable resources", entry_with_resource > 0, true) and ok
	# Folding an organ hides its entries but keeps the header (view state only).
	var before_rows: int = dock._anatomy_panel._rows.size()
	dock._anatomy_panel._folded["triggers"] = true
	dock._anatomy_panel.refresh(dock.get_current_sheet())
	ok = _check("a folded organ hides its entries", dock._anatomy_panel._rows.size() < before_rows, true) and ok
	dock._anatomy_panel._folded.clear()

	dock.free()
	return ok

static func _by_id(organs: Array) -> Dictionary:
	var by_id: Dictionary = {}
	for organ: Dictionary in organs:
		by_id[str(organ.get("id"))] = organ.get("entries")
	return by_id

static func _labels(entries: Variant) -> Array:
	var labels: Array = []
	for entry: Dictionary in (entries as Array):
		labels.append(str(entry.get("label")))
	return labels

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] anatomy_panel_test: %s" % label)
		return true
	print("[FAIL] anatomy_panel_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
