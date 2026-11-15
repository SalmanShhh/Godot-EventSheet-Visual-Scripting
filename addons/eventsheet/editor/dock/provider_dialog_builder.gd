@tool
extends RefCounted
# The provider-registration dialog's construction, moved out of the dock's UI builder so the first
# open of a sheet does not compile it: the dialog is only built when someone opens it, and the
# builder reaches this file by path at that moment. The body is the old method verbatim; the
# dock reference arrives as a parameter and every widget reference still lives on the dock.

var _dock: Control = null


func build(dock: Control) -> void:
	_dock = dock
	if _dock._provider_dialog != null:
		return
	_dock._provider_dialog = Window.new()
	_dock._provider_dialog.title = EventSheetL10n.translate("Custom ACE Providers")
	_dock._provider_dialog.visible = false
	_dock._provider_dialog.min_size = Vector2i(720, 620)
	_dock._provider_dialog.close_requested.connect(func() -> void: _dock._provider_dialog.hide())
	_dock.add_child(_dock._provider_dialog)

	var content: VBoxContainer = EventSheetPopupUI.form_box()
	_dock._provider_dialog.add_child(EventSheetPopupUI.window_body(content))

	content.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("Register GDScript files whose methods, signals and exported variables become custom ACEs.\nZero-config alternative: drop scripts into res://eventsheet_addons/ and they register project-wide automatically.")))

	var providers_box: VBoxContainer = EventSheetPopupUI.form_box()

	_dock._provider_list = ItemList.new()
	_dock._provider_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock._provider_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	providers_box.add_child(_dock._provider_list)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	providers_box.add_child(buttons)
	var add_button: Button = Button.new()
	add_button.text = "Add…"
	add_button.pressed.connect(_dock._providers_glue.on_provider_add_pressed)
	buttons.add_child(add_button)
	var remove_button: Button = Button.new()
	remove_button.text = EventSheetL10n.translate("Remove Selected")
	remove_button.pressed.connect(_dock._providers_glue.on_provider_remove_pressed)
	buttons.add_child(remove_button)
	var open_in_godot_button: Button = Button.new()
	open_in_godot_button.text = "Open in Godot Script Editor"
	open_in_godot_button.tooltip_text = "Open the selected provider script in Godot's script editor."
	open_in_godot_button.pressed.connect(_dock._preview_glue._on_provider_open_in_godot_pressed)
	buttons.add_child(open_in_godot_button)

	var providers_card: PanelContainer = EventSheetPopupUI.titled_card("Providers", providers_box)
	providers_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(providers_card)
	_dock._provider_list.item_selected.connect(func(index: int) -> void:
		var entry: Variant = _dock._provider_list.get_item_metadata(index)
		var listed_path: String = str((entry as Dictionary).get("path", "")) if entry is Dictionary else ""
		# Already registered, so this is a read of what it contributes - no Register button.
		_dock._providers_glue.preview_provider_script(listed_path, false))

	# "What it publishes": the scan of the highlighted (or just-browsed) script. Browsing previews only -
	# Register is the second, deliberate click - so a script never joins the vocabulary unseen.
	var preview_box: VBoxContainer = EventSheetPopupUI.form_box()
	_dock._provider_preview_summary = EventSheetPopupUI.hint_label(EventSheetL10n.translate("Select a provider, or press Add to preview a script."))
	preview_box.add_child(_dock._provider_preview_summary)
	_dock._provider_preview_warnings = VBoxContainer.new()
	_dock._provider_preview_warnings.add_theme_constant_override("separation", 2)
	preview_box.add_child(_dock._provider_preview_warnings)
	# The table is the curation surface as well as the preview: Publish, Kind, Verb and Category are
	# editable in place, and "Curate Script" writes the differences back as `## @ace_*` annotations.
	# Raw reflection guesses these from the signature, which is wrong often enough on real game code
	# (an untyped method reads as an Action) that "see it, fix it, keep it" has to be one flow.
	_dock._provider_preview_tree = Tree.new()
	_dock._provider_preview_tree.columns = 6
	_dock._provider_preview_tree.column_titles_visible = true
	_dock._provider_preview_tree.set_column_title(0, "Publish")
	_dock._provider_preview_tree.set_column_title(1, "Kind")
	_dock._provider_preview_tree.set_column_title(2, "Name")
	_dock._provider_preview_tree.set_column_title(3, "Category")
	_dock._provider_preview_tree.set_column_title(4, "Parameters")
	_dock._provider_preview_tree.set_column_title(5, "Emits")
	_dock._provider_preview_tree.set_column_expand(0, false)
	_dock._provider_preview_tree.set_column_custom_minimum_width(0, 62)
	_dock._provider_preview_tree.set_column_expand(1, false)
	_dock._provider_preview_tree.set_column_custom_minimum_width(1, 110)
	# The verb name is what the reader scans for, so it gets the room; the emitted code is the widest
	# text but also the least urgent (the row's tooltip carries the full id and source member anyway).
	_dock._provider_preview_tree.set_column_expand_ratio(2, 3)
	_dock._provider_preview_tree.set_column_expand_ratio(3, 2)
	_dock._provider_preview_tree.set_column_expand_ratio(4, 2)
	_dock._provider_preview_tree.set_column_expand_ratio(5, 3)
	_dock._provider_preview_tree.set_column_clip_content(5, true)
	_dock._provider_preview_tree.hide_root = true
	_dock._provider_preview_tree.custom_minimum_size = Vector2(0, 180)
	_dock._provider_preview_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_box.add_child(_dock._provider_preview_tree)
	var preview_actions: HBoxContainer = HBoxContainer.new()
	preview_actions.add_theme_constant_override("separation", 6)
	preview_box.add_child(preview_actions)
	_dock._provider_register_button = Button.new()
	_dock._provider_register_button.text = "Register This Script"
	_dock._provider_register_button.visible = false
	_dock._provider_register_button.tooltip_text = "Add the previewed script to this sheet's providers, so the actions above join the picker."
	_dock._provider_register_button.pressed.connect(_dock._providers_glue.on_provider_register_pressed)
	preview_actions.add_child(_dock._provider_register_button)
	_dock._provider_curate_button = Button.new()
	_dock._provider_curate_button.text = "Curate Script…"
	_dock._provider_curate_button.visible = false
	_dock._provider_curate_button.tooltip_text = "Write your edits above into the script as `## @ace_*` comments, so it keeps publishing them.\nOnly comments are added - your signatures and bodies are never touched, and the file is backed up first."
	_dock._provider_curate_button.pressed.connect(_dock._providers_glue.on_provider_curate_pressed)
	preview_actions.add_child(_dock._provider_curate_button)
	_dock._provider_params_button = Button.new()
	_dock._provider_params_button.text = "Parameters…"
	_dock._provider_params_button.visible = false
	_dock._provider_params_button.tooltip_text = "Shape the selected entry's parameters: a hint (try 'comparison'), a fixed set of choices, and what the row shows the moment it is dropped."
	_dock._provider_params_button.pressed.connect(_dock._providers_glue.on_provider_params_pressed)
	preview_actions.add_child(_dock._provider_params_button)
	_dock._provider_shim_button = Button.new()
	_dock._provider_shim_button.text = "Keep Old Name…"
	_dock._provider_shim_button.visible = false
	_dock._provider_shim_button.tooltip_text = "Renamed this function? Add a deprecated stand-in under its old name so sheets that already use it keep working.\nNothing existing is edited - the stand-in just forwards."
	_dock._provider_shim_button.pressed.connect(_dock._providers_glue.on_provider_shim_pressed)
	preview_actions.add_child(_dock._provider_shim_button)
	var preview_card: PanelContainer = EventSheetPopupUI.titled_card(EventSheetL10n.translate("What it publishes"), preview_box)
	preview_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(preview_card)

	_dock._provider_file_dialog = FileDialog.new()
	_dock._provider_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dock._provider_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_dock._provider_file_dialog.filters = PackedStringArray(["*.gd ; GDScript"])
	_dock._provider_file_dialog.file_selected.connect(_dock._providers_glue.on_provider_file_selected)
	_dock._provider_dialog.add_child(_dock._provider_file_dialog)
