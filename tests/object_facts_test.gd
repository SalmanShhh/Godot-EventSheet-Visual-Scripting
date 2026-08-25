# Godot EventSheets - what an object IS, proved against a real script and a
# real scene rather than against strings a test made up.
#
# tests/fixtures/object_facts_player.gd + object_facts_player.tscn carry one of every shape the
# reading needs: instance variables, a function that answers yes-or-no (a condition on the sheet),
# two triggers, a family joined in code AND two written into the scene, a behavior pack node with a
# setting the scene changed, a sprite whose texture is the object's picture, and a plain child node.
#
# Everything under test is DERIVED and display-only, which is why the pins here are values and not
# counts: a lens that started reading a different scene would change what a row SAYS long before it
# changed how many rows there are.
@tool
class_name ObjectFactsTest
extends RefCounted

const SCRIPT_PATH := "res://tests/fixtures/object_facts_player.gd"
const SCENE_PATH := "res://tests/fixtures/object_facts_player.tscn"


static func run() -> bool:
	var passed: bool = true
	EventSheetObjectFacts.clear_cache()
	passed = _script_facts() and passed
	passed = _scene_facts() and passed
	passed = _entry_facts() and passed
	passed = _popup_identity_rows() and passed
	passed = _sheet_titles() and passed
	passed = _signal_notes() and passed
	passed = _object_bar_sections() and passed
	passed = _thumbnails_are_icon_only_headless() and passed
	return passed


# ── The object's own script ───────────────────────────────────────────────────────────────────


static func _script_facts() -> bool:
	var passed: bool = true
	var facts: Dictionary = EventSheetObjectFacts.script_facts(SCRIPT_PATH)
	passed = _check("instance variables are the slots the object carries",
		_names(facts.get("variables", [])), "max_speed · hp · target") and passed
	passed = _check("functions read as the sheet says them, with their inputs",
		_signatures(facts.get("functions", [])),
		"Take Damage(amount) · Flee() · Is Alive() [condition]") and passed
	passed = _check("signals read as the triggers they are",
		_signatures(facts.get("triggers", [])), "On Died() · On Hit(body)") and passed
	passed = _check("a family joined in code is a family",
		" · ".join(PackedStringArray(facts.get("families", PackedStringArray()))), "respawnable") and passed
	# The engine's own callbacks are the engine calling the object, never a verb the sheet calls on
	# it - a list led by _ready buries the two functions the reader came for.
	passed = _check("engine callbacks are not functions the object offers",
		_names(facts.get("functions", [])).contains("_ready"), false) and passed
	passed = _check("a file that is not there answers with nothing",
		EventSheetObjectFacts.script_facts("res://tests/fixtures/not_a_file.gd").is_empty(), false) and passed
	return passed


# ── The scene the object is placed in ─────────────────────────────────────────────────────────


static func _scene_facts() -> bool:
	var passed: bool = true
	var facts: Dictionary = EventSheetObjectFacts.scene_facts(SCENE_PATH)
	passed = _check("the scene names its root and its class",
		"%s %s" % [str(facts.get("root", "")), str(facts.get("root_type", ""))],
		"Player CharacterBody2D") and passed
	passed = _check("the scene's persistent groups are the object's families",
		", ".join(PackedStringArray(facts.get("families", PackedStringArray()))),
		"player, damageable") and passed
	var behaviors: Array = facts.get("behaviors", [])
	var behavior_line: PackedStringArray = PackedStringArray()
	for entry: Variant in behaviors:
		var behavior: Dictionary = entry
		var settings: PackedStringArray = PackedStringArray()
		for property_entry: Variant in behavior.get("properties", []):
			var property: Dictionary = property_entry
			settings.append("%s = %s" % [str(property.get("name", "")), str(property.get("value", ""))])
		behavior_line.append("%s [%s]" % [str(behavior.get("name", "")), " · ".join(settings)])
	passed = _check("a pack node is a behavior, carrying what the scene set on it",
		" · ".join(behavior_line), "Health [max health = 50.0]") and passed
	passed = _check("the plain nodes stay plain children",
		_names(facts.get("children", [])), "Sprite2D · Camera2D") and passed
	passed = _check("the object's picture is the texture on its sprite",
		str(facts.get("picture", "")), "res://eventsheet_addons/behavior.svg") and passed
	passed = _check("one node's own picture is found by name",
		EventSheetObjectFacts.picture_of_node(SCENE_PATH, "Sprite2D"),
		"res://eventsheet_addons/behavior.svg") and passed
	passed = _check("a node with no texture has no picture",
		EventSheetObjectFacts.picture_of_node(SCENE_PATH, "Camera2D"), "") and passed
	return passed


static func _entry_facts() -> bool:
	var passed: bool = true
	var entry: Dictionary = {"label": "Player", "kind": "script", "class": "CharacterBody2D", "path": ""}
	var facts: Dictionary = EventSheetObjectFacts.facts_for_entry(entry, SCRIPT_PATH)
	passed = _check("the sheet's own object answers with its own script",
		str(facts.get("script_path", "")), SCRIPT_PATH) and passed
	passed = _check("its families are the scene's and the code's, in that order",
		", ".join(PackedStringArray(facts.get("families", PackedStringArray()))),
		"player, damageable, respawnable") and passed
	passed = _check("its behaviors come from the scene",
		_names(facts.get("behaviors", [])), "Health") and passed
	var child: Dictionary = {"label": "Camera2D", "kind": "node", "class": "Camera2D", "path": "$Camera2D"}
	passed = _check("a scene child with no script of its own has nothing to open",
		EventSheetObjectFacts.script_path_for_entry(child, SCRIPT_PATH), "") and passed
	return passed


static func _popup_identity_rows() -> bool:
	var passed: bool = true
	var entry: Dictionary = {"label": "Player", "kind": "script", "class": "CharacterBody2D", "path": ""}
	var lines: PackedStringArray = PackedStringArray()
	for row: Dictionary in EventSheetObjectProperties.identity_rows(entry, SCRIPT_PATH):
		lines.append("%s=%s" % [str(row.get("label", "")), str(row.get("value", ""))])
	passed = _check("the popup says what the object IS, section by section",
		" | ".join(lines),
		"Instance variables=max_speed · hp · target"
		+ " | Functions=Take Damage (amount) · Flee · Is Alive (condition)"
		+ " | Triggers=On Died · On Hit (body)"
		+ " | Behaviors=Health (max health = 50.0)"
		+ " | Base classes=player · damageable · respawnable") and passed
	# The Godot word rides along ONCE, muted, on the row that needs the bridge.
	var families_note: String = ""
	for row: Dictionary in EventSheetObjectProperties.identity_rows(entry, SCRIPT_PATH):
		if str(row.get("label", "")) == "Base classes":
			families_note = str(row.get("note", ""))
	passed = _check("the Godot word for a family is a muted note, not the name", families_note, "(groups)") and passed
	passed = _check("an object with no file behind it grows no sections",
		EventSheetObjectProperties.identity_rows({"label": "enemies", "kind": "group"}, "").is_empty(),
		true) and passed
	return passed


# ── Tabs and titles name the object ───────────────────────────────────────────────────────────


static func _sheet_titles() -> bool:
	var passed: bool = true
	var sheet := EventSheetResource.new()
	sheet.external_source_path = SCRIPT_PATH
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "ObjectFactsPlayer"
	var title: Dictionary = EventSheetObjectFacts.sheet_object_title(sheet, SCRIPT_PATH)
	passed = _check("a script with a class of its own is named for it",
		str(title.get("name", "")), "ObjectFactsPlayer") and passed
	passed = _check("the file it is stored in rides along for the hover",
		str(title.get("file", "")), SCRIPT_PATH) and passed
	# A scene script rarely declares a class, and "Player" is what its author calls it.
	var unnamed := EventSheetResource.new()
	unnamed.external_source_path = SCRIPT_PATH
	passed = _check("a script with no class is named for the object it drives",
		str(EventSheetObjectFacts.sheet_object_title(unnamed, SCRIPT_PATH).get("name", "")), "Player") and passed
	var pack := EventSheetResource.new()
	pack.external_source_path = "res://eventsheet_addons/health/health_behavior.gd"
	pack.custom_class_name = "SimpleHealthBehavior"
	var pack_title: Dictionary = EventSheetObjectFacts.sheet_object_title(
		pack, "res://eventsheet_addons/health/health_behavior.gd")
	passed = _check("a pack is named for the pack, and says so",
		"%s (%s)" % [str(pack_title.get("name", "")), str(pack_title.get("note", ""))],
		"Health (addon pack)") and passed
	return passed


# ── Who listens, and where it comes from ──────────────────────────────────────────────────────


static func _signal_notes() -> bool:
	var passed: bool = true
	passed = _check("the modern spelling is read",
		" ".join(EventSheetSignalFanout.emitted_signals_in("died.emit()")), "died") and passed
	passed = _check("the legacy spelling is read",
		" ".join(EventSheetSignalFanout.emitted_signals_in("emit_signal(\"died\", 3)")), "died") and passed
	passed = _check("an emit through an object names the signal, not the object",
		" ".join(EventSheetSignalFanout.emitted_signals_in("player.died.emit()")), "died") and passed
	passed = _check("a plain connect is read",
		" ".join(EventSheetSignalFanout.connected_signals_in("player.died.connect(_on_died)")), "died") and passed
	passed = _check("a quoted connect is read",
		" ".join(EventSheetSignalFanout.connected_signals_in("player.connect(\"died\", _on_died)")),
		"died") and passed
	passed = _check("a line that is neither says nothing",
		" ".join(EventSheetSignalFanout.emitted_signals_in("hp -= amount")), "") and passed
	var listeners: Array = [
		{"label": "HUD", "path": "res://hud.gd", "line": 12},
		{"label": "Level", "path": "res://level.gd", "line": 40}
	]
	passed = _check("an emit says who listens",
		EventSheetSignalFanout.listeners_note_for(listeners), "→ HUD, Level (2 listeners)") and passed
	passed = _check("one listener is one listener",
		EventSheetSignalFanout.listeners_note_for([listeners[0]]), "→ HUD (1 listener)") and passed
	passed = _check("nothing listening says nothing at all",
		EventSheetSignalFanout.listeners_note_for([]), "") and passed
	passed = _check("a handler says where the signal is raised",
		EventSheetSignalFanout.raised_note_for([
			{"label": "Player", "path": "res://player.gd", "line": 9, "function": "Take Damage"}
		]), "← emitted in player.gd: Take Damage") and passed
	passed = _check("more than one raise site is counted, not listed",
		EventSheetSignalFanout.raised_note_for([
			{"label": "Player", "path": "res://player.gd", "line": 9, "function": "Take Damage"},
			{"label": "Boss", "path": "res://boss.gd", "line": 4, "function": "Die"}
		]), "← emitted in player.gd: Take Damage (+1 more)") and passed
	# A trigger id is what the row holds; the signal behind it is what the note is about.
	passed = _check("a custom signal trigger resolves to its signal",
		ViewportRowBuilder.signal_name_of_trigger("signal:door_opened"), "door_opened") and passed
	passed = _check("a core signal trigger resolves back through the same table",
		ViewportRowBuilder.signal_name_of_trigger("OnBodyEntered"), "body_entered") and passed
	passed = _check("a lifecycle trigger is not a signal",
		ViewportRowBuilder.signal_name_of_trigger("OnReady"), "") and passed
	return passed


# ── The Object bar ────────────────────────────────────────────────────────────────────────────


static func _object_bar_sections() -> bool:
	var passed: bool = true
	var census: Array = [
		{"label": "Player", "kind": "script", "class": "CharacterBody2D", "path": "", "rows": 5,
			"verbs": PackedStringArray(), "signals": PackedStringArray()},
		{"label": "Sprite2D", "kind": "node", "class": "Sprite2D", "path": "$Sprite2D", "rows": 4,
			"verbs": PackedStringArray(), "signals": PackedStringArray()},
		{"label": "Boss", "kind": "node", "class": "", "path": "$Enemies/Boss", "rows": 1,
			"verbs": PackedStringArray(), "signals": PackedStringArray()},
		{"label": "Game", "kind": "autoload", "class": "", "path": "", "rows": 2,
			"verbs": PackedStringArray(), "signals": PackedStringArray()},
		{"label": "enemies", "kind": "group", "class": "", "path": "", "rows": 1,
			"verbs": PackedStringArray(), "signals": PackedStringArray()}
	]
	var scene_only: Array = EventSheetObjectsPanel.scene_only_entries(census, SCENE_PATH)
	passed = _check("what the sheet has not used yet is what the scene has left",
		_names(scene_only), "Camera2D") and passed
	var sections: Array = EventSheetObjectsPanel.sections_for(census, scene_only, "object_facts_player.tscn")
	var summary: PackedStringArray = PackedStringArray()
	for entry: Variant in sections:
		var section: Dictionary = entry
		summary.append("%s: %s" % [str(section.get("title", "")), _names(section.get("entries", []))])
	# Added the INPUT section between the scene and the globals: the controls a reader is looking
	# at are nearer to hand than the families they rarely touch. It is empty here because this fixture
	# names no control, and an empty section is never drawn.
	passed = _check("the bar is four sections, in the order a reader wants them",
		" | ".join(summary),
		"USED IN THIS SHEET: Player · Sprite2D · Boss"
		+ " | ALSO IN THE SCENE: Camera2D"
		+ " | INPUT: "
		+ " | GLOBALS & BASE CLASSES: Game · enemies") and passed
	passed = _check("the used section is its title and nothing else",
		EventSheetObjectsPanel.section_line(sections[0], 3), "USED IN THIS SHEET") and passed
	passed = _check("the scene section counts what is left and says what to do with it",
		EventSheetObjectsPanel.section_line(sections[1], 1),
		"ALSO IN THE SCENE  (1) - drag one onto the sheet to use it") and passed
	passed = _check("the globals section just counts",
		EventSheetObjectsPanel.section_line(sections[3], 2), "GLOBALS & BASE CLASSES  (2)") and passed
	# A name that resolves to nothing at runtime is the one thing in the bar a reader must not
	# scroll past, so it is flagged rather than listed like any other node.
	passed = _check("an object the scene does not have is flagged",
		" ".join(EventSheetObjectsPanel.missing_labels(census, SCENE_PATH)), "Boss") and passed
	passed = _check("with no scene there is nothing to be missing from",
		" ".join(EventSheetObjectsPanel.missing_labels(census, "")), "") and passed
	passed = _check("sorting by count puts the busiest object first",
		_names(EventSheetObjectsPanel.sorted_entries(census, "count")),
		"Player · Sprite2D · Game · Boss · enemies") and passed
	passed = _check("sorting by name is alphabetical",
		_names(EventSheetObjectsPanel.sorted_entries(census, "name")),
		"Boss · Game · Player · Sprite2D · enemies") and passed
	passed = _check("reading order is left exactly as the sheet introduced them",
		_names(EventSheetObjectsPanel.sorted_entries(census, "reading")),
		"Player · Sprite2D · Boss · Game · enemies") and passed
	passed = _check("the filter matches the name", EventSheetObjectsPanel.matches_filter(census[1], "spr"),
		true) and passed
	passed = _check("the filter matches the note too",
		EventSheetObjectsPanel.matches_filter(census[0], "characterbody"), true) and passed
	passed = _check("the filter drops what it does not match",
		EventSheetObjectsPanel.matches_filter(census[0], "zzz"), false) and passed
	passed = _check("hovering a count says what those rows ARE",
		EventSheetObjectsPanel.count_tooltip({"conditions": 2, "actions": 3, "triggers": 1}),
		"2 conditions · 3 actions · 1 trigger") and passed
	passed = _check("a lone condition is not pluralised",
		EventSheetObjectsPanel.count_tooltip({"conditions": 1, "actions": 0, "triggers": 0}),
		"1 condition") and passed
	passed = _check("a script with no scene says why the bar is empty and what to do",
		EventSheetObjectsPanel.empty_state_text(false),
		"This script is not on a scene yet - drop it on a node in the Scene dock and its objects appear here.") and passed
	return passed


# ── Headless stays icon-only ──────────────────────────────────────────────────────────────────


static func _thumbnails_are_icon_only_headless() -> bool:
	var passed: bool = true
	EventSheetObjectThumbnails.clear_cache()
	var entry: Dictionary = {"label": "Player", "kind": "script", "class": "CharacterBody2D", "path": ""}
	passed = _check("the object's picture is found as a path even with no editor",
		EventSheetObjectThumbnails.texture_path_for(entry, SCRIPT_PATH),
		"res://eventsheet_addons/behavior.svg") and passed
	# Thumbnails come from the editor's own preview cache, so a headless run has none and every
	# caller falls back to the class icon it already had.
	passed = _check("with no editor there is no thumbnail, only the class icon behind it",
		EventSheetObjectThumbnails.thumbnail_for(entry, SCRIPT_PATH) == null, true) and passed
	passed = _check("an object whose scene has no picture has no picture",
		EventSheetObjectThumbnails.texture_path_for(
			{"label": "Camera2D", "kind": "node"}, SCRIPT_PATH), "") and passed
	return passed


# ── Helpers ───────────────────────────────────────────────────────────────────────────────────


## The `name` of each record, joined - what a section or a fact list SAYS, in order.
static func _names(records: Array) -> String:
	var names: PackedStringArray = PackedStringArray()
	for entry: Variant in records:
		var record: Dictionary = entry
		names.append(str(record.get("name", record.get("label", ""))))
	return " · ".join(names)


## Each declaration as `Display(param, param)`, with `[condition]` on the ones that answer yes-or-no.
static func _signatures(declarations: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in declarations:
		var declaration: Dictionary = entry
		var line: String = "%s(%s)" % [
			str(declaration.get("display", "")),
			", ".join(PackedStringArray(declaration.get("params", PackedStringArray())))
		]
		if bool(declaration.get("condition", false)):
			line = "%s [condition]" % line
		parts.append(line)
	return " · ".join(parts)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] object facts: %s" % label)
		return true
	print("[FAIL] object facts: %s\n  expected: %s\n  actual:   %s" % [label, str(expected), str(actual)])
	return false
