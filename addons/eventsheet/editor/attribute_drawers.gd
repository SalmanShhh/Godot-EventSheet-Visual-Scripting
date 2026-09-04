# Godot EventSheets - Inspector attribute drawers (Tier 3)
#
# One EditorInspectorPlugin recognizes the `eventsheet:<drawer>` marker that the compiler bakes into
# @export_custom hint strings, and swaps in a richer editor control. THE DEGRADATION CONTRACT: generated
# scripts stay plain GDScript - without this plugin (or in exported games) the property renders as a normal
# field, so the parity covenant is untouched. The actual widgets live in drawer_widgets.gd (reused by the
# Variable dialog's live preview); here we only map a marker+type to the right EditorProperty and forward edits.
#
# Drawers + marker forms:
#   progress_bar   eventsheet:progress_bar:<min>:<max>   int / float
#   min_max        eventsheet:min_max:<min>:<max>        Vector2 (x = low end, y = high end)
#   table          eventsheet:table:<n>=<t>,<n>=<t>      Array (of Dictionary rows; t: String/int/float/bool)
#   cards          eventsheet:cards:kind=<k>,schema=<n>,stripes=<k>
#                  Array (of Dictionary cards, each of a KIND, edited as a reorderable list of cards -
#                  the schema registered under <n> says what each kind is called and which fields it has)
#   toggle_row     eventsheet:toggle_row:<a>,<b>,<c>     String / int (choices as one row of toggle buttons;
#                  optional tails, in this order: ":segmented" for equal-width word buttons, ":icons=<source>"
#                  for a picture per option - a path pattern holding %s, or a registered provider's name)
#   unit           eventsheet:unit:kinds=<a>|<b>,store=<a> float (a spin box with a unit dropdown at its edge)
#   corners        eventsheet:corners                    Vector4 (one number, or four boxes clockwise from top-left)
#   vector_dial    eventsheet:vector_dial:<max>          Vector2
#   swatch_row     eventsheet:swatch_row                 Color
#   texture_preview eventsheet:texture_preview           Texture2D / String (path)
#   curve_editor   eventsheet:curve_editor               Curve
#
# Decor that belongs to the OBJECT rather than to one property is parsed beside this file:
# `# @inspector_preview` asks for the preview card at the top, and
# `# @inspector_handle <property> <kind> [from <property>]` declares a viewport handle.
@tool
class_name EventSheetAttributeDrawers
extends EditorInspectorPlugin

# The two decor lines that belong to the OBJECT rather than to one property - the preview card and
# the viewport handles - are parsed beside this file and loaded BY PATH here, so naming them never
# widens what an editor boot compiles (this plugin is constructed at boot; add_inspector_plugin
# takes an instance).
const OBJECT_DECOR_PATH: String = "res://addons/eventsheet/editor/inspector/object_decor.gd"
const PREVIEW_PANEL_PATH: String = "res://addons/eventsheet/editor/inspector/preview_panel.gd"
## The card-list drawer and its schema side, loaded BY PATH for the same reason: a property that
## never asks for cards must not pay for them at every editor start.
const CARD_LIST_DRAWER_PATH: String = "res://addons/eventsheet/editor/inspector/card_list_drawer.gd"
const CARD_SCHEMAS_PATH: String = "res://addons/eventsheet/editor/inspector/card_schemas.gd"


func _can_handle(_object: Object) -> bool:
	return true  # cheap: the per-property marker check below does the real filtering


## Object-level decor, above every property: a script carrying `# @inspector_preview` gets the shared
## preview card at the top of its Inspector, showing the object as it is and re-drawing as it changes.
## Anything else is left alone, so an object that asked for nothing renders exactly as Godot draws it.
func _parse_begin(object: Object) -> void:
	if load(OBJECT_DECOR_PATH).wants_preview(object):
		add_custom_control(load(PREVIEW_PANEL_PATH).new(object))


func _parse_property(_object: Object, type: Variant.Type, name: String, _hint_type: PropertyHint, hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	# Decor first: `# @inspector_header` / `# @inspector_info` comments above the var render as a section
	# label / info panel ABOVE the property, composing with any drawer (or the default field) below.
	for entry: Variant in decor_for(_object, name):
		var decor_entry: Dictionary = entry as Dictionary
		match str(decor_entry.get("kind", "")):
			"header":
				add_custom_control(EventSheetDrawerWidgets.build_header_label(str(decor_entry.get("text", "")), str(decor_entry.get("color", ""))))
			"required":
				add_custom_control(EventSheetDrawerWidgets.RequiredBadge.new(_object, name))
			"validate":
				add_custom_control(EventSheetDrawerWidgets.ValidateBadge.new(_object, str(decor_entry.get("function", ""))))
			"action":
				add_custom_control(EventSheetDrawerWidgets.ActionButton.new(_object, str(decor_entry.get("function", "")), str(decor_entry.get("label", ""))))
			"link":
				add_custom_control(EventSheetDrawerWidgets.LinkToggle.new(_object, str(decor_entry.get("first", "")), str(decor_entry.get("second", ""))))
			"group_show_if":
				# Nothing to draw: hiding the group is the ordinary _validate_property the compiler
				# emits once per member, exactly as the per-field Show If compiles. The entry is here
				# so the Designer (and anything else reading the map) can say WHY a group hides.
				pass
			_:
				add_custom_control(EventSheetDrawerWidgets.build_info_panel(str(decor_entry.get("text", ""))))
	var drawer: Dictionary = parse_drawer_hint(hint_string)
	var kind: String = str(drawer.get("drawer", ""))
	match kind:
		"progress_bar":
			if type != TYPE_INT and type != TYPE_FLOAT:
				return false
			add_property_editor(name, ProgressBarProperty.new(float(drawer.get("min", 0.0)), float(drawer.get("max", 100.0))))
			return true
		"min_max":
			if type != TYPE_VECTOR2:
				return false
			add_property_editor(name, MinMaxSliderProperty.new(float(drawer.get("min", 0.0)), float(drawer.get("max", 100.0))))
			return true
		"toggle_row":
			# String stores the option TEXT; int stores its INDEX (an enum written as buttons).
			if type != TYPE_STRING and type != TYPE_INT:
				return false
			var toggle_spec: Dictionary = parse_toggle_spec(drawer.get("args", []))
			var toggle_options: PackedStringArray = toggle_spec.get("options", PackedStringArray())
			if toggle_options.is_empty():
				return false
			add_property_editor(name, ToggleRowProperty.new(toggle_options, type == TYPE_INT,
				str(toggle_spec.get("icons", "")), bool(toggle_spec.get("segmented", false))))
			return true
		"unit":
			# The stored number never moves: the dropdown converts the VIEW, and the export says
			# which unit the file (and therefore the running game) is written in.
			if type != TYPE_FLOAT:
				return false
			var unit_args: Array = drawer.get("args", [])
			var unit_spec: Dictionary = parse_unit_spec(str(unit_args[0]) if unit_args.size() > 0 else "")
			var unit_ids: PackedStringArray = unit_spec.get("units", PackedStringArray())
			if unit_ids.is_empty():
				return false
			add_property_editor(name, UnitFieldProperty.new(unit_ids, str(unit_spec.get("store", ""))))
			return true
		"corners":
			# Four corners clockwise from the top-left. One number until they differ, then four
			# labelled boxes - the same shape margins and padding take.
			if type != TYPE_VECTOR4:
				return false
			add_property_editor(name, CornersProperty.new())
			return true
		"table":
			if type != TYPE_ARRAY:
				return false
			var args: Array = drawer.get("args", [])
			var columns: Array = parse_table_columns(str(args[0]) if args.size() > 0 else "")
			if columns.is_empty():
				return false
			add_property_editor(name, TableProperty.new(columns))
			return true
		"cards":
			# A list of Dictionaries, each of a kind: the reorderable card list. Both the untyped list
			# and Array[Dictionary] reach here as TYPE_ARRAY, exactly as the table drawer does.
			if type != TYPE_ARRAY:
				return false
			var cards_args: Array = drawer.get("args", [])
			var cards_spec: Dictionary = load(CARD_SCHEMAS_PATH).call("parse_cards_spec", str(cards_args[0]) if cards_args.size() > 0 else "")
			add_property_editor(name, CardListProperty.new(cards_spec))
			return true
		"vector_dial":
			if type != TYPE_VECTOR2:
				return false
			var args: Array = drawer.get("args", [])
			var dial_max: float = str(args[0]).to_float() if args.size() > 0 else 100.0
			add_property_editor(name, VectorDialProperty.new(dial_max))
			return true
		"swatch_row":
			if type != TYPE_COLOR:
				return false
			add_property_editor(name, SwatchRowProperty.new())
			return true
		"texture_preview":
			# Resource-class guard: a generated sheet only ever pairs this marker with a Texture2D (the compiler
			# type-gates it), but a hand-edited marker on another resource would otherwise attach a wrong picker.
			if type != TYPE_OBJECT or not _value_is_kind(_object, name, "Texture2D"):
				return false
			add_property_editor(name, TexturePreviewProperty.new())
			return true
		"curve_editor":
			if type != TYPE_OBJECT or not _value_is_kind(_object, name, "Curve"):
				return false
			add_property_editor(name, CurveEditorProperty.new())
			return true
	return false


## "eventsheet:progress_bar:0:200" -> {drawer:"progress_bar", args:["0","200"], min:0.0, max:200.0}.
## Anything not starting with the marker prefix -> {}. Static + UI-free so the headless suite pins the contract.
static func parse_drawer_hint(hint_string: String) -> Dictionary:
	if not hint_string.begins_with("eventsheet:"):
		return {}
	var parts: PackedStringArray = hint_string.split(":")
	var parsed: Dictionary = {"drawer": parts[1] if parts.size() > 1 else "", "args": Array(parts.slice(2))}
	if parts.size() > 2:
		parsed["min"] = parts[2].to_float()
	if parts.size() > 3:
		parsed["max"] = parts[3].to_float()
	return parsed


## "kinds=px|world|screen,store=world" -> {units: PackedStringArray, store: String}. The store falls
## back to the first listed unit, so a marker missing it (or naming a unit it does not list) still
## has a definite stored unit. Static + UI-free so the headless suite pins the contract.
static func parse_unit_spec(spec: String) -> Dictionary:
	var units: PackedStringArray = PackedStringArray()
	var store: String = ""
	for token: String in spec.split(","):
		var trimmed: String = token.strip_edges()
		if trimmed.begins_with("kinds="):
			for unit: String in trimmed.substr(6).split("|"):
				if not unit.strip_edges().is_empty():
					units.append(unit.strip_edges())
		elif trimmed.begins_with("store="):
			store = trimmed.substr(6).strip_edges()
	if units.is_empty():
		return {"units": units, "store": ""}
	if store.is_empty() or not units.has(store):
		store = units[0]
	return {"units": units, "store": store}


## The toggle-row marker's arguments -> {options, segmented, icons}. The option list is args[0];
## after it come the optional tails in a fixed order - "segmented", then "icons=<source>". The icon
## source is rejoined with ":" because a res:// path carries colons of its own.
## Static + UI-free so the headless suite pins the contract.
static func parse_toggle_spec(args: Array) -> Dictionary:
	var spec: Dictionary = {"options": PackedStringArray(), "segmented": false, "icons": ""}
	if args.is_empty():
		return spec
	var options: PackedStringArray = PackedStringArray()
	for option: String in str(args[0]).split(","):
		if not option.strip_edges().is_empty():
			options.append(option.strip_edges())
	spec["options"] = options
	for index: int in range(1, args.size()):
		var tail: String = str(args[index])
		if tail == "segmented":
			spec["segmented"] = true
		elif tail.begins_with("icons="):
			var joined: PackedStringArray = PackedStringArray()
			for rest: int in range(index, args.size()):
				joined.append(str(args[rest]))
			spec["icons"] = ":".join(joined).substr(6)
			break
	return spec


# Decor maps parsed per script, cached by source length (cosmetic-only, so a same-length edit missing
# the cache costs nothing worse than one stale render until the next real edit).
static var _decor_cache: Dictionary = {}


## The decor entries for one property, parsed from the object's script source. Decor comments are plain
## `#` lines (never `##` - those merge into the hover tooltip), so they reach the editor only through
## the source text, exactly like the parity covenant wants: inert in the exported game.
static func decor_for(object: Object, property: String) -> Array:
	if object == null:
		return []
	var script: GDScript = object.get_script() as GDScript
	if script == null:
		return []
	var source: String = script.source_code
	if source.find("# @inspector_") == -1:
		return []
	var key: int = script.get_instance_id()
	var cached: Variant = _decor_cache.get(key)
	if cached is Dictionary and int((cached as Dictionary).get("len", -1)) == source.length():
		return ((cached as Dictionary).get("map") as Dictionary).get(property, [])
	var map: Dictionary = build_decor_map(source)
	_decor_cache[key] = {"len": source.length(), "map": map}
	return map.get(property, [])


## property name -> Array of decor dicts ({kind:"header", text, color} / {kind:"info", text}), from raw
## script source. Decor binds to the next `var` declaration; tooltips (`##`) and `@export_*` annotation
## lines may sit between them (the canonical emission order); anything else orphans the decor.
static func build_decor_map(source: String) -> Dictionary:
	var map: Dictionary = {}
	var pending: Array = []
	# The show-if that scopes a whole @export_group: it rides above the group line and belongs to
	# every member below it, until the next group (or category) line replaces it.
	var group_scope: Dictionary = {}
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("# @inspector_header "):
			pending.append(_parse_header_decor(line.substr(20).strip_edges()))
		elif line.begins_with("# @inspector_info "):
			pending.append({"kind": "info", "text": line.substr(18).strip_edges()})
		elif line == "# @inspector_required":
			pending.append({"kind": "required"})
		elif line.begins_with("# @inspector_validate "):
			pending.append({"kind": "validate", "function": line.substr(22).strip_edges()})
		elif line.begins_with("# @inspector_action "):
			var action_spec: String = line.substr(20).strip_edges()
			var first_space: int = action_spec.find(" ")
			pending.append({
				"kind": "action",
				"function": action_spec.substr(0, first_space) if first_space > 0 else action_spec,
				"label": action_spec.substr(first_space + 1).strip_edges() if first_space > 0 else ""
			})
		elif line.begins_with("# @inspector_link "):
			var link_names: PackedStringArray = line.substr(18).strip_edges().split(" ", false)
			if link_names.size() == 2:
				pending.append({"kind": "link", "first": link_names[0], "second": link_names[1]})
		elif line.begins_with("# @inspector_show_if "):
			# Only meaningful directly above an @export_group line (the group-scoped form); above a
			# variable the show-if is the per-field attribute, which compiles rather than decorates.
			pending.append({"kind": "_show_if_pending", "predicate": line.substr(21).strip_edges()})
		elif line.begins_with("@export_group(") or line.begins_with("@export_category("):
			# A group line closes the previous group's scope and opens its own. A subgroup line does
			# NOT: it nests inside the group, so the group's show-if still covers its members. Only
			# the show-if is consumed here - the canonical emission puts a header / info / action
			# ABOVE the group line, and those still belong to the variable underneath it.
			group_scope = {}
			var carried: Array = []
			for waiting: Variant in pending:
				if str((waiting as Dictionary).get("kind", "")) != "_show_if_pending":
					carried.append(waiting)
				elif not str((waiting as Dictionary).get("predicate", "")).is_empty():
					group_scope = {"kind": "group_show_if", "predicate": str((waiting as Dictionary).get("predicate"))}
			pending = carried
		elif line.begins_with("var ") or (line.begins_with("@") and line.contains(" var ")):
			if not pending.is_empty() or not group_scope.is_empty():
				var var_name: String = _var_name_from_line(line)
				if not var_name.is_empty():
					var entries: Array = []
					if not group_scope.is_empty():
						entries.append(group_scope)
					for waiting: Variant in pending:
						if str((waiting as Dictionary).get("kind", "")) != "_show_if_pending":
							entries.append(waiting)
					if not entries.is_empty():
						map[var_name] = entries
				pending = []
		elif line.begins_with("#") or line.begins_with("@"):
			continue
		else:
			pending = []
			# A blank line between two members of a group is ordinary spacing, so the group's scope
			# survives it; a real statement (a function, a signal) means the export block is over.
			if not line.is_empty():
				group_scope = {}
	return map


## "Combat #e06666" -> {kind:"header", text:"Combat", color:"#e06666"}; a trailing token only counts as
## the accent when it is a full #rrggbb - anything else stays part of the title.
static func _parse_header_decor(text: String) -> Dictionary:
	var tokens: PackedStringArray = text.split(" ")
	var last: String = tokens[tokens.size() - 1] if tokens.size() > 1 else ""
	if last.length() == 7 and last.begins_with("#") and last.substr(1).is_valid_hex_number():
		return {"kind": "header", "text": text.substr(0, text.length() - last.length()).strip_edges(), "color": last}
	return {"kind": "header", "text": text, "color": ""}


## The declared name out of "var health: int = 100" or "@export(...) var health := 1".
static func _var_name_from_line(line: String) -> String:
	var after: String = line.substr(line.find("var ") + 4).strip_edges()
	for terminator: String in [":", "=", " "]:
		var at: int = after.find(terminator)
		if at != -1:
			after = after.substr(0, at)
	return after.strip_edges()


## "hp=int,name=String" -> [{name:"hp", type:"int"}, {name:"name", type:"String"}]. The table
## marker's column schema; unknown types fall back to String, nameless entries are dropped.
## Static + UI-free so the headless suite pins the contract.
static func parse_table_columns(spec: String) -> Array:
	var columns: Array = []
	for pair: String in spec.split(","):
		var trimmed: String = pair.strip_edges()
		if trimmed.is_empty():
			continue
		var eq: int = trimmed.find("=")
		var column_name: String = (trimmed.substr(0, eq) if eq > 0 else trimmed).strip_edges()
		var column_type: String = trimmed.substr(eq + 1).strip_edges() if eq > 0 else "String"
		if column_name.is_empty() or column_name.contains("="):
			continue
		# A fixed-choice column - enum(a|b|c) - renders as a dropdown; the options ride the schema.
		# By path, not by class name: this file is constructed at editor boot (add_inspector_plugin
		# takes an instance), and naming the compiler here would compile its whole subtree into every
		# session for one schema helper. The widgets module owns the cached load.
		var enum_options: Array = EventSheetDrawerWidgets.sheet_compiler().table_enum_options(column_type)
		if not enum_options.is_empty():
			columns.append({"name": column_name, "type": "enum", "options": enum_options})
			continue
		# "key" rides along with the plain types: it renders as text like a String column, and marks
		# the cells as translation keys for the translator sweep. Flattening it here would make the
		# declaration unreachable from a resource's own @export hint.
		if not column_type in ["String", "key", "int", "float", "bool", "color"]:
			column_type = "String"
		columns.append({"name": column_name, "type": column_type})
	return columns


## Best-effort resource-class guard for the TYPE_OBJECT drawers. A generated sheet only ever pairs the marker
## with the right resource type (the compiler type-gates emission), but a hand-edited marker could mismatch -
## e.g. a curve_editor on a Texture2D var. A null value (the default) is allowed (can't tell yet, and the
## picker is harmless); a present value of the wrong class fails, so we degrade to a plain field.
static func _value_is_kind(object: Object, name: String, type_class: String) -> bool:
	if object == null:
		return true
	var value: Variant = object.get(name)
	if value == null:
		return true
	return value is Object and (value as Object).is_class(type_class)

# ── EditorProperty wrappers (each embeds a reusable widget and forwards edits) ──


## Numeric progress bar: drag to set; emits an int back for int properties, a float for floats.
class ProgressBarProperty:
	extends EditorProperty
	var _bar: EventSheetDrawerWidgets.DrawerProgressBar

	func _init(min_value: float, max_value: float) -> void:
		_bar = EventSheetDrawerWidgets.DrawerProgressBar.new(min_value, max_value)
		_bar.value_changed.connect(_on_changed)
		add_child(_bar)
		add_focusable(_bar)

	func _on_changed(v: float) -> void:
		var is_int: bool = typeof(get_edited_object().get(get_edited_property())) == TYPE_INT
		emit_changed(get_edited_property(), int(round(v)) if is_int else v)

	func _update_property() -> void:
		_bar.set_value(float(get_edited_object().get(get_edited_property())))


## Vector2 min-max range: drag either handle to set the low (x) / high (y) end.
class MinMaxSliderProperty:
	extends EditorProperty
	var _slider: EventSheetDrawerWidgets.DrawerMinMaxSlider

	func _init(min_value: float, max_value: float) -> void:
		_slider = EventSheetDrawerWidgets.DrawerMinMaxSlider.new(min_value, max_value)
		_slider.value_changed.connect(_on_changed)
		add_child(_slider)
		add_focusable(_slider)

	func _on_changed(v: Vector2) -> void:
		emit_changed(get_edited_property(), v)

	func _update_property() -> void:
		_slider.set_value(get_edited_object().get(get_edited_property()))


## Fixed choices as one row of toggle buttons: the pressed button IS the value. A String property
## stores the option text; an int property stores the option's INDEX, which is how a plain
## @export_enum int already reads - so the same row of buttons serves both without a second drawer.
class ToggleRowProperty:
	extends EditorProperty
	var _row: EventSheetDrawerWidgets.DrawerToggleRow
	var _options: PackedStringArray = PackedStringArray()
	var _stores_index: bool = false

	func _init(options: PackedStringArray, stores_index: bool = false, icon_source: String = "", segmented: bool = false) -> void:
		_options = options
		_stores_index = stores_index
		_row = EventSheetDrawerWidgets.DrawerToggleRow.new(options, icon_source, segmented)
		_row.value_changed.connect(_on_changed)
		add_child(_row)
		set_bottom_editor(_row)

	func _on_changed(value: String) -> void:
		if not _stores_index:
			emit_changed(get_edited_property(), value)
			return
		var index: int = Array(_options).find(value)
		if index >= 0:
			emit_changed(get_edited_property(), index)

	func _update_property() -> void:
		var value: Variant = get_edited_object().get(get_edited_property())
		if not _stores_index:
			_row.set_value(str(value))
			return
		var index: int = int(value)
		_row.set_value(_options[index] if index >= 0 and index < _options.size() else "")


## Four corners in one property: one number while they agree, four labelled boxes when they do not.
class CornersProperty:
	extends EditorProperty
	var _corners: EventSheetDrawerWidgets.DrawerCorners

	func _init() -> void:
		_corners = EventSheetDrawerWidgets.DrawerCorners.new()
		_corners.value_changed.connect(_on_changed)
		add_child(_corners)
		set_bottom_editor(_corners)

	func _on_changed(value: Vector4) -> void:
		emit_changed(get_edited_property(), value)

	func _update_property() -> void:
		var value: Variant = get_edited_object().get(get_edited_property())
		_corners.set_value(value if value is Vector4 else Vector4.ZERO)


## A float with its unit: a spin box plus a unit dropdown at its edge. The dropdown converts what is
## SHOWN; what is stored stays in the unit the export named, so flipping it never rewrites the scene
## and never moves a number the running game reads.
class UnitFieldProperty:
	extends EditorProperty
	var _field: EventSheetDrawerWidgets.DrawerUnitField

	func _init(units: PackedStringArray, store_unit: String) -> void:
		_field = EventSheetDrawerWidgets.DrawerUnitField.new(units, store_unit)
		_field.value_changed.connect(_on_changed)
		add_child(_field)
		add_focusable(_field)

	func _on_changed(value: float) -> void:
		emit_changed(get_edited_property(), value)

	func _update_property() -> void:
		_field.set_value(float(get_edited_object().get(get_edited_property())))


## Array-of-Dictionary table: a grid with typed cell editors, add / remove / move-up.
class TableProperty:
	extends EditorProperty
	var _table: EventSheetDrawerWidgets.DrawerTable

	func _init(columns: Array) -> void:
		_table = EventSheetDrawerWidgets.DrawerTable.new(columns)
		_table.value_changed.connect(_on_changed)
		add_child(_table)
		set_bottom_editor(_table)

	func _on_changed(rows: Array) -> void:
		emit_changed(get_edited_property(), rows)
		# emit_changed writes `rows` onto the resource through the inspector's set(), which does NOT fire
		# the resource's `changed` signal - so live-preview listeners (the DrawingPrefab preview panel, a
		# DrawingPrefabStamp) never repaint on a table edit. Emit `changed` explicitly so they refresh
		# from the just-written value; the _update_property echo it may provoke is a no-op (equal value).
		var edited: Object = get_edited_object()
		if edited is Resource:
			(edited as Resource).emit_changed()

	func _update_property() -> void:
		# Guard by VALUE, not a one-shot flag: the echo from our own commit (and from the `changed`
		# signal we fire for the live preview) carries a value equal to what the grid already shows, so
		# we skip the rebuild and the cell being typed in keeps focus. Only an external change (undo,
		# reselecting the asset) brings a different value that actually rebuilds the grid.
		var value: Variant = get_edited_object().get(get_edited_property())
		var incoming: Array = value if value is Array else []
		if incoming == _table.get_value():
			return
		_table.set_value(incoming)


## A list of Dictionaries as a list of cards: drag to reorder, fold one open for its own fields.
## The widget is loaded BY PATH (see CARD_LIST_DRAWER_PATH) and spoken to through `connect` and
## `call`, so this boot-path file never names it and the two never form a cycle.
class CardListProperty:
	extends EditorProperty
	var _list: Control = null

	func _init(spec: Dictionary) -> void:
		_list = load(EventSheetAttributeDrawers.CARD_LIST_DRAWER_PATH).new(spec)
		_list.connect("value_changed", _on_changed)
		add_child(_list)
		set_bottom_editor(_list)

	func _on_changed(cards: Array) -> void:
		emit_changed(get_edited_property(), cards)
		# A property write does not fire a resource's `changed` signal, so live previews (a prefab's
		# picture, a stamp in the viewport) would not repaint. Fire it, as the table drawer does.
		var edited: Object = get_edited_object()
		if edited is Resource:
			(edited as Resource).emit_changed()

	func _update_property() -> void:
		# Guard by VALUE: the echo of our own commit carries what the list already shows, so skipping
		# it keeps the field being edited alive. Only an outside change (undo, reselecting) rebuilds.
		var value: Variant = get_edited_object().get(get_edited_property())
		var incoming: Array = value if value is Array else []
		if incoming == _list.call("get_value"):
			return
		_list.call("set_value", incoming)


## Vector2 dial: drag the handle to set direction + magnitude.
class VectorDialProperty:
	extends EditorProperty
	var _dial: EventSheetDrawerWidgets.DrawerVectorDial

	func _init(max_magnitude: float) -> void:
		_dial = EventSheetDrawerWidgets.DrawerVectorDial.new(max_magnitude)
		_dial.value_changed.connect(_on_changed)
		add_child(_dial)
		set_bottom_editor(_dial)

	func _on_changed(v: Vector2) -> void:
		emit_changed(get_edited_property(), v)

	func _update_property() -> void:
		_dial.set_value(get_edited_object().get(get_edited_property()))


## Colour swatch row: click a preset (or the picker) to set the colour.
class SwatchRowProperty:
	extends EditorProperty
	var _row: EventSheetDrawerWidgets.DrawerSwatchRow

	func _init() -> void:
		_row = EventSheetDrawerWidgets.DrawerSwatchRow.new()
		_row.value_changed.connect(_on_changed)
		add_child(_row)
		set_bottom_editor(_row)

	func _on_changed(c: Color) -> void:
		emit_changed(get_edited_property(), c)

	func _update_property() -> void:
		_row.set_value(get_edited_object().get(get_edited_property()))


## Texture preview: a Texture2D resource picker above a live thumbnail.
class TexturePreviewProperty:
	extends EditorProperty
	var _preview: EventSheetDrawerWidgets.DrawerTexturePreview
	var _picker: EditorResourcePicker

	func _init() -> void:
		var box: VBoxContainer = VBoxContainer.new()
		_picker = EditorResourcePicker.new()
		_picker.base_type = "Texture2D"
		_picker.resource_changed.connect(_on_resource_changed)
		box.add_child(_picker)
		_preview = EventSheetDrawerWidgets.DrawerTexturePreview.new()
		box.add_child(_preview)
		add_child(box)
		set_bottom_editor(box)

	func _on_resource_changed(resource: Resource) -> void:
		_preview.set_texture(resource as Texture2D)
		emit_changed(get_edited_property(), resource)

	func _update_property() -> void:
		var value: Variant = get_edited_object().get(get_edited_property())
		_picker.edited_resource = value as Resource
		_preview.set_texture(value as Texture2D)


## Curve editor: a Curve resource picker above a live inline render of the curve's shape.
class CurveEditorProperty:
	extends EditorProperty
	var _preview: EventSheetDrawerWidgets.DrawerCurvePreview
	var _picker: EditorResourcePicker

	func _init() -> void:
		var box: VBoxContainer = VBoxContainer.new()
		_picker = EditorResourcePicker.new()
		_picker.base_type = "Curve"
		_picker.resource_changed.connect(_on_resource_changed)
		box.add_child(_picker)
		_preview = EventSheetDrawerWidgets.DrawerCurvePreview.new()
		box.add_child(_preview)
		add_child(box)
		set_bottom_editor(box)

	func _on_resource_changed(resource: Resource) -> void:
		_preview.set_curve(resource as Curve)
		emit_changed(get_edited_property(), resource)

	func _update_property() -> void:
		var value: Variant = get_edited_object().get(get_edited_property())
		_picker.edited_resource = value as Resource
		_preview.set_curve(value as Curve)
