@tool
class_name ACEParamsExpressionPicker
extends RefCounted
# The "Insert Expression" picker opened by the ƒx button next to an expression field - a visual
# expression builder. Lists EXPRESSION-type ACEs (grouped), the host object's reflected
# properties/methods, and the sheet's own variables (with member chaining while searching);
# picking one inserts its code fragment at the field's caret. Extracted from
# ace_params_dialog.gd to keep that file maintainable; it owns its own widgets and reaches the host
# ACEParamsDialog (the ACE registry, the host-class reflection, the value-bearing _fields, the live
# ƒx validation) through the `_host` back-reference, the same pattern as the other editor helpers.
#
# The host (ACEParamsDialog) keeps a one-line delegate for every method/var/static reached from
# outside (tests, the host's own field-builder) so callers and the by-class-name static calls
# (ACEParamsDialog.member_expression_fragment, …) keep working unchanged.

# The host ACEParamsDialog instance (named _host, not _dialog, because the host's OWN field is
# literally `var _dialog: ConfirmationDialog` - `_host._dialog` reads unambiguously). ACEParamsDialog
# extends RefCounted (not Control), so the back-ref is typed as the host class, and `_host._dialog` is
# the ConfirmationDialog this picker parents its window under.
var _host: ACEParamsDialog = null

var _expression_window: AcceptDialog = null
var _expression_tree: Tree = null
var _expression_search: LineEdit = null
var _robust_checkbox: CheckBox = null
var _inserts_label: Label = null
var _expression_target_key: String = ""
# Per-dialog-session cache of the Self section's derivation: typing in the search box only
# re-FILTERS, so re-deriving the census + all 76 packs' behaviour groups per keystroke (~25ms on
# a project-sized sheet) would be pure waste. Cleared on every open; the behaviour half also
# keys on the robust toggle.
var _self_section_cache: Dictionary = {}
# V11 - and the GLOBALS the sheet reaches for, for the same reason: answering that one scans every
# row of the sheet and then the autoloads' scripts, while typing in the search box only re-FILTERS.
# Only the globals are held: the sheet's own variables and its locals are a cheap walk, and holding
# those would hide a variable added while the dictionary is open. Keyed "globals" so a sheet that
# touches none still counts as derived. Cleared on every open, beside the caches above.
var _global_variables_cache: Dictionary = {}
var _behaviour_groups_cache: Dictionary = {}  # {robust(bool): Array}
# The grounded tier's input, derived once per open: the selected Scene-dock node that carries
# THIS sheet's script, read through its behaviour children ([{name, provider}]). Empty = no
# grounding, the fallback tier lists packs by class name. Tests and harnesses (no editor
# selection to read) inject through grounded_children_override.
var _grounded_children_cache: Array = []
var grounded_children_override: Array = []
# LIVE grounding: while the game runs a Live Values session, the dictionary asks the RUNNING
# instance for its behaviour children (dock wires live_query to the debugger's
# send_query_children and routes children_report_received back here). The reply upgrades the
# Behaviours subgroup asynchronously - real runtime names, including behaviours attached at
# runtime, which no edit-time tier can see. Empty owner = no live report this open.
var live_query: Callable = Callable()
var _live_owner: String = ""
var _live_instances: int = 0


func init(host: ACEParamsDialog) -> void:
	_host = host


func _open_expression_picker(target_key: String) -> void:
	_expression_target_key = target_key
	_ensure_expression_window()
	# Fresh derivation per open - the sheet (and the Scene-dock selection) may have changed since
	# the dialog last showed.
	_self_section_cache = {}
	_behaviour_groups_cache = {}
	_global_variables_cache = {}
	_live_owner = ""
	_live_instances = 0
	_grounded_children_cache = grounded_children_override if not grounded_children_override.is_empty() else _grounded_children_from_selection()
	# Live tier: ask the RUNNING game (if a Live Values session streams) for the real children.
	# Async - the reply upgrades the tree when it lands; until then the edit-time tiers stand.
	if live_query.is_valid():
		live_query.call(_sheet_script_path())
	# Spawn-heavy sheets DEFAULT to the robust behaviour access: their behaviours may attach at
	# runtime, where a $-path to an auto-named child misses silently. Re-derived on every open so
	# the default tracks the sheet as it grows; the checkbox stays a per-session user override.
	if _robust_checkbox != null:
		_robust_checkbox.set_pressed_no_signal(EventSheetSelfExpressions.is_spawn_heavy(_context_sheet()))
	_refresh_expression_tree()
	_expression_window.get_ok_button().disabled = true
	_expression_window.popup_centered(Vector2i(560, 460))
	_expression_search.grab_focus()


## The sheet behind the open dialog (null headless / before setup) - the Self section's census input.
func _context_sheet() -> EventSheetResource:
	if not _host._lint_context_provider.is_valid():
		return null
	return _host._lint_context_provider.call() as EventSheetResource


## The path a running/placed instance of this sheet carries as its script - the identity every
## grounding tier matches on ("" when the sheet was never saved).
func _sheet_script_path() -> String:
	var sheet: EventSheetResource = _context_sheet()
	if sheet == null:
		return ""
	var sheet_script_path: String = sheet.external_source_path.strip_edges()
	return sheet_script_path if not sheet_script_path.is_empty() else sheet.resource_path.strip_edges()


## The RUNNING game answered a query_children request. Adopt it only when it is OUR sheet's
## report and the dictionary is still open - a stale reply after the dialog moved on is noise.
## The live tier outranks the edit-time tiers: it is the only one that sees behaviours attached
## at runtime, under their real runtime names.
func _on_live_children_report(report: Dictionary) -> void:
	if _expression_window == null or not _expression_window.visible:
		return
	if str(report.get("script_path", "")) != _sheet_script_path() or _sheet_script_path().is_empty():
		return
	var children: Array = report.get("children", [])
	if children.is_empty():
		return
	_live_owner = str(report.get("owner_name", ""))
	_live_instances = int(report.get("instance_count", 0))
	_grounded_children_cache = children
	_behaviour_groups_cache = {}
	_refresh_expression_tree()


## The grounded tier's probe: the Scene-dock selection, kept ONLY when a selected node carries
## THIS sheet's script - grounding against someone else's node would list someone else's organs.
## Export-safe editor access (same pattern as the palette's scale bridge); returns [] everywhere
## an editor selection does not exist (headless tests, render harnesses, exported games).
func _grounded_children_from_selection() -> Array:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return []
	var sheet_script_path: String = _sheet_script_path()
	if sheet_script_path.is_empty():
		return []
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_selection"):
		return []
	var selection: Object = editor_interface.call("get_selection")
	if selection == null or not selection.has_method("get_selected_nodes"):
		return []
	for node: Variant in selection.call("get_selected_nodes"):
		if not (node is Node):
			continue
		var script: Script = (node as Node).get_script() as Script
		if script != null and script.resource_path == sheet_script_path:
			return EventSheetSelfExpressions.grounded_children(node as Node)
	return []


func _ensure_expression_window() -> void:
	if _expression_window != null:
		return
	_expression_window = AcceptDialog.new()
	# Event-sheet style: a floating EXPRESSIONS DICTIONARY, not a modal insert step. Non-exclusive
	# so the params dialog underneath stays live (type in the field, dictionary at your side),
	# and inserting keeps it OPEN - close with X, reopen any time with the field's ƒx
	# (Find Expressions) button. Typing in the field itself pops the unfocused autocomplete;
	# this window is the browsable catalog for when you don't know the name yet.
	_expression_window.title = "Expressions dictionary"
	_expression_window.visible = false
	_expression_window.exclusive = false
	_expression_window.dialog_hide_on_ok = false
	_expression_window.min_size = Vector2i(480, 360)
	_expression_window.ok_button_text = "Insert"
	_expression_window.get_ok_button().disabled = true
	_expression_window.close_requested.connect(func() -> void: _expression_window.hide())
	_expression_window.confirmed.connect(_on_expression_activated)
	_host._dialog.add_child(_expression_window)

	# Standard body margins + a consistent form box (matches the picker + node picker).
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	var margin: MarginContainer = EventSheetPopupUI.margined(content)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_expression_window.add_child(margin)

	content.add_child(EventSheetPopupUI.hint_label("Double-click to insert at the cursor - the dictionary stays open so results chain. You can also just type in the field: the same expressions autocomplete as you go."))

	_expression_search = LineEdit.new()
	_expression_search.placeholder_text = "Search expressions..."
	_expression_search.clear_button_enabled = true
	_expression_search.text_changed.connect(func(_text: String) -> void: _refresh_expression_tree())
	# Enter commits the first result (parity with the main ACE picker's type-and-Enter).
	_expression_search.text_submitted.connect(func(_text: String) -> void: _activate_first_expression_match())
	content.add_child(_expression_search)

	# Behaviour access form: $Name (editor-attached child) vs get_node_or_null("Name") (survives a
	# behaviour attached at runtime). Defaulted per sheet on open (spawn-heavy sheets start robust).
	_robust_checkbox = CheckBox.new()
	_robust_checkbox.text = "Robust behaviour lookups (get_node_or_null)"
	_robust_checkbox.tooltip_text = "Behaviour entries insert get_node_or_null(\"Name\") instead of $Name - the access that keeps working when a behaviour is attached at runtime, where a $-path to an auto-named child misses silently. Defaults on for sheets that spawn objects."
	_robust_checkbox.toggled.connect(func(_pressed: bool) -> void: _refresh_expression_tree())
	content.add_child(_robust_checkbox)

	_expression_tree = Tree.new()
	_expression_tree.hide_root = true
	_expression_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expression_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_expression_tree.item_activated.connect(_on_expression_activated)
	_expression_tree.item_selected.connect(_on_expression_selection_changed)
	# Bare Control holder bounds the dialog height (a Tree reports its full content height as its
	# minimum, which an AcceptDialog would otherwise grow to fit).
	var expr_holder: Control = Control.new()
	expr_holder.custom_minimum_size = Vector2(0.0, 300.0)
	expr_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expr_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_expression_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	expr_holder.add_child(_expression_tree)
	var expr_card: PanelContainer = EventSheetPopupUI.titled_card("Expressions", expr_holder)
	expr_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(expr_card)

	# V11 - the one line under the tree: what the highlighted entry actually inserts. A global reads
	# `Score` in its group and inserts `Game.Score`, and this is where a reader finds that out before
	# it lands in the field rather than after.
	_inserts_label = EventSheetPopupUI.hint_label("")
	content.add_child(_inserts_label)


func _refresh_expression_tree() -> void:
	if _expression_tree == null or _host._registry == null:
		return
	_expression_tree.clear()
	var root: TreeItem = _expression_tree.create_item()
	var query: String = _expression_search.text.strip_edges()
	# The Self section pins FIRST - the "what does my object know about itself" reflex. A
	# self-scoped query ("self", "Self.X") filters WITHIN the section and hides the rest of the
	# tree, mirroring how typing Self. elsewhere scopes the panel to the object's own list.
	var self_query: Dictionary = EventSheetSelfExpressions.normalize_query(query)
	_add_self_section(root, str(self_query.get("remainder", "")))
	if bool(self_query.get("self_scoped", false)):
		return
	var group_nodes: Dictionary = {}
	for definition: ACEDefinition in _host._registry.search(query):
		if definition.ace_type != ACEDefinition.ACEType.EXPRESSION:
			continue
		var node_type: String = str(definition.metadata.get("node_type", "")).strip_edges()
		var group_key: String = node_type if not node_type.is_empty() else (definition.category if not definition.category.is_empty() else "General")
		if not group_nodes.has(group_key):
			var group_item: TreeItem = _expression_tree.create_item(root)
			group_item.set_text(0, group_key)
			group_item.set_custom_color(0, ACEPickerDialog.GROUP_COLOR_NODE_TYPE if not node_type.is_empty() else ACEPickerDialog.GROUP_COLOR_NEUTRAL)
			group_item.set_selectable(0, false)
			group_nodes[group_key] = group_item
		var item: TreeItem = _expression_tree.create_item(group_nodes[group_key])
		item.set_text(0, definition.display_name)
		item.set_custom_color(0, ACEPickerDialog.ITEM_COLOR_EXPRESSION)
		if not definition.description.is_empty():
			item.set_tooltip_text(0, definition.description)
		item.set_metadata(0, definition)
	# Visual expression builder: also list the host object's OWN members (reflected),
	# so any property/method is pickable without typing - not just registered ACEs.
	var host_class: String = _host._host_class_for_context()
	_add_member_expression_group(root, "This Object - Properties", ACEParamsDialog.reflected_members(host_class, "property"), false, query)
	_add_member_expression_group(root, "This Object - Methods", ACEParamsDialog.reflected_members(host_class, "method"), true, query)
	# Beyond `self`: the sheet's own variables as one-click leaves, plus - while searching - the typed
	# members of any class-backed variable (enemy.health) so reflection isn't limited to the host.
	_add_sheet_variable_expressions(root, query)


## The pinned Self section: the sheet's own variables, the host's event-sheet-common properties
## under their familiar names, and the sheet's expression functions - each leaf inserting plain
## GDScript.
## The model (and its host gating) lives in EventSheetSelfExpressions, static + pure; this only
## draws it. Subgroups with no surviving entries are dropped, never shown empty.
func _add_self_section(root: TreeItem, lowered_query: String) -> void:
	var sheet: EventSheetResource = _context_sheet()
	if _self_section_cache.is_empty():
		_self_section_cache = EventSheetSelfExpressions.section_for(sheet, _host._host_class_for_context())
	var section: Dictionary = _self_section_cache
	var self_item: TreeItem = null
	for subgroup: Array in [
		["Variables", section.get("variables", [])],
		["Properties", section.get("properties", [])],
		["Functions", section.get("functions", [])],
		["Host", section.get("host", [])],
	]:
		var survivors: Array = []
		for entry: Variant in (subgroup[1] as Array):
			if entry is Dictionary and EventSheetSelfExpressions.entry_matches(entry, lowered_query):
				survivors.append(entry)
		if survivors.is_empty():
			continue
		if self_item == null:
			self_item = _self_root(root)
		var subgroup_item: TreeItem = _expression_tree.create_item(self_item)
		subgroup_item.set_text(0, str(subgroup[0]))
		subgroup_item.set_custom_color(0, ACEPickerDialog.GROUP_COLOR_NEUTRAL)
		subgroup_item.set_selectable(0, false)
		_add_self_leaves(subgroup_item, survivors)
	# Behaviours: one child group per pack, its knobs and value-returning verbs as $Pack.member
	# chains. GROUNDED tier when the sheet's own instance is selected in the Scene dock (real
	# child names, nothing guessed); otherwise the fallback tier lists packs by class name -
	# used-by-this-sheet packs lead and stay open, the rest trail collapsed for browsing.
	var robust: bool = _robust_checkbox != null and _robust_checkbox.button_pressed
	var grounded: bool = not _grounded_children_cache.is_empty()
	if not _behaviour_groups_cache.has(robust):
		_behaviour_groups_cache[robust] = EventSheetSelfExpressions.grounded_groups(_grounded_children_cache, robust) if grounded \
			else EventSheetSelfExpressions.behaviour_groups(sheet, robust)
	var behaviours_item: TreeItem = null
	for pack: Dictionary in (_behaviour_groups_cache[robust] as Array):
		var survivors: Array = []
		for entry: Variant in pack.get("entries", []):
			if entry is Dictionary and EventSheetSelfExpressions.entry_matches(entry, lowered_query):
				survivors.append(entry)
		if survivors.is_empty():
			continue
		if self_item == null:
			self_item = _self_root(root)
		if behaviours_item == null:
			behaviours_item = _expression_tree.create_item(self_item)
			var behaviours_label: String = "Behaviours"
			var behaviours_tooltip: String = "Attached behaviours' knobs and value expressions, reached through the child node. Retarget the inserted $Name if yours is named differently - it stays selected after insert."
			if not _live_owner.is_empty():
				behaviours_label = "Behaviours (live · on %s)" % _live_owner
				if _live_instances > 1:
					behaviours_label += "  · 1 of %d running" % _live_instances
				behaviours_tooltip = "Read from the RUNNING game - these are the instance's actual behaviour children right now, including ones attached at runtime."
			elif grounded:
				behaviours_label = "Behaviours (on the selected node)"
				behaviours_tooltip = "Read off the node selected in the Scene dock - these are its actual behaviour children, under their real names."
			behaviours_item.set_text(0, behaviours_label)
			behaviours_item.set_custom_color(0, ACEPickerDialog.GROUP_COLOR_NEUTRAL)
			behaviours_item.set_selectable(0, false)
			behaviours_item.set_tooltip_text(0, behaviours_tooltip)
		var pack_item: TreeItem = _expression_tree.create_item(behaviours_item)
		if bool(pack.get("grounded", false)):
			pack_item.set_text(0, "$%s (%s)" % [str(pack.get("node_name")), str(pack.get("provider"))])
		else:
			pack_item.set_text(0, str(pack.get("provider")) + (" (used here)" if bool(pack.get("used")) else ""))
		pack_item.set_custom_color(0, ACEPickerDialog.GROUP_COLOR_NODE_TYPE)
		pack_item.set_selectable(0, false)
		# Browsing (no query): grounded groups are all real, so all open; in the fallback only
		# the packs this sheet already uses open expanded.
		pack_item.collapsed = lowered_query.is_empty() and not bool(pack.get("used"))
		_add_self_leaves(pack_item, survivors)


func _self_root(root: TreeItem) -> TreeItem:
	var self_item: TreeItem = _expression_tree.create_item(root)
	self_item.set_text(0, "Self")
	self_item.set_custom_color(0, ACEPickerDialog.GROUP_COLOR_NODE_TYPE)
	self_item.set_selectable(0, false)
	self_item.set_tooltip_text(0, "What this sheet's object knows about itself - every entry inserts plain GDScript.")
	return self_item


func _add_self_leaves(parent: TreeItem, entries: Array) -> void:
	for entry: Dictionary in entries:
		var item: TreeItem = _expression_tree.create_item(parent)
		item.set_text(0, str(entry.get("label", "")))
		item.set_custom_color(0, ACEPickerDialog.ITEM_COLOR_EXPRESSION)
		item.set_tooltip_text(0, str(entry.get("tooltip", "")))
		item.set_metadata(0, str(entry.get("fragment", "")))


## Adds a reflected-members group to the expression picker; methods insert as `name()`,
## properties as `name`. Honors the search query (case-insensitive substring filter).
func _add_member_expression_group(root: TreeItem, label: String, members: Array, is_method: bool, query: String) -> void:
	var lowered: String = query.to_lower()
	var group_item: TreeItem = null
	for member: Variant in members:
		var member_name: String = str(member)
		if not lowered.is_empty() and not member_name.to_lower().contains(lowered):
			continue
		if group_item == null:
			group_item = _expression_tree.create_item(root)
			group_item.set_text(0, label)
			group_item.set_custom_color(0, ACEPickerDialog.GROUP_COLOR_NODE_TYPE)
			group_item.set_selectable(0, false)
		var fragment: String = member_expression_fragment(member_name, is_method)
		var item: TreeItem = _expression_tree.create_item(group_item)
		item.set_text(0, fragment)
		item.set_custom_color(0, ACEPickerDialog.ITEM_COLOR_EXPRESSION)
		item.set_metadata(0, fragment)


## The insert fragment for a reflected member: `name()` for a method, `name` for a
## property. Static + pure, so it is unit-testable without a dialog.
static func member_expression_fragment(member: String, is_method: bool) -> String:
	return (member + "()") if is_method else member


## The insert fragment for a member reached THROUGH a variable: `enemy.health` / `enemy.move()`.
## Static + pure, so it is unit-testable without a dialog.
static func variable_member_fragment(var_name: String, member: String, is_method: bool) -> String:
	return var_name + "." + member_expression_fragment(member, is_method)


## V11. The sheet's variables as one-click leaves, GROUPED BY OWNER - this object's own first, then
## each autoload's globals, then the locals in scope - each written in the sentence its row reads
## with ("hp   whole number = 100") and inserting what the code needs (a bare name, or `Game.Score`
## for a global, where the prefix cannot be dropped). A variable whose type cannot go where this
## parameter is asking is greyed rather than hidden: knowing `alive` exists and is the wrong kind is
## the answer, and hiding it only makes the reader look for it.
##
## While searching it also chains the members of any variable whose declared type is a reflectable
## class, so `enemy.health` is one pick. Query-gated: a class can carry 100+ members, so showing them
## all for every variable would bury the idle tree - they surface as you type.
func _add_sheet_variable_expressions(root: TreeItem, query: String) -> void:
	if not _host._lint_context_provider.is_valid():
		return
	var sheet: EventSheetResource = _host._lint_context_provider.call() as EventSheetResource
	if sheet == null:
		return
	var lowered: String = query.to_lower()
	var wanted: String = _wanted_type()
	if not _global_variables_cache.has("globals"):
		_global_variables_cache["globals"] = EventSheetVariableOwners.global_entries(sheet)
	var catalog: Array[Dictionary] = EventSheetVariableOwners.own_entries(sheet)
	catalog.append_array(_global_variables_cache["globals"] as Array[Dictionary])
	catalog.append_array(EventSheetVariableOwners.local_entries(sheet))
	for group: Dictionary in EventSheetVariableOwners.group_entries(catalog):
		var group_item: TreeItem = null
		for entry: Dictionary in (group.get("entries", []) as Array):
			var name_str: String = str(entry.get("name", ""))
			if name_str.is_empty() or (not lowered.is_empty() and not name_str.to_lower().contains(lowered)):
				continue
			if group_item == null:
				group_item = _expression_tree.create_item(root)
				group_item.set_text(0, str(group.get("title", "")))
				group_item.set_custom_color(0, ACEPickerDialog.GROUP_COLOR_NEUTRAL)
				group_item.set_selectable(0, false)
			var item: TreeItem = _expression_tree.create_item(group_item)
			item.set_text(0, variable_leaf_text(entry))
			var fits: bool = EventSheetVariableOwners.fits(entry, wanted)
			item.set_custom_color(0, ACEPickerDialog.ITEM_COLOR_EXPRESSION if fits
				else ACEPickerDialog.GROUP_COLOR_NEUTRAL)
			item.set_selectable(0, fits)
			item.set_tooltip_text(0, EventSheetVariableOwners.sentence(entry) if fits
				else "%s - this field wants %s." % [
					EventSheetVariableOwners.sentence(entry),
					ViewportRowBuilder.friendly_type_word(wanted)])
			item.set_metadata(0, str(entry.get("insert_text", name_str)))
	# Member chaining (host.velocity) - only while searching, and only for class-backed variables.
	if lowered.is_empty():
		return
	for entry: Dictionary in _gather_sheet_variables(sheet):
		var vtype: String = str(entry.get("type_name", ""))
		if vtype.is_empty() or not ClassDB.class_exists(vtype):
			continue
		_add_variable_member_group(root, str(entry.get("name", "")), vtype, lowered)


## V11. One variable's line in the picker: the name, then the type word and what it starts as, then
## the Inspector note when the value is a designer knob. Static + pure, so the line is pinned without
## a dialog.
static func variable_leaf_text(entry: Dictionary) -> String:
	var text: String = str(entry.get("name", ""))
	var type_word: String = str(entry.get("type_word", "")).strip_edges()
	var value_text: String = str(entry.get("value", "")).strip_edges()
	if not type_word.is_empty():
		text += "   %s" % type_word
	if not value_text.is_empty():
		text += " = %s" % value_text
	if bool(entry.get("inspector", false)):
		text += "  · " + EventSheetL10n.translate("Inspector")
	return text


## The GDScript type the field that opened the picker is asking for, or "" when it asks for anything.
## Read off the parameter's own declared type, which is what the compiler will hand the template.
func _wanted_type() -> String:
	if _host._definition == null or _expression_target_key.is_empty():
		return ""
	for parameter: Variant in _host._definition.parameters:
		if parameter is Dictionary and str((parameter as Dictionary).get("id", "")) == _expression_target_key:
			return str((parameter as Dictionary).get("type_name", ""))
	return ""


## V11. The line under the tree: what picking the highlighted entry actually inserts, so the reader
## sees `Game.Score` before they insert it into a field that shows `Score`. "" when nothing is
## highlighted. Static + pure.
static func inserts_note(insert_text: String) -> String:
	if insert_text.strip_edges().is_empty():
		return ""
	return EventSheetL10n.translate("Inserts %s") % insert_text.strip_edges()


## Every reachable sheet variable as [{name, type_name}] - the census MOVED to
## EventSheetSelfExpressions.gather_sheet_variables so the Self section and this group can never
## drift apart; this stays as the delegate callers and tests already reach.
func _gather_sheet_variables(sheet: EventSheetResource) -> Array:
	return EventSheetSelfExpressions.gather_sheet_variables(sheet)


## A per-variable group of `varname.member` fragments (properties, then methods), filtered by the query.
func _add_variable_member_group(root: TreeItem, var_name: String, var_type: String, lowered_query: String) -> void:
	var group_item: TreeItem = null
	for kind: String in ["property", "method"]:
		var is_method: bool = kind == "method"
		for member: Variant in ACEParamsDialog.reflected_members(var_type, kind):
			var fragment: String = variable_member_fragment(var_name, str(member), is_method)
			if not fragment.to_lower().contains(lowered_query):
				continue
			if group_item == null:
				group_item = _expression_tree.create_item(root)
				group_item.set_text(0, "%s (%s)" % [var_name, var_type])
				group_item.set_custom_color(0, ACEPickerDialog.GROUP_COLOR_NODE_TYPE)
				group_item.set_selectable(0, false)
			var item: TreeItem = _expression_tree.create_item(group_item)
			item.set_text(0, fragment)
			item.set_custom_color(0, ACEPickerDialog.ITEM_COLOR_EXPRESSION)
			item.set_metadata(0, fragment)


## Enter in the expression-picker search box commits the first matching expression.
func _activate_first_expression_match() -> void:
	var first: TreeItem = _host._first_metadata_row(_expression_tree.get_root()) if _expression_tree != null else null
	if first != null:
		first.select(0)
		_on_expression_activated()


## Enables the "Insert" button only when a real expression row is highlighted.
func _on_expression_selection_changed() -> void:
	var selected: TreeItem = _expression_tree.get_selected() if _expression_tree != null else null
	if _expression_window != null:
		_expression_window.get_ok_button().disabled = selected == null or selected.get_metadata(0) == null
	if _inserts_label != null:
		var metadata: Variant = selected.get_metadata(0) if selected != null else null
		_inserts_label.text = inserts_note(str(metadata)) if metadata is String else ""


func _on_expression_activated() -> void:
	var item: TreeItem = _expression_tree.get_selected()
	if item == null:
		return
	var metadata: Variant = item.get_metadata(0)
	var insert_text: String = ""
	if metadata is ACEDefinition:
		insert_text = _expression_template(metadata as ACEDefinition)
	elif metadata is String:
		insert_text = str(metadata)
	if insert_text.is_empty():
		return
	# Insert at the caret so results compose into a larger expression (e.g. health + sin(time)). The OK
	# button still closes the window (AcceptDialog auto-hides on confirm); double-clicking a tree result
	# leaves the window open so several can be chained. The old code only handled LineEdit - and the
	# expression field is always a CodeEdit - so picking a result silently did nothing. This fixes it.
	_insert_into_expression_target(insert_text)


## Inserts a snippet at the caret of the expression field that opened the picker (the CodeEdit for
## _expression_target_key) and re-validates it. A behaviour chain leaves its node token SELECTED
## ($SineBehavior / the quoted name in get_node_or_null) so retargeting is one keystroke or a
## node drag - the fields already accept node drops.
func _insert_into_expression_target(snippet: String) -> void:
	var target: Variant = _host._fields.get(_expression_target_key)
	var span: Vector2i = EventSheetSelfExpressions.retarget_span(snippet) if not snippet.contains("\n") else Vector2i(-1, 0)
	if target is TextEdit:  # CodeEdit extends TextEdit
		var edit: TextEdit = target as TextEdit
		var caret_line: int = edit.get_caret_line()
		var caret_column: int = edit.get_caret_column()
		edit.insert_text_at_caret(snippet)
		if span.x >= 0:
			edit.select(caret_line, caret_column + span.x, caret_line, caret_column + span.x + span.y)
		_host._validate_expression_field(edit)
	elif target is LineEdit:
		var line_edit: LineEdit = target as LineEdit
		var caret: int = line_edit.caret_column
		line_edit.insert_text_at_caret(snippet)
		if span.x >= 0:
			line_edit.select(caret + span.x, caret + span.x + span.y)
		_host._validate_expression_field(line_edit)


## Returns the code template inserted for an expression definition (with default params).
func _expression_template(definition: ACEDefinition) -> String:
	var template: String = str(definition.metadata.get("codegen_template", ""))
	if template.is_empty():
		# Instance-backed reflected methods: insert the owned-instance call the compiler
		# understands (the display fallback below would paste prose as code).
		template = definition.instance_backed_template()
	if template.is_empty():
		var display: String = definition.format_display({})
		return display if not display.is_empty() else definition.display_name
	# Substitute default parameter values into the codegen template placeholders.
	for index in range(definition.parameters.size()):
		var parameter: Variant = definition.parameters[index]
		if not (parameter is Dictionary):
			continue
		var param_dict: Dictionary = parameter as Dictionary
		var param_key: String = str(param_dict.get("id", ""))
		if param_key.is_empty():
			continue
		var param_value: String = str(param_dict.get("default_value", param_dict.get("default", "")))
		template = template.replace("{%d}" % index, param_value)
		template = template.replace("{%s}" % param_key, param_value)
	return template
