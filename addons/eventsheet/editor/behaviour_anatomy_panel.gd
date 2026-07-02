@tool
class_name BehaviourAnatomyPanel
extends VBoxContainer
# The Behaviour Anatomy panel — a left-rail READ MODEL that shows the active sheet as an organism
# with always-visible "organs": Properties (exported knobs) · State (internal vars) · Triggers ·
# Actions · Conditions · Expressions · Uses (outside vocabulary it calls). A behaviour's whole
# public shape becomes one glance, and clicking an entry jumps the canvas to its row.
#
# PURE VIEW: it holds no sheet state and never writes — the census below only READS the sheet, so
# the byte round-trip is untouched. Entries are gathered from BOTH authoring layers: structured
# resources (SignalRow triggers, exposed EventFunctions) and, for opened packs whose verbs are still
# literal code, the `## @ace_*` annotation shells (the same classifier the canvas shells use), so an
# opened pack and an editor-authored sheet read through the same seven organs.

## The user clicked an entry — the workspace reveals that resource's row on the canvas.
signal reveal_requested(resource: Resource)

const _ORGAN_ACCENTS: Dictionary = {
	"properties": EventSheetPalette.TEXT_SECONDARY,
	"state": EventSheetPalette.TEXT_SECONDARY,
	"triggers": EventSheetPalette.COLOR_TRIGGER,
	"actions": EventSheetPalette.COLOR_ACTION,
	"conditions": EventSheetPalette.COLOR_CONDITION,
	"expressions": EventSheetPalette.COLOR_EXPRESSION,
	"uses": EventSheetPalette.TEXT_SECONDARY,
}

var _tree: Tree = null

func _init() -> void:
	name = "Anatomy"
	custom_minimum_size = Vector2(180.0, 120.0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title: Label = Label.new()
	title.text = "Anatomy"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", EventSheetPalette.TEXT_SECONDARY)
	add_child(title)
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_activated.connect(_on_item_activated)
	add_child(_tree)

## Rebuilds the organ tree from the sheet (called by the workspace on tab switch + after edits).
func refresh(sheet: EventSheetResource) -> void:
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	for organ: Dictionary in collect_anatomy(sheet):
		var entries: Array = organ.get("entries", [])
		var organ_item: TreeItem = _tree.create_item(root)
		organ_item.set_text(0, "%s · %d" % [str(organ.get("title")), entries.size()])
		organ_item.set_custom_color(0, _ORGAN_ACCENTS.get(str(organ.get("id")), EventSheetPalette.TEXT_SECONDARY))
		organ_item.set_selectable(0, false)
		if entries.is_empty():
			var ghost: TreeItem = _tree.create_item(organ_item)
			ghost.set_text(0, "(empty)")
			ghost.set_custom_color(0, EventSheetPalette.TEXT_MUTED)
			ghost.set_selectable(0, false)
			organ_item.collapsed = true
			continue
		for entry: Dictionary in entries:
			var item: TreeItem = _tree.create_item(organ_item)
			item.set_text(0, str(entry.get("label")))
			if entry.get("resource") is Resource:
				item.set_metadata(0, entry.get("resource"))
			else:
				item.set_custom_color(0, EventSheetPalette.TEXT_SECONDARY)

func _on_item_activated() -> void:
	var selected: TreeItem = _tree.get_selected()
	if selected != null and selected.get_metadata(0) is Resource:
		reveal_requested.emit(selected.get_metadata(0))

## The seven organs, ordered, as [{id, title, entries: [{label, resource?}]}] — static + pure so the
## census is unit-testable without a panel. `resource` is present when the entry has a canvas row to
## jump to (signals, functions, annotation shells); variables and providers are informational.
static func collect_anatomy(sheet: EventSheetResource) -> Array:
	var organs: Dictionary = {
		"properties": [], "state": [], "triggers": [],
		"actions": [], "conditions": [], "expressions": [], "uses": [],
	}
	if sheet != null:
		var names: Array = sheet.variables.keys()
		names.sort()
		for var_name: Variant in names:
			var descriptor: Dictionary = sheet.variables.get(var_name, {})
			var entry: Dictionary = {"label": "%s : %s" % [str(var_name), str(descriptor.get("type", "Variant"))]}
			# Match the compiler default: exported unless explicitly false.
			if bool(descriptor.get("exported", descriptor.get("exposed", true))):
				(organs["properties"] as Array).append(entry)
			else:
				(organs["state"] as Array).append(entry)
		var providers: Dictionary = {}
		for row: Variant in sheet.events:
			_collect_row(row, organs, providers)
		for entry: Variant in sheet.functions:
			if not (entry is EventFunction):
				continue
			var event_function: EventFunction = entry as EventFunction
			if not event_function.expose_as_ace:
				continue  # internal helpers aren't part of the published anatomy
			var label: String = event_function.ace_display_name.strip_edges()
			if label.is_empty():
				label = event_function.function_name.capitalize()
			(organs[ViewportRowBuilder.define_role_for(event_function) + "s"] as Array).append(
				{"label": label, "resource": event_function})
		var provider_names: Array = providers.keys()
		provider_names.sort()
		for provider: Variant in provider_names:
			(organs["uses"] as Array).append({"label": str(provider)})
	return [
		{"id": "properties", "title": "Properties", "entries": organs["properties"]},
		{"id": "state", "title": "State", "entries": organs["state"]},
		{"id": "triggers", "title": "Triggers", "entries": organs["triggers"]},
		{"id": "actions", "title": "Actions", "entries": organs["actions"]},
		{"id": "conditions", "title": "Conditions", "entries": organs["conditions"]},
		{"id": "expressions", "title": "Expressions", "entries": organs["expressions"]},
		{"id": "uses", "title": "Uses", "entries": organs["uses"]},
	]

static func _collect_row(row: Variant, organs: Dictionary, providers: Dictionary) -> void:
	if row is EventGroup:
		var group: EventGroup = row as EventGroup
		var group_rows: Array = group.events if not group.events.is_empty() else group.rows
		for child: Variant in group_rows:
			_collect_row(child, organs, providers)
		return
	if row is LocalVariable:
		# Tree variables — how opened packs (and tree-first authors) carry their designer knobs.
		var variable: LocalVariable = row as LocalVariable
		var organ: String = "properties" if variable.exported else "state"
		(organs[organ] as Array).append({
			"label": "%s : %s" % [variable.name, variable.type_name],
			"resource": variable,
		})
		return
	if row is SignalRow and (row as SignalRow).trigger:
		var signal_row: SignalRow = row as SignalRow
		var label: String = signal_row.ace_name.strip_edges()
		if label.is_empty():
			label = signal_row.signal_name
		(organs["triggers"] as Array).append({"label": label, "resource": signal_row})
		return
	if row is RawCodeRow:
		# Opened packs keep verbs as annotation shells — same classifier as the canvas shell rows.
		var shell: Dictionary = ViewportRowBuilder.define_shell_info((row as RawCodeRow).code)
		if not shell.is_empty():
			(organs[str(shell.get("kind")) + "s"] as Array).append(
				{"label": str(shell.get("name")), "resource": row})
		return
	if not (row is EventRow):
		return
	var event_row: EventRow = row as EventRow
	var aces: Array = []
	if event_row.trigger != null:
		aces.append(event_row.trigger)
	aces.append_array(event_row.conditions)
	aces.append_array(event_row.actions)
	if not event_row.trigger_provider_id.is_empty():
		aces.append(event_row)  # trigger identity can live on the row itself
	for ace: Variant in aces:
		var provider: String = ""
		if ace is EventRow:
			provider = (ace as EventRow).trigger_provider_id
		elif ace is Resource and (ace as Resource).get("provider_id") != null:
			provider = str((ace as Resource).get("provider_id"))
		# "Core" is the built-in vocabulary — Uses lists OUTSIDE vocabulary only.
		if not provider.is_empty() and provider != "Core":
			providers[provider] = true
	for sub_event: Variant in event_row.sub_events:
		_collect_row(sub_event, organs, providers)
