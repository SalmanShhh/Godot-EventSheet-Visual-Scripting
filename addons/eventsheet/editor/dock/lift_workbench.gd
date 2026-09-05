@tool
class_name EventSheetLiftWorkbench
extends RefCounted
# Lift Workbench (Tools menu) - the bench a recogniser is written on.
#
# Writing a lift family is a loop: paste a line somebody really wrote, find out whether anything
# claims it, look at the rows it opens as, and check that saving writes the same bytes back. Until
# now that loop was a throwaway fixture, a test run and a diff by hand, once per spelling. This is
# the same loop in one window, on a buffer, with the answer arriving as you type.
#
# THREE ANSWERS PER BUFFER, all of them from EventSheetLiftReading so this window can never tell a
# developer something the corpus gate and the head bar's chip would not:
#
#   WHAT CLAIMS IT   per line: the family and entry id that recognised it, the plainer name of the
#                    row it otherwise arrived as, or "stays code" - and those three read differently
#                    on purpose, because a named entry and a general reading are not the same claim.
#   WHAT IT OPENS AS the real rows, drawn by the real viewport. Not a mock-up of the canvas: the
#                    canvas, read-only, on the sheet the buffer imported to.
#   WHAT IT SAVES AS the re-emission, byte for byte. Green when the buffer comes back unchanged, and
#                    red with the exact two lines when it does not - because a trailing space is the
#                    whole bug and "they differ" is not a bug report.
#
# DRAFTS LAST AS LONG AS THE PANEL DOES. A draft is asked before every shipped spelling, so one
# over-wide draft claims lines all over the window - which is why the drafts are listed where they
# are made, with a plain button that clears them. They are held in this object and nowhere else:
# no file is written for them, so closing the panel is itself the way out of a draft that claims too
# much, and a line can never read as somebody's draft from three sessions ago.
#
# THE BUFFER IS THE WHOLE SCOPE. The refresh is debounced rather than per keystroke, and it imports
# and compiles exactly what is in the box - never the project. That is what keeps a developer tool
# free to be open all day.
#
# NOTHING UNDER res:// IS TOUCHED, and that is the promise worth stating exactly. Every reading does
# compile: the compiler writes what it emits, and a reading that let it default would save each
# measured buffer back over the file it came from. So a reading always compiles to one throwaway path
# under user:// (EventSheetLiftReading.THROWAWAY_PATH), which is rewritten on every debounced refresh
# and belongs to nobody. The project's own files are opened for reading and never for writing.
#
# DRAFT AN EXAMPLE takes an unclaimed line to the by-example form (EventForgeLiftExample): mark the
# value spans, get the derived entry back, and add it to the drafts this window is holding. Drafts
# are asked first on every refresh, so a draft claims lines in this window immediately and is marked
# "draft" while it does - it is never mistaken for a shipped spelling, and nothing under res:// is
# touched. Moving a draft into a real family is a copy and paste of the entry the form shows, which
# is the point: the form does the mechanical half, a person still decides the spelling is worth
# shipping.

## How long the buffer has to go quiet before the reading runs. Long enough that typing a line never
## starts a compile, short enough that stopping to look already has the answer waiting.
const REFRESH_DELAY: float = 0.35

## The buffer a freshly opened workbench starts on: one line each of the three answers, so the window
## explains itself before anything is typed into it.
const STARTER_BUFFER: String = """extends Node

var lives: int = 3


func _ready() -> void:
	rpc("player_joined", name)
	lives = 3
	var timer: Timer = Timer.new()
	timer.timeout.connect(func() -> void:
		lives -= 1
	)
	add_child(timer)
"""

var _dock: Control = null
var _window: Window = null
var _buffer: CodeEdit = null
var _claims: Tree = null
var _diff: RichTextLabel = null
var _tally: Label = null
var _preview: EventSheetViewport = null
var _draft_button: Button = null
var _timer: Timer = null
var _draft_window: Window = null
var _draft_example: CodeEdit = null
var _draft_id: LineEdit = null
var _draft_ace: LineEdit = null
var _draft_result: RichTextLabel = null
var _drafts_list: RichTextLabel = null
var _drafts: Array = []


func init(dock: Control) -> void:
	_dock = dock


func open() -> void:
	if _window == null:
		build_window()
	refresh()
	_window.popup_centered(Vector2i(1080, 720))


# ── the reading ─────────────────────────────────────────────────────────────────


## The whole answer for whatever is in the buffer right now. Public because the suite drives it
## headless through `reading_for`, which is the same call without the widgets.
func refresh() -> void:
	if _buffer == null:
		return
	var reading: Dictionary = reading_for(_buffer.text)
	_fill_claims(reading)
	_fill_diff(reading)
	_fill_preview(reading)


## The reading of one buffer, with this window's drafts asked first. The one place the panel's
## answers come from - so a test can pin exactly what a developer would be shown.
func reading_for(source: String) -> Dictionary:
	return EventSheetLiftReading.read(source, "", draft_entries())


## What this panel is holding right now, one line per draft - the ids and the examples, in the order
## they were added. A draft is asked FIRST on every refresh, so drafts nobody can see are claims
## with no visible cause. Said here, beside the button that clears them.
func drafts_summary() -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	for draft: Variant in _drafts:
		var row: Dictionary = draft
		said.append("%s - %s" % [str(row.get("id", "")), str(row.get("example", ""))])
	return said


## Drops every draft this panel is holding and re-reads the buffer, so each line they were claiming
## goes back to whatever claimed it before. Closing the panel does the same thing, because the drafts
## live in this object and nowhere else.
func clear_drafts() -> void:
	_drafts = []
	EventSheetLiftReading.clear_cache()
	_fill_drafts_list()
	refresh()


func _fill_drafts_list() -> void:
	if _drafts_list == null:
		return
	_drafts_list.clear()
	var said: PackedStringArray = drafts_summary()
	if said.is_empty():
		_drafts_list.add_text(EventSheetL10n.translate("Nothing drafted yet."))
		return
	for line: String in said:
		_drafts_list.add_text(line)
		_drafts_list.newline()


## The drafts as lift-table entries. A draft that cannot be derived comes back carrying its
## refusal (the example engine never guesses), and an entry carrying a refusal matches nothing - so a
## broken draft is inert here exactly as it would be in a shipped family.
func draft_entries() -> Array:
	var entries: Array = []
	for draft: Variant in _drafts:
		var row: Dictionary = draft
		entries.append(EventForgeLiftExample.entry(str(row.get("id", "")), str(row.get("ace_id", "")),
			str(row.get("example", ""))))
	return entries


# ── the three panes ─────────────────────────────────────────────────────────────


func _fill_claims(reading: Dictionary) -> void:
	if _claims == null:
		return
	_claims.clear()
	var root: TreeItem = _claims.create_item()
	for line: Variant in reading.get("lines", []) as Array:
		var entry: Dictionary = line
		if str(entry.get("layer", "")) == EventSheetLiftReading.LAYER_QUIET:
			continue
		var item: TreeItem = _claims.create_item(root)
		item.set_text(0, str(entry.get("number", 0)))
		item.set_text(1, str(entry.get("text", "")).strip_edges())
		item.set_text(2, str(entry.get("claim", "")))
		item.set_metadata(0, entry)
		# The two layers are told apart by weight and colour, not by wording alone: a named entry is
		# the strong claim, the general reading is plainer, and unclaimed code is the muted one a
		# reader is meant to go and look at.
		var layer: String = str(entry.get("layer", ""))
		if layer == EventSheetLiftReading.LAYER_ENTRY:
			item.set_custom_color(2, Color(0.55, 0.85, 0.55))
		elif layer == EventSheetLiftReading.LAYER_CODE:
			item.set_custom_color(2, Color(0.90, 0.72, 0.42))
			item.set_custom_color(1, Color(0.75, 0.75, 0.75))
		else:
			item.set_custom_color(2, Color(0.66, 0.74, 0.86))
	# The door opens on the first line nothing claims, without waiting to be asked: the lines a lift
	# author came here for are exactly the ones nothing claims, and hunting for the first one by hand
	# is a step the window can take for them. A selection they made themselves is never overridden.
	if _claims.get_selected() == null:
		var candidate: TreeItem = root.get_first_child()
		while candidate != null:
			var found: Variant = candidate.get_metadata(0)
			if found is Dictionary and str((found as Dictionary).get("layer", "")) == EventSheetLiftReading.LAYER_CODE:
				candidate.select(0)
				break
			candidate = candidate.get_next()
	var counts: Dictionary = EventSheetLiftReading.layer_counts(reading)
	if _tally != null:
		# TWO DIFFERENT QUESTIONS, said apart so the strip cannot read as a contradiction. The first
		# two numbers are about NAMING - did any vocabulary claim this line. The percentage is about
		# DRAWING - how much of the file the canvas shows as rows rather than as a wall of code, which
		# is the number the head bar's chip shows and the number the corpus gate pins. A file can draw
		# entirely as rows and still have lines no vocabulary names; both facts are true at once.
		_tally.text = EventSheetL10n.translate("%d claimed by an entry · %d nothing claims · %d%% renders as rows rather than blocks") \
			% [int(counts.get(EventSheetLiftReading.LAYER_ENTRY, 0)),
			int(counts.get(EventSheetLiftReading.LAYER_CODE, 0)), EventSheetLiftReading.percent(reading)]
	_update_draft_button()


func _fill_diff(reading: Dictionary) -> void:
	if _diff == null:
		return
	_diff.clear()
	if bool(reading.get("identical", false)):
		_diff.push_color(Color(0.45, 0.82, 0.45))
		_diff.add_text(EventSheetL10n.translate("Saves back byte-identical."))
		_diff.pop()
		return
	var difference: Dictionary = reading.get("diff", {}) as Dictionary
	_diff.push_color(Color(0.92, 0.45, 0.45))
	_diff.add_text(EventSheetL10n.translate("Line %d comes back different.") % int(difference.get("line", 0)))
	_diff.pop()
	_diff.newline()
	_diff.add_text("%s: %s" % [EventSheetL10n.translate("buffer"), str(difference.get("expected", ""))])
	_diff.newline()
	_diff.add_text("%s: %s" % [EventSheetL10n.translate("saved"), str(difference.get("got", ""))])


func _fill_preview(reading: Dictionary) -> void:
	if _preview == null:
		return
	var sheet: EventSheetResource = reading.get("sheet", null) as EventSheetResource
	if sheet == null:
		return
	sheet.read_only = true
	if sheet.editor_style == null:
		var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
		style.ensure_defaults()
		sheet.editor_style = style
	_preview.set_sheet(sheet)


# ── the draft door ──────────────────────────────────────────────────────────────


## The door is only ever open on a line nothing claims. An entry drafted for a line that already
## lifts is a second spelling of a row that already exists, which is the one thing this window
## should not make easy.
func _update_draft_button() -> void:
	if _draft_button == null:
		return
	_draft_button.disabled = _selected_unclaimed_line().is_empty()


func _selected_unclaimed_line() -> String:
	if _claims == null:
		return ""
	var item: TreeItem = _claims.get_selected()
	if item == null:
		return ""
	var entry: Variant = item.get_metadata(0)
	if not (entry is Dictionary):
		return ""
	if str((entry as Dictionary).get("layer", "")) != EventSheetLiftReading.LAYER_CODE:
		return ""
	return str((entry as Dictionary).get("text", "")).strip_edges()


func _open_draft_form() -> void:
	var line: String = _selected_unclaimed_line()
	if line.is_empty():
		return
	if _draft_window == null:
		_build_draft_window()
	_draft_example.text = line
	_draft_id.text = _suggested_id(line)
	_draft_ace.text = ""
	_draft_result.clear()
	_draft_result.add_text(EventSheetL10n.translate("Mark each value span as [[name: text]], then check it."))
	_fill_drafts_list()
	_draft_window.popup_centered(Vector2i(780, 700))


## An id suggested from the line's own words - the identifiers in it, joined, lowercased. A
## suggestion only: it is an editable field, and the author renames it to whatever the family calls
## this spelling.
func _suggested_id(line: String) -> String:
	var words: PackedStringArray = PackedStringArray()
	var regex: RegEx = RegEx.create_from_string("[A-Za-z_][A-Za-z0-9_]*")
	for hit: RegExMatch in regex.search_all(line):
		words.append(hit.get_string().to_snake_case())
		if words.size() >= 3:
			break
	return "_".join(words)


## What the example engine makes of the marked line, shown before anything is stored: the derived
## pattern and shape, or the refusal sentence naming what it could not answer mechanically.
func _check_draft() -> Dictionary:
	var derived: Dictionary = EventForgeLiftExample.entry(_draft_id.text.strip_edges(),
		_draft_ace.text.strip_edges(), _draft_example.text)
	_draft_result.clear()
	if derived.has(EventForgeLiftTable.REFUSAL_KEY):
		_draft_result.push_color(Color(0.92, 0.45, 0.45))
		_draft_result.add_text(EventSheetL10n.translate("Refused: %s")
			% str(derived[EventForgeLiftTable.REFUSAL_KEY]))
		_draft_result.pop()
		return derived
	_draft_result.push_color(Color(0.45, 0.82, 0.45))
	_draft_result.add_text(EventSheetL10n.translate("This example derives an entry."))
	_draft_result.pop()
	_draft_result.newline()
	_draft_result.add_text("\"pattern\": \"%s\"" % str(derived.get("pattern", "")))
	_draft_result.newline()
	_draft_result.add_text("\"shape\": \"%s\"" % str(derived.get("shape", "")))
	_draft_result.newline()
	_draft_result.add_text("\"slots\": %s" % str(derived.get("slots", {})))
	return derived


## Adds the draft to the ones this panel is holding and re-reads the buffer, so the line it was
## drafted from changes its claim in front of the author. A refused example is not stored.
func _append_draft() -> void:
	var derived: Dictionary = _check_draft()
	if derived.has(EventForgeLiftTable.REFUSAL_KEY):
		return
	_drafts.append({"id": _draft_id.text.strip_edges(), "ace_id": _draft_ace.text.strip_edges(),
		"example": _draft_example.text})
	EventSheetLiftReading.clear_cache()
	_fill_drafts_list()
	refresh()


# ── window construction ─────────────────────────────────────────────────────────


## Builds the window and returns it. Public because the preview harness parents it into its own host
## rather than into a dock, and because a window built by hand is the only way to photograph one.
func build_window() -> Window:
	_window = Window.new()
	_window.title = EventSheetL10n.translate("Lift Workbench - what claims each line")
	_window.close_requested.connect(func() -> void: _window.hide())
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = REFRESH_DELAY
	_timer.timeout.connect(refresh)
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top: HSplitContainer = HSplitContainer.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.split_offset = 420
	top.add_child(_build_buffer_card())
	top.add_child(_build_answers_card())
	body.add_child(top)
	body.add_child(_build_rows_card())
	body.add_child(_build_footer())
	var margined: MarginContainer = EventSheetPopupUI.margined(body)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window.add_child(margined)
	_window.add_child(_timer)
	_buffer.text = STARTER_BUFFER
	if _dock != null:
		_dock.add_child(_window)
	return _window


## Replaces what is in the buffer and reads it at once, skipping the debounce. For a caller that
## already knows what it wants shown - the preview harness, or a test.
func set_buffer(source: String) -> void:
	if _buffer == null:
		build_window()
	_buffer.text = source
	refresh()


func _build_buffer_card() -> Control:
	_buffer = CodeEdit.new()
	_buffer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_buffer.custom_minimum_size = Vector2(380.0, 240.0)
	EventSheetPopupUI.configure_code_editor(_buffer)
	_buffer.text_changed.connect(func() -> void: _timer.start())
	var card: PanelContainer = EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("Paste code here"), _buffer)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return card


func _build_answers_card() -> Control:
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_claims = Tree.new()
	_claims.columns = 3
	_claims.hide_root = true
	_claims.column_titles_visible = true
	_claims.set_column_title(0, EventSheetL10n.translate("Line"))
	_claims.set_column_title(1, EventSheetL10n.translate("Code"))
	_claims.set_column_title(2, EventSheetL10n.translate("Claimed by"))
	_claims.set_column_expand(0, false)
	_claims.set_column_custom_minimum_width(0, 48)
	_claims.custom_minimum_size = Vector2(420.0, 240.0)
	_claims.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_claims.item_selected.connect(_update_draft_button)
	var claims_card: PanelContainer = EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("What claims each line"), _claims)
	claims_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(claims_card)
	_diff = RichTextLabel.new()
	_diff.custom_minimum_size = Vector2(0.0, 76.0)
	_diff.selection_enabled = true
	column.add_child(EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("What it saves back as"), _diff))
	return column


func _build_rows_card() -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 180.0)
	_preview = EventSheetViewport.new()
	_preview.set_ace_registry(_dock._ace_registry if _dock != null else EventSheetACERegistry.new())
	_preview.set_reading_mode(true)
	scroll.add_child(_preview)
	return EventSheetPopupUI.titled_card(EventSheetL10n.translate("The rows it opens as"), scroll)


func _build_footer() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	_tally = Label.new()
	_tally.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_tally)
	_draft_button = Button.new()
	_draft_button.text = EventSheetL10n.translate("Draft an example…")
	_draft_button.tooltip_text = EventSheetL10n.translate("Take the selected unclaimed line to the by-example form and derive an entry from it.")
	_draft_button.disabled = true
	_draft_button.pressed.connect(_open_draft_form)
	row.add_child(_draft_button)
	return row


func _build_draft_window() -> void:
	_draft_window = Window.new()
	_draft_window.title = EventSheetL10n.translate("Draft an example")
	_draft_window.close_requested.connect(func() -> void: _draft_window.hide())
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	_draft_example = CodeEdit.new()
	_draft_example.custom_minimum_size = Vector2(0.0, 72.0)
	EventSheetPopupUI.configure_code_editor(_draft_example)
	body.add_child(EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("The line, with its value spans marked"), _draft_example))
	body.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("A value span is [[name: text]], or [[name|fragment: text]] to say which fragment it is. Everything outside a span is matched literally.")))
	_draft_id = LineEdit.new()
	_draft_ace = LineEdit.new()
	body.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Entry id"), _draft_id))
	body.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Row it means"), _draft_ace))
	_draft_result = RichTextLabel.new()
	_draft_result.custom_minimum_size = Vector2(0.0, 96.0)
	_draft_result.selection_enabled = true
	body.add_child(EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("The entry this derives"), _draft_result))
	# The drafts are a plain list, not a named thing: they are the working state of an open form, and
	# a heading over them would promise something that outlives the window.
	_drafts_list = RichTextLabel.new()
	_drafts_list.custom_minimum_size = Vector2(0.0, 72.0)
	_drafts_list.selection_enabled = true
	body.add_child(_drafts_list)
	body.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("These are asked before every shipped spelling, in this window only. They are gone when it closes, and nothing on disk is written.")))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var clear: Button = Button.new()
	clear.text = EventSheetL10n.translate("Clear drafts")
	clear.tooltip_text = EventSheetL10n.translate("Empties the drafts this window keeps, so every line they were claiming goes back to whatever claimed it before.")
	clear.pressed.connect(clear_drafts)
	buttons.add_child(clear)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var check: Button = Button.new()
	check.text = EventSheetL10n.translate("Check")
	check.pressed.connect(func() -> void: _check_draft())
	buttons.add_child(check)
	var append: Button = Button.new()
	append.text = EventSheetL10n.translate("Add draft")
	append.pressed.connect(_append_draft)
	buttons.add_child(append)
	body.add_child(buttons)
	_draft_window.add_child(EventSheetPopupUI.margined(body))
	if _dock != null:
		_dock.add_child(_draft_window)
