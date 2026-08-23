@tool
class_name EventSheetCompareConditionDialog
extends RefCounted
# K2/K3 - the ONE Compare dialog.
#
# A comparison is the commonest question a sheet asks, and the vocabulary answers it with five
# separate conditions (Compare variable, Compare Values, Is Between Values, Is Outside Range, Values
# Are Near) plus a folder of text tests. Picking between five dialogs is a decision about ACE ids;
# what an author actually decides is three things - WHAT to compare, HOW, and TO WHAT. So this dialog
# asks exactly those three, and the operator chosen in the middle box decides which existing ACE the
# row becomes. No id changes, no new templates: the mapping table below is the whole feature.
#
# The left side's TYPE picks the operator list: a text variable is asked "begins with / contains / is
# one of", a number "at most / between / within ±". "Ignore case" is a tick rather than a separate
# verb, because that is what it is.
#
# Everything testable is static: `writes()` is the mapping table, `reads_as()` and `in_code()` are
# what the help strip shows, and none of them needs a Window. The strip's IN CODE line is produced by
# handing a throwaway ACECondition to ConditionCodegen, so the dialog can never promise a line the
# compiler would not write - including K4's inverted-comparison flip.

## Emitted when the dialog is confirmed. `ace_id` is one of the existing condition ids; the dock
## resolves it against the registry and applies it through the ordinary ACE apply path.
signal compare_confirmed(ace_id: String, params: Dictionary, negated: bool, context: Dictionary)

## Every ACE this dialog can write. Public because the dock uses it to decide which picks and which
## row edits open here instead of the generic parameters dialog - one list, so the two can never
## disagree about what "a comparison" is.
const PROVIDER := "Core"
const ACE_COMPARE_VAR := "CompareVar"
const ACE_COMPARE_VALUES := "CompareValues"
const ACE_IS_BETWEEN := "IsBetween"
const ACE_IS_OUTSIDE_RANGE := "IsOutsideRange"
const ACE_VALUES_ARE_NEAR := "ValuesAreNear"
const ACE_TEXT_EQUALS_IGNORE_CASE := "TextEqualsIgnoreCase"
const ACE_TEXT_BEGINS_WITH := "TextBeginsWith"
const ACE_TEXT_ENDS_WITH := "StringEndsWith"
const ACE_TEXT_CONTAINS := "StringContains"
const ACE_TEXT_IS_ONE_OF := "TextIsOneOf"
const ACE_TEXT_MATCHES := "TextMatchesPattern"
const ACE_TEXT_IS_EMPTY := "TextIsEmpty"

const COMPARE_ACE_IDS: PackedStringArray = [
	ACE_COMPARE_VAR, ACE_COMPARE_VALUES, ACE_IS_BETWEEN, ACE_IS_OUTSIDE_RANGE, ACE_VALUES_ARE_NEAR,
	ACE_TEXT_EQUALS_IGNORE_CASE, ACE_TEXT_BEGINS_WITH, ACE_TEXT_ENDS_WITH, ACE_TEXT_CONTAINS,
	ACE_TEXT_IS_ONE_OF, ACE_TEXT_MATCHES, ACE_TEXT_IS_EMPTY
]

## The RANGE operators - the three questions a single operator cannot ask. Their keys are words
## rather than symbols because there is no symbol for them, and the label carries the shape the
## question takes in code, the way the six comparison labels carry theirs.
const OPERATOR_BETWEEN := "between"
const OPERATOR_NOT_BETWEEN := "not between"
const OPERATOR_WITHIN := "within"

## The TEXT operators. Keys are the words a reader says; `is` and `is not` write a plain comparison,
## the rest write the text condition that already exists for them.
const OPERATOR_IS := "is"
const OPERATOR_IS_NOT := "is not"
const OPERATOR_BEGINS_WITH := "begins with"
const OPERATOR_ENDS_WITH := "ends with"
const OPERATOR_CONTAINS := "contains"
const OPERATOR_IS_ONE_OF := "is one of"
const OPERATOR_MATCHES := "matches"
const OPERATOR_IS_EMPTY := "is empty"

## How many value fields an operator needs, which is the only thing the dialog's layout asks of it.
const FIELDS_ONE := "one"
const FIELDS_TWO := "two"
const FIELDS_TOLERANCE := "tolerance"
const FIELDS_NONE := "none"

## What the left side of a comparison IS, which is what picks the operator list.
const KIND_NUMBER := "number"
const KIND_TEXT := "text"

## The free-text entry at the foot of the variable list: comparing something that is not one of the
## sheet's own variables is still a comparison, and it writes Compare Values.
const SOMETHING_ELSE := "__something_else__"

var _dock: Control = null
var _dialog: ConfirmationDialog = null
var _owner_label: Label = null
var _left_option: OptionButton = null
var _left_edit: LineEdit = null
var _left_row: Control = null
var _operator_option: OptionButton = null
var _right_edit: LineEdit = null
var _right_row: Control = null
var _second_edit: LineEdit = null
var _second_row: Control = null
var _tolerance_edit: LineEdit = null
var _tolerance_row: Control = null
var _ignore_case_check: CheckBox = null
var _invert_check: CheckBox = null
## P0/P4 - the ONE help strip at the foot: what the focused field is for, then the row this dialog
## will write and the line it compiles to.
var _help_strip: EventSheetPopupUI.HelpStrip = null
var _context: Dictionary = {}
## The kind the operator list is currently built for, so it is only rebuilt when the answer changes.
var _operator_kind: String = ""
## The variables this sheet can name, read once when the dialog opens. The catalog every other
## surface reads, so the list here and the row it writes agree about what a variable is called.
var _variables: Array[Dictionary] = []
## The kind an EDITED row arrived as, which outranks what its left side looks like: a text condition
## on a typed expression (`save.get("name") begins with "a"`) is a text question however the
## expression is spelled, and rebuilding the list from the literal would throw the operator away.
## Cleared the moment the reader changes the left side, because then the row is theirs again.
var _row_kind: String = ""
## Item index -> the GDScript shape that operator writes, shown muted beside the list. Kept beside
## the dropdown rather than in item metadata, which already carries the operator key the row stores.
var _operator_codes: Dictionary = {}


func init(dock: Control) -> void:
	_dock = dock


# ── The mapping table (the whole feature, and the part a test pins) ──────────────────────────


## The six comparison operators plus the three ranges, as the dialog's list. Reads the ONE labeled
## comparison list every operator picker in the plugin resolves to, so a wording change there lands
## here too; the ranges follow behind a separator because they ask a different shape of question.
static func number_operators() -> Array:
	var entries: Array = []
	for option: Dictionary in EventForgeACEFactory.COMPARISON_OPTIONS:
		entries.append({"key": str(option["key"]), "label": str(option["label"]),
			"code": str(option["key"]), "fields": FIELDS_ONE})
	entries.append({"separator": EventSheetL10n.translate("ranges")})
	entries.append({"key": OPERATOR_BETWEEN, "label": EventSheetL10n.translate("between   two values"),
		"code": "a <= x and x <= b", "fields": FIELDS_TWO})
	entries.append({"key": OPERATOR_NOT_BETWEEN, "label": EventSheetL10n.translate("not between"),
		"code": "x < a or x > b", "fields": FIELDS_TWO})
	entries.append({"key": OPERATOR_WITHIN, "label": EventSheetL10n.translate("within ±   of a value"),
		"code": "absf(x - v) <= t", "fields": FIELDS_TOLERANCE})
	return entries


## The text operators - the same eight questions the Text folder asks as separate verbs, in the order
## a reader would try them. "Ignore case" is not among them: it is a tick, because it qualifies the
## question rather than being one.
static func text_operators() -> Array:
	return [
		{"key": OPERATOR_IS, "label": EventSheetL10n.translate("is"), "code": "==", "fields": FIELDS_ONE},
		{"key": OPERATOR_IS_NOT, "label": EventSheetL10n.translate("is not"), "code": "!=", "fields": FIELDS_ONE},
		{"key": OPERATOR_BEGINS_WITH, "label": EventSheetL10n.translate("begins with"),
			"code": ".begins_with()", "fields": FIELDS_ONE},
		{"key": OPERATOR_ENDS_WITH, "label": EventSheetL10n.translate("ends with"),
			"code": ".ends_with()", "fields": FIELDS_ONE},
		{"key": OPERATOR_CONTAINS, "label": EventSheetL10n.translate("contains"),
			"code": ".contains()", "fields": FIELDS_ONE},
		{"key": OPERATOR_IS_ONE_OF, "label": EventSheetL10n.translate("is one of   a list"),
			"code": "in [...]", "fields": FIELDS_ONE},
		{"key": OPERATOR_MATCHES, "label": EventSheetL10n.translate("matches   a pattern"),
			"code": ".match()", "fields": FIELDS_ONE},
		{"key": OPERATOR_IS_EMPTY, "label": EventSheetL10n.translate("is empty"),
			"code": ".is_empty()", "fields": FIELDS_NONE}
	]


## The operator list for a left-hand side of this kind.
static func operators_for(left_kind: String) -> Array:
	return text_operators() if left_kind == KIND_TEXT else number_operators()


## How many value fields an operator asks for. FIELDS_ONE for anything not listed, because one value
## is what a comparison takes.
static func fields_for(left_kind: String, operator: String) -> String:
	for entry: Variant in operators_for(left_kind):
		var option: Dictionary = entry
		if str(option.get("key", "")) == operator:
			return str(option.get("fields", FIELDS_ONE))
	return FIELDS_ONE


## THE mapping: three boxes in, one existing ACE out. `on_variable` is true when the left side was
## picked from the sheet's own variables (which is what Compare variable is for) rather than typed.
## Returns {"ace_id", "params", "negated"} - `negated` is the inversion the MAPPING itself needs
## ("is not", ignoring case, has no ACE of its own and is the ignore-case equality inverted); the
## dialog's own Invert tick is combined with it, never overwritten by it.
static func writes(left_kind: String, operator: String, on_variable: bool, left: String,
		right: String, second: String, tolerance: String, ignore_case: bool) -> Dictionary:
	match operator:
		OPERATOR_BETWEEN:
			return _wrote(ACE_IS_BETWEEN, {"value": left, "min": right, "max": second})
		OPERATOR_NOT_BETWEEN:
			return _wrote(ACE_IS_OUTSIDE_RANGE, {"value": left, "min": right, "max": second})
		OPERATOR_WITHIN:
			return _wrote(ACE_VALUES_ARE_NEAR, {"a": left, "b": right, "tolerance": tolerance})
		OPERATOR_IS:
			if ignore_case:
				return _wrote(ACE_TEXT_EQUALS_IGNORE_CASE, {"a": left, "b": right})
			return _wrote_comparison(on_variable, left, "==", right)
		OPERATOR_IS_NOT:
			if ignore_case:
				return _wrote(ACE_TEXT_EQUALS_IGNORE_CASE, {"a": left, "b": right}, true)
			return _wrote_comparison(on_variable, left, "!=", right)
		OPERATOR_BEGINS_WITH:
			return _wrote(ACE_TEXT_BEGINS_WITH,
				{"text": _cased(left, ignore_case), "prefix": _cased(right, ignore_case)})
		OPERATOR_ENDS_WITH:
			return _wrote(ACE_TEXT_ENDS_WITH,
				{"text": _cased(left, ignore_case), "suffix": _cased(right, ignore_case)})
		OPERATOR_CONTAINS:
			return _wrote(ACE_TEXT_CONTAINS,
				{"text": _cased(left, ignore_case), "needle": _cased(right, ignore_case)})
		OPERATOR_IS_ONE_OF:
			return _wrote(ACE_TEXT_IS_ONE_OF, {"text": left, "options": right})
		OPERATOR_MATCHES:
			return _wrote(ACE_TEXT_MATCHES, {"text": left, "pattern": right})
		OPERATOR_IS_EMPTY:
			return _wrote(ACE_TEXT_IS_EMPTY, {"text": left})
	# Anything left is one of the six operators, which is the plain comparison the sheet started with.
	return _wrote_comparison(on_variable, left, operator, right)


static func _wrote(ace_id: String, params: Dictionary, negated: bool = false) -> Dictionary:
	return {"ace_id": ace_id, "params": params, "negated": negated}


## Compare variable when the left side IS one of the sheet's variables, Compare Values otherwise:
## the two conditions differ only in whether the left side is a name the sheet knows.
static func _wrote_comparison(on_variable: bool, left: String, operator: String, right: String) -> Dictionary:
	if on_variable:
		return _wrote(ACE_COMPARE_VAR, {"var_name": left, "op": operator, "value": right})
	return _wrote(ACE_COMPARE_VALUES, {"a": left, "op": operator, "b": right})


## `.to_lower()` on a side when the case is to be ignored - which is exactly what a hand-written
## sheet does, and what the ignore-case equality condition already emits for both of its sides.
static func _cased(value: String, ignore_case: bool) -> String:
	return "%s.to_lower()" % value if ignore_case and not value.strip_edges().is_empty() else value


# ── What the help strip shows ────────────────────────────────────────────────────────────────


## READS AS: the row this dialog will write, in the condition's own sentence with the row's operator
## glyphs. An inverted comparison with a clean opposite shows the opposite (K4), because that is both
## what the row will say and what the compiler will write; anything else leads with "not".
static func reads_as(ace_id: String, params: Dictionary, negated: bool, owner: String = "") -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(PROVIDER, ace_id)
	if descriptor == null:
		return ""
	var shown: Dictionary = params
	var leads_with_not: bool = negated
	if negated:
		var flipped: Dictionary = EventForgeACEFactory.flipped_comparison_params(descriptor.codegen_template, params)
		if not flipped.is_empty():
			shown = flipped
			leads_with_not = false
	var text: String = descriptor.get_display_text()
	for key: Variant in shown.keys():
		text = text.replace("{%s}" % str(key), EventForgeACEFactory.comparison_glyph(str(shown[key])))
	if leads_with_not:
		text = "%s %s" % [EventSheetL10n.translate("not"), text]
	return text if owner.strip_edges().is_empty() else "%s   %s" % [owner, text]


## IN CODE: the line the compiler will write for this row - produced BY the compiler, from a
## throwaway condition, so the dialog cannot promise a spelling the emitter would not use.
static func in_code(ace_id: String, params: Dictionary, negated: bool) -> String:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = PROVIDER
	condition.ace_id = ace_id
	condition.params = params
	condition.negated = negated
	var expression: String = ConditionCodegen.generate_condition(condition)
	return "" if expression.strip_edges().is_empty() else "if %s:" % expression


# ── Reading a row back into the three boxes ──────────────────────────────────────────────────


## The three boxes an existing row opens with: which ACE it is, read back as an operator and its
## values. {} for a row this dialog cannot represent, which is how the dock knows to fall back to the
## ordinary parameters dialog rather than silently rewriting a row it misread.
static func boxes_for(ace_id: String, params: Dictionary, negated: bool) -> Dictionary:
	var ignore_case: bool = false
	var left: String = ""
	var right: String = ""
	var second: String = ""
	var tolerance: String = ""
	var operator: String = ""
	var kind: String = KIND_NUMBER
	var on_variable: bool = false
	match ace_id:
		ACE_COMPARE_VAR:
			left = str(params.get("var_name", ""))
			operator = str(params.get("op", "=="))
			right = str(params.get("value", ""))
			on_variable = true
		ACE_COMPARE_VALUES:
			left = str(params.get("a", ""))
			operator = str(params.get("op", "=="))
			right = str(params.get("b", ""))
		ACE_IS_BETWEEN, ACE_IS_OUTSIDE_RANGE:
			left = str(params.get("value", ""))
			operator = OPERATOR_BETWEEN if ace_id == ACE_IS_BETWEEN else OPERATOR_NOT_BETWEEN
			right = str(params.get("min", ""))
			second = str(params.get("max", ""))
		ACE_VALUES_ARE_NEAR:
			left = str(params.get("a", ""))
			operator = OPERATOR_WITHIN
			right = str(params.get("b", ""))
			tolerance = str(params.get("tolerance", ""))
		ACE_TEXT_EQUALS_IGNORE_CASE:
			left = str(params.get("a", ""))
			right = str(params.get("b", ""))
			operator = OPERATOR_IS_NOT if negated else OPERATOR_IS
			ignore_case = true
			kind = KIND_TEXT
		ACE_TEXT_BEGINS_WITH, ACE_TEXT_ENDS_WITH, ACE_TEXT_CONTAINS:
			left = str(params.get("text", ""))
			right = str(params.get("prefix", params.get("suffix", params.get("needle", ""))))
			operator = OPERATOR_BEGINS_WITH
			if ace_id == ACE_TEXT_ENDS_WITH:
				operator = OPERATOR_ENDS_WITH
			elif ace_id == ACE_TEXT_CONTAINS:
				operator = OPERATOR_CONTAINS
			ignore_case = left.ends_with(".to_lower()")
			if ignore_case:
				left = left.trim_suffix(".to_lower()")
				right = right.trim_suffix(".to_lower()")
			kind = KIND_TEXT
		ACE_TEXT_IS_ONE_OF:
			left = str(params.get("text", ""))
			right = str(params.get("options", ""))
			operator = OPERATOR_IS_ONE_OF
			kind = KIND_TEXT
		ACE_TEXT_MATCHES:
			left = str(params.get("text", ""))
			right = str(params.get("pattern", ""))
			operator = OPERATOR_MATCHES
			kind = KIND_TEXT
		ACE_TEXT_IS_EMPTY:
			left = str(params.get("text", ""))
			operator = OPERATOR_IS_EMPTY
			kind = KIND_TEXT
		_:
			return {}
	# An ignore-case "is not" IS the inversion, so the tick must not show it a second time.
	var tick: bool = negated and ace_id != ACE_TEXT_EQUALS_IGNORE_CASE
	return {"kind": kind, "operator": operator, "on_variable": on_variable, "left": left,
		"right": right, "second": second, "tolerance": tolerance, "ignore_case": ignore_case,
		"negated": tick}


## What the left side of a comparison is, from the variable's declared type when it has one and from
## the literal itself when it does not: quoted text is text, and everything else is asked with the
## number list (which is also the right list for a bare expression - the six operators fit anything
## that can be ordered or equalled).
static func kind_of(type_name: String, literal: String) -> String:
	if type_name == "String" or type_name == "StringName":
		return KIND_TEXT
	if not type_name.strip_edges().is_empty():
		return KIND_NUMBER
	var text: String = literal.strip_edges()
	var quoted: bool = text.length() >= 2 and (
		(text.begins_with("\"") and text.ends_with("\"")) or (text.begins_with("'") and text.ends_with("'")))
	return KIND_TEXT if quoted else KIND_NUMBER


## One line of the variable list: the name, its type in the sheet's own word, and what it starts at.
## Reads the catalog entry as it stands - the type word is the one the row leads with, so the list
## and the row it will write cannot spell a variable two ways.
static func variable_label(entry: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray([str(entry.get("name", ""))])
	for key: String in ["type_word", "value"]:
		var text: String = str(entry.get(key, "")).strip_edges()
		if not text.is_empty():
			parts.append(text)
	return "   ·   ".join(parts)


# ── The dialog ───────────────────────────────────────────────────────────────────────────────


## Opens the dialog for a row that does not exist yet (`ace_id` empty) or for one being edited.
## `context` is the ACE apply context and is handed straight back on confirm.
func open(context: Dictionary, ace_id: String = "", params: Dictionary = {}, negated: bool = false) -> void:
	_ensure_dialog()
	_context = context.duplicate(true)
	# THE variable list every surface reads, taken once per open: a variable added since the last
	# comparison must be offered, and re-deriving it on every keystroke would walk the project.
	_variables = EventSheetVariableOwners.catalog(_sheet())
	var boxes: Dictionary = boxes_for(ace_id, params, negated) if not ace_id.is_empty() else {}
	_row_kind = str(boxes.get("kind", ""))
	_fill_left_options(str(boxes.get("left", "")), bool(boxes.get("on_variable", false)))
	_rebuild_operators(_left_kind(), str(boxes.get("operator", "")))
	_right_edit.text = str(boxes.get("right", ""))
	_second_edit.text = str(boxes.get("second", ""))
	_tolerance_edit.text = str(boxes.get("tolerance", "0.01"))
	_ignore_case_check.button_pressed = bool(boxes.get("ignore_case", false))
	_invert_check.button_pressed = bool(boxes.get("negated", false))
	_owner_label.text = _owner_text()
	_dialog.title = EventSheetL10n.translate("Compare")
	_refresh()
	_dialog.popup_centered(Vector2i(int(EventSheetPalette.scaled_f(560.0)), int(EventSheetPalette.scaled_f(420.0))))


func _ensure_dialog() -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Compare"
	_dialog.ok_button_text = "OK"
	_dialog.visible = false
	_dialog.confirmed.connect(_on_confirmed)
	_dock.add_child(_dialog)

	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_dialog.add_child(EventSheetPopupUI.margined(form))

	# Whose comparison this is, said once at the top - the same "to Player" line the Add variable
	# dialog leads with, because a row belongs to an object before it belongs to a condition.
	_owner_label = EventSheetPopupUI.hint_label("")
	form.add_child(_owner_label)

	# WHAT. The sheet's own variables, each with its type word and what it starts at, and a free-text
	# entry for everything else - which is the difference between Compare variable and Compare Values.
	_left_option = OptionButton.new()
	_left_option.clip_text = true
	_left_option.item_selected.connect(func(_index: int) -> void:
		_row_kind = ""
		_refresh())
	form.add_child(EventSheetPopupUI.form_row("Compare", _left_option))
	_left_edit = LineEdit.new()
	_left_edit.placeholder_text = "score + 1"
	_left_edit.text_changed.connect(func(_text: String) -> void:
		_row_kind = ""
		_refresh())
	_left_row = EventSheetPopupUI.form_row("", _left_edit)
	form.add_child(_left_row)

	# HOW. The operator list, whose choice decides which of the existing conditions this row becomes.
	_operator_option = OptionButton.new()
	_operator_option.item_selected.connect(func(_index: int) -> void: _refresh())
	# The list is filled when the dialog opens, so the muted code note has to be told where to read
	# from rather than sniffing an empty dropdown for one.
	var operator_code: Callable = func(index: int) -> String:
		return str(_operator_codes.get(index, ""))
	form.add_child(EventSheetPopupUI.form_row("Is",
		EventSheetPopupUI.code_noted_option(_operator_option, operator_code)))

	# TO WHAT. One value, two of them for a range, or a value and a tolerance.
	_right_edit = LineEdit.new()
	_right_edit.text_changed.connect(func(_text: String) -> void: _refresh())
	_right_row = EventSheetPopupUI.form_row("To", _right_edit)
	form.add_child(_right_row)
	_second_edit = LineEdit.new()
	_second_edit.text_changed.connect(func(_text: String) -> void: _refresh())
	_second_row = EventSheetPopupUI.form_row("And", _second_edit)
	form.add_child(_second_row)
	_tolerance_edit = LineEdit.new()
	_tolerance_edit.text_changed.connect(func(_text: String) -> void: _refresh())
	_tolerance_row = EventSheetPopupUI.form_row("Give or take", _tolerance_edit)
	form.add_child(_tolerance_row)

	_ignore_case_check = CheckBox.new()
	_ignore_case_check.text = "Ignore case"
	_ignore_case_check.toggled.connect(func(_on: bool) -> void: _refresh())
	form.add_child(_ignore_case_check)
	_invert_check = CheckBox.new()
	_invert_check.text = "Invert - true when it is NOT the case"
	_invert_check.toggled.connect(func(_on: bool) -> void: _refresh())
	form.add_child(_invert_check)

	_help_strip = EventSheetPopupUI.help_strip("Compare",
		"Pick what to compare, how, and to what. The row you get is whichever condition matches - the ids and the code are the sheet's own.")
	form.add_child(_help_strip)
	_help_strip.follow(_left_option, "Compare",
		"The left side of the question. Pick one of this sheet's variables, or choose the last entry to type any expression - then the row is a plain value comparison.")
	_help_strip.follow(_left_edit, "Compare",
		"Any expression: a property, a call, arithmetic. Typed values compare as values, so this writes Compare Values rather than Compare variable.")
	_help_strip.follow(_operator_option, "Is",
		"How the two sides are compared. The ranges at the foot ask for two values, or for a value and how far off it may be.")
	_help_strip.follow(_right_edit, "To",
		"What to compare against - a number, a piece of text in quotes, or another expression.")
	_help_strip.follow(_second_edit, "And",
		"The other end of the range. Both ends count as inside it.")
	_help_strip.follow(_tolerance_edit, "Give or take",
		"How far apart the two values may be and still count as equal. Decimal numbers almost never land exactly equal, which is what this is for.")
	_help_strip.follow(_ignore_case_check, "Ignore case",
		"Treat capitals and lowercase as the same. It writes to_lower() on both sides, which is what a hand-written check does.")
	_help_strip.follow(_invert_check, "Invert",
		"True when the question is NOT. A comparison with a clean opposite simply shows the opposite instead - hp > 0 rather than not (hp <= 0).")


## The variable list, rebuilt from the sheet each time the dialog opens (a variable added since the
## last comparison must be offered). `selected_name` re-selects the row being edited.
func _fill_left_options(selected_name: String, on_variable: bool) -> void:
	_left_option.clear()
	for entry: Dictionary in _variables:
		_left_option.add_item(variable_label(entry))
		# The INSERT text, not the bare name: inside a comparison a global's `Game.` prefix is real
		# code, and the row would not compile without it.
		_left_option.set_item_metadata(_left_option.item_count - 1,
			str(entry.get("insert_text", entry.get("name", ""))))
	_left_option.add_separator()
	_left_option.add_item(EventSheetL10n.translate("Something else…"))
	_left_option.set_item_metadata(_left_option.item_count - 1, SOMETHING_ELSE)
	var chosen: int = -1
	if on_variable and not selected_name.is_empty():
		for index: int in range(_left_option.item_count):
			if str(_left_option.get_item_metadata(index)) == selected_name:
				chosen = index
				break
	_left_option.select(chosen if chosen >= 0 else _left_option.item_count - 1)
	_left_edit.text = "" if chosen >= 0 else selected_name


## The operator list for the current left side. Rebuilt only when the KIND changes, so arrowing
## through values never resets the operator under the cursor.
func _rebuild_operators(kind: String, selected: String) -> void:
	if kind == _operator_kind and selected.is_empty():
		return
	_operator_kind = kind
	_operator_option.clear()
	_operator_codes.clear()
	for entry: Variant in operators_for(kind):
		var option: Dictionary = entry
		if option.has("separator"):
			_operator_option.add_separator(str(option["separator"]))
			continue
		_operator_option.add_item(str(option["label"]))
		var index: int = _operator_option.item_count - 1
		_operator_option.set_item_metadata(index, str(option["key"]))
		_operator_codes[index] = str(option["code"])
	var chosen: int = -1
	for index: int in range(_operator_option.item_count):
		if str(_operator_option.get_item_metadata(index)) == selected:
			chosen = index
			break
	_operator_option.select(chosen if chosen >= 0 else 0)
	var note: Variant = _operator_option.get_meta("code_note", null)
	if note is Label:
		(note as Label).text = str(_operator_codes.get(_operator_option.selected, ""))


## Which fields the chosen operator needs, and what the row will read and compile to. One function,
## because every widget in the dialog changes the same two answers.
func _refresh() -> void:
	var free_text: bool = _selected_variable().is_empty()
	_left_row.visible = free_text
	_rebuild_operators(_left_kind(), "")
	var operator: String = _selected_operator()
	var fields: String = fields_for(_operator_kind, operator)
	_right_row.visible = fields != FIELDS_NONE
	_second_row.visible = fields == FIELDS_TWO
	_tolerance_row.visible = fields == FIELDS_TOLERANCE
	_ignore_case_check.visible = _operator_kind == KIND_TEXT and operator != OPERATOR_IS_EMPTY
	var written: Dictionary = _written()
	_help_strip.set_reading(
		reads_as(str(written["ace_id"]), written["params"], bool(written["negated"]), _owner_name()),
		in_code(str(written["ace_id"]), written["params"], bool(written["negated"])))


## The row this dialog would write right now.
func _written() -> Dictionary:
	var variable: String = _selected_variable()
	var left: String = variable if not variable.is_empty() else _left_edit.text.strip_edges()
	var written: Dictionary = writes(_operator_kind, _selected_operator(), not variable.is_empty(), left,
		_right_edit.text.strip_edges(), _second_edit.text.strip_edges(),
		_tolerance_edit.text.strip_edges(), _ignore_case_check.visible and _ignore_case_check.button_pressed)
	# The dialog's own tick and the inversion the mapping needed are the same fact asked twice: an
	# ignore-case "is not" is already inverted, and ticking Invert on top of it asks for the "is".
	written["negated"] = bool(written["negated"]) != _invert_check.button_pressed
	return written


func _selected_variable() -> String:
	if _left_option == null or _left_option.selected < 0:
		return ""
	var metadata: String = str(_left_option.get_item_metadata(_left_option.selected))
	return "" if metadata == SOMETHING_ELSE else metadata


func _selected_operator() -> String:
	if _operator_option == null or _operator_option.selected < 0:
		return "=="
	return str(_operator_option.get_item_metadata(_operator_option.selected))


## What the left side IS: the chosen variable's declared type, or the literal typed in its place.
func _left_kind() -> String:
	if not _row_kind.is_empty():
		return _row_kind
	var variable: String = _selected_variable()
	if variable.is_empty():
		return kind_of("", _left_edit.text if _left_edit != null else "")
	var found: Dictionary = EventSheetVariableOwners.find(_variables, variable)
	return KIND_NUMBER if found.is_empty() else kind_of(str(found.get("type_name", "")), "")


func _sheet() -> EventSheetResource:
	return _dock._current_sheet if _dock != null else null


## The object this comparison belongs to - the same owner the row's object column will say, asked of
## the one place that answers it.
func _owner_name() -> String:
	return EventSheetVariableOwners.owner_of_sheet(_sheet())


func _owner_text() -> String:
	var owner: String = _owner_name()
	return "" if owner.is_empty() else EventSheetL10n.translate("on {object}").replace("{object}", owner)


func _on_confirmed() -> void:
	var written: Dictionary = _written()
	compare_confirmed.emit(str(written["ace_id"]), written["params"], bool(written["negated"]), _context)
