# Godot EventSheets - THE PACK UPDATE, SHOWN BEFORE IT HAPPENS.
#
# Three lists and a button. Everything the update would do is on the page before the button exists to
# be pressed, and nothing on the page is a summary of something the reader cannot see:
#
#   UNTOUCHED   every file that still hashes to what arrived. These take the new version. They are
#               LISTED rather than silently swept, because a reader who never edited a pack still
#               deserves to see the eleven files about to be rewritten under their project.
#   YOURS       every file that differs from what arrived, one answer each - Keep mine (the default,
#               always), Take new, or See the diff, which shows the changed region of the two texts
#               side by side. A pack with no attach record puts EVERY file here: "we do not know" is
#               not "you changed nothing".
#   VOCABULARY  what the new version retires and adds, diffed out of the two versions' registry
#               dumps. A retired verb keeps its id, its template and its place in the picker - it
#               simply gained a forwarding address - so the row beside it opens the migrate dry run
#               rather than asking for anything.
#
# THE OLD VERSION IS BACKED UP FIRST. `EventSheetPackUpdate.apply` copies every file it is about to
# overwrite or remove into the same ring a sheet save uses, before the first write.
#
# ALL THE THINKING IS ELSEWHERE. The plan, the classification and the vocabulary diff are static and
# pure in `EventSheetPackUpdate`, `EventSheetPackManifest` and `EventForgeRegistryDump`, so the suite
# pins the words a reader is shown without opening a window. This file is the shell.
@tool
class_name EventSheetPackUpdateDialog
extends AcceptDialog

## The pack folder being updated, and what is being offered to it.
var _pack_folder: String = ""
var _incoming: Dictionary = {}
var _plan: Dictionary = {}
var _vocabulary: Dictionary = {}
## The catalogue the project would have if this update were taken. What the dry run answers against.
var _vocabulary_after: Dictionary = {}
var _choices: Dictionary = {}
var _version: String = ""

var _summary: Label = null
var _untouched_list: ItemList = null
var _yours_box: VBoxContainer = null
var _yours_card: Control = null
var _vocabulary_list: ItemList = null
var _vocabulary_card: Control = null
var _dry_run_button: Button = null
var _diff_dialog: AcceptDialog = null
var _diff_text: TextEdit = null

## Called with the sentence to show when the update lands, so the manager can rebuild its table and
## the dock can refresh the vocabulary. `_on_dry_run` is called with THE VOCABULARY THIS PROJECT
## WOULD HAVE if the update were taken - the incoming version's verbs over the installed catalogue -
## because that is the only corpus in which the update's own forwarding addresses exist. Answering
## the dry run against the packs the project has today shows what the update would do only by
## accident, which for an update that adds an address is never.
var _on_applied: Callable = Callable()
var _on_dry_run: Callable = Callable()


func _init() -> void:
	title = EventSheetL10n.translate("Update pack")
	ok_button_text = EventSheetL10n.translate("Take This Update")
	add_cancel_button(EventSheetL10n.translate("Cancel"))
	add_child(EventSheetPopupUI.margined(_build_body()))
	confirmed.connect(_on_confirmed)


func configure(on_applied: Callable, on_dry_run: Callable) -> void:
	_on_applied = on_applied
	_on_dry_run = on_dry_run


## Points the window at one pack and one incoming archive. Returns false when the archive holds
## nothing for this pack, so the caller can say so rather than showing an empty page.
func open_update(pack_folder: String, incoming: Dictionary, version: String = "") -> bool:
	if incoming.is_empty():
		return false
	_pack_folder = pack_folder
	_incoming = incoming
	_version = version
	_plan = EventSheetPackUpdate.plan(_pack_folder, _incoming)
	_vocabulary = EventSheetPackUpdate.vocabulary(_pack_folder, _incoming)
	_vocabulary_after = EventSheetPackUpdate.vocabulary_after(_pack_folder, _incoming)
	_choices.clear()
	_fill()
	return true


func _build_body() -> Control:
	var page: VBoxContainer = EventSheetPopupUI.form_box()
	page.custom_minimum_size = Vector2(760.0, 520.0)
	_summary = EventSheetPopupUI.hint_label("", 720.0)
	page.add_child(_summary)
	_untouched_list = _list(120.0)
	page.add_child(EventSheetPopupUI.titled_card(
		EventSheetL10n.translate("Untouched - these take the new version"), _untouched_list))
	_yours_box = VBoxContainer.new()
	_yours_box.add_theme_constant_override("separation", 4)
	var yours_scroll: ScrollContainer = ScrollContainer.new()
	yours_scroll.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(140.0))
	yours_scroll.add_child(_yours_box)
	_yours_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_yours_card = EventSheetPopupUI.titled_card(EventSheetL10n.translate("Yours - you changed these"), yours_scroll)
	page.add_child(_yours_card)
	var vocabulary_box: VBoxContainer = EventSheetPopupUI.form_box()
	_vocabulary_list = _list(90.0)
	vocabulary_box.add_child(_vocabulary_list)
	_dry_run_button = Button.new()
	_dry_run_button.text = EventSheetL10n.translate("Dry run…")
	_dry_run_button.tooltip_text = EventSheetL10n.translate("Opens the migrate receipt for the sheet in front of you, answered against the vocabulary this update would leave: every row that would be rewritten, shown before anything is. Reading a version's verbs runs its script, under user:// - nothing of it is written under res:// until you take it.")
	_dry_run_button.pressed.connect(_on_dry_run_pressed)
	vocabulary_box.add_child(_dry_run_button)
	_vocabulary_card = EventSheetPopupUI.titled_card(EventSheetL10n.translate("What this version retires and adds"), vocabulary_box)
	page.add_child(_vocabulary_card)
	return page


func _list(rows_high: float) -> ItemList:
	var list: ItemList = ItemList.new()
	list.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(rows_high))
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return list


# ── Drawing the proposal ──────────────────────────────────────────────────────────────────────


func _fill() -> void:
	_summary.text = EventSheetPackUpdate.summary_text(_plan)
	_untouched_list.clear()
	for row: Dictionary in (_plan.get("untouched", []) as Array):
		var line: String = EventSheetPackUpdate.row_text(row)
		_untouched_list.add_item(line)
		_untouched_list.set_item_tooltip(_untouched_list.item_count - 1, line)
	for child: Node in _yours_box.get_children():
		child.queue_free()
	for row: Dictionary in (_plan.get("yours", []) as Array):
		_yours_box.add_child(_yours_row(row))
	_yours_card.visible = not (_plan.get("yours", []) as Array).is_empty()
	_vocabulary_list.clear()
	for line: String in EventSheetPackUpdate.vocabulary_lines(_vocabulary):
		_vocabulary_list.add_item(line)
		_vocabulary_list.set_item_tooltip(_vocabulary_list.item_count - 1, line)
	# A vocabulary that neither retires nor adds anything is not a section with nothing in it: it is
	# a fact worth one line, because "this update changes no verbs" is what most updates are.
	if _vocabulary_list.item_count == 0:
		_vocabulary_list.add_item(EventSheetL10n.translate("This version publishes the same conditions, actions and expressions as the one you have."))
	_dry_run_button.disabled = (_vocabulary.get("retired", []) as Array).is_empty()


## One row of the YOURS list: the file, what the new version does to it, and the answer.
func _yours_row(row: Dictionary) -> Control:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", EventSheetPopupUI.ROW_SEPARATION)
	var label: Label = Label.new()
	label.text = EventSheetPackUpdate.row_text(row)
	label.tooltip_text = label.text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	line.add_child(label)
	var relative: String = str(row.get("path", ""))
	var answer: OptionButton = OptionButton.new()
	answer.add_item(EventSheetL10n.translate("Keep mine"), 0)
	answer.add_item(EventSheetL10n.translate("Take new"), 1)
	answer.selected = 1 if EventSheetPackUpdate.default_choice(row) == EventSheetPackUpdate.CHOICE_TAKE_NEW else 0
	answer.item_selected.connect(func(index: int) -> void:
		_choices[relative] = EventSheetPackUpdate.CHOICE_TAKE_NEW if index == 1 \
			else EventSheetPackUpdate.CHOICE_KEEP_MINE)
	line.add_child(answer)
	var diff_button: Button = Button.new()
	diff_button.text = EventSheetL10n.translate("See the diff")
	diff_button.disabled = str(row.get("change", "")) != EventSheetPackUpdate.CHANGE_REPLACED
	diff_button.pressed.connect(func() -> void: _show_diff(relative))
	line.add_child(diff_button)
	return line


# ── The diff ──────────────────────────────────────────────────────────────────────────────────


## The changed region of one file, yours above the new version's. The region itself is worked out by
## the same trim-the-common-ends diff the sheet's own "What changed?" uses, so there is one idea of
## what a changed region is in this plugin rather than two.
func _show_diff(relative: String) -> void:
	if _diff_dialog == null:
		_diff_dialog = AcceptDialog.new()
		_diff_dialog.title = EventSheetL10n.translate("See the diff")
		_diff_text = TextEdit.new()
		_diff_text.editable = false
		_diff_text.custom_minimum_size = Vector2(760.0, 460.0)
		# Code, so it is read in the editor's own code face rather than the UI one.
		var code_font: Font = EventSheetPopupUI.editor_font("doc_source")
		if code_font != null:
			_diff_text.add_theme_font_override("font", code_font)
		_diff_dialog.add_child(EventSheetPopupUI.margined(_diff_text))
		add_child(_diff_dialog)
	_diff_text.text = diff_text(_pack_folder.path_join(relative), _incoming.get(relative, PackedByteArray()))
	_diff_dialog.popup_centered(Vector2i(820, 520))


## The two sides of one file's change as text: the lines that differ, yours first. Static and pure
## over a path and the incoming bytes, so the suite reads exactly what the window shows.
static func diff_text(installed_path: String, incoming_bytes: PackedByteArray) -> String:
	var mine: PackedStringArray = FileAccess.get_file_as_string(installed_path).split("\n")
	var theirs: PackedStringArray = incoming_bytes.get_string_from_utf8().split("\n")
	var region: Dictionary = EventSheetSheetDiff.changed_region(mine, theirs)
	if region.is_empty():
		return EventSheetL10n.translate("These two files are identical.")
	var lines: PackedStringArray = PackedStringArray([EventSheetL10n.translate("Yours:")])
	for index: int in range(int(region["old_start"]), int(region["old_end"]) + 1):
		lines.append("  %s" % mine[index - 1])
	lines.append("")
	lines.append(EventSheetL10n.translate("The new version:"))
	for index: int in range(int(region["new_start"]), int(region["new_end"]) + 1):
		lines.append("  %s" % theirs[index - 1])
	return "\n".join(lines)


# ── The two doors ─────────────────────────────────────────────────────────────────────────────


func _on_dry_run_pressed() -> void:
	if _on_dry_run.is_valid():
		_on_dry_run.call(_vocabulary_after)
		hide()


func _on_confirmed() -> void:
	var done: Dictionary = EventSheetPackUpdate.apply(_pack_folder, _incoming, _plan, _choices, _version)
	if _on_applied.is_valid():
		_on_applied.call(applied_text(done))


## What happened, in the same four numbers whatever the answers were. Pure, so the suite pins the
## sentence rather than a window's label.
## What happened, and WHERE THE PREVIOUS BYTES ARE. The ring is a folder of files rather than a
## button - the editor's Restore menu restores the sheet in front of you - so naming it is what makes
## "backed up" something a reader can act on rather than a number they have to trust.
static func applied_text(done: Dictionary) -> String:
	return EventSheetL10n.translate("%d file(s) took the new version, %d were removed, %d of yours were kept. %d went into the backup ring first.") % [
		int(done.get("written", 0)), int(done.get("removed", 0)),
		int(done.get("kept", 0)), int(done.get("backed_up", 0))] 		+ EventSheetPackUpdate.backup_note(done)
