# Pack builder - save_system (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Save System addon v2: slot-based persistence as an AUTOLOAD sheet - deliberately
## UN-opinionated: storage strategy (directory/pattern/section/format/encryption) is
## exported Inspector properties; the core is Variant-typed (typed Save Number/Text
## remain as conveniences - their ace_ids are API); before_save/after_load lifecycle
## signals let ANY sheet contribute state without this pack knowing it exists; slot
## metadata powers save/load menus; optional autosave. Full-state snapshots stay an
## honest non-goal (Godot serializes scenes, not "the whole game").
## THE DEEPEST EXTENSION POINT: this pack IS an event sheet - open the .tres, add
## functions, recompile, re-register.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("save_system", "Node", "SaveSystemAddon",
		"Slot-based persistence as the SaveSystem autoload: every sheet saves and loads values by name, each slot is its own file, and the location, format, and encryption are set once in the Inspector. Save Game fires On Before Save so every sheet writes its own piece, and Load Game fires On After Load so every sheet reads it back.",
		{"autoload": "SaveSystem", "verb_category": "Save System", "tags": PackedStringArray(["persistence"])})
	src.sheet.variables = {
		"autosave_accumulator": {"type": "float", "default": 0.0, "exported": false},
		"autosave_interval": {"type": "float", "default": 0.0, "exported": true,
			"attributes": {"tooltip": "Seconds between autosaves (0 = off). Fires On Before Save first.", "range": {"min": "0", "max": "600", "step": "1"}}},
		"backup_count": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "How many earlier versions of each slot to keep (0 = off). Every write copies the slot's previous bytes into a ring beside the save, so Restore Slot From Backup can go back to a save that was written perfectly and is simply wrong.", "range": {"min": "0", "max": "50", "step": "1"}}},
		"encryption_key": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "Non-empty = encrypted saves (keep the key out of screenshots!)."}},
		"file_pattern": {"type": "String", "default": "save_{slot}.cfg", "exported": true,
			"attributes": {"tooltip": "{slot} becomes the slot number."}},
		"format": {"type": "String", "default": "config", "exported": true, "options": ["config", "json", "binary", "csv", "ini", "xml"],
			"attributes": {"tooltip": "config = ConfigFile (Godot-native), json = readable text, binary = compact store_var, csv = spreadsheet rows, ini = portable [section] key=value, xml = structured <entry> tags. All six preserve exact types."}},
		"persist_group": {"type": "String", "default": "persist", "exported": true,
			"attributes": {"tooltip": "Nodes in this group (and their behaviors) auto-save via save_state()/load_state() on Save Game / Load Game."}},
		"save_directory": {"type": "String", "default": "user://", "exported": true,
			"attributes": {"tooltip": "Where save files live."}},
		"save_version": {"type": "int", "default": 1, "exported": true,
			"attributes": {"tooltip": "The save shape number THIS build writes. Bump it whenever your saved data changes shape, and Load Game fires On Save Needs Upgrade for every older file so migration rows can fix it before anything reads it. 1 = nothing to migrate yet (and nothing is stamped, so files stay exactly as they were).", "range": {"min": "1", "max": "999", "step": "1"}}},
		"section": {"type": "String", "default": "save", "exported": true,
			"attributes": {"tooltip": "ConfigFile section / JSON namespace for values."}},
		"slot": {"type": "int", "default": 0, "exported": true,
			"attributes": {"tooltip": "Active save slot (each slot is its own file).", "range": {"min": "0", "max": "9", "step": "1"}, "group": "Save System"}}
	}
	src.note("Save System: register as the SaveSystem autoload, then save from any sheet. Strategy (paths/format/encryption) lives in the Inspector; On Before Save / On After Load let every sheet contribute its own state. This pack is an event sheet - extend it by editing it.")
	src.block("block_1")
	src.on_process()
	src.block("block_2")
	src.block("block_3")
	src.verb("save_value", "Save Value",
		"Writes ANY value (number, text, Vector2, Color, Dictionary…) under the key.",
		[["key", "String"], ["value", "Variant"]])
	src.expression("load_value", "Load Value",
		"Reads any value (your default when missing).",
		[["key", "String"], ["default_value", "Variant"]], TYPE_MAX)
	src.verb("save_number", "Save Number",
		"Writes a number under the key (active slot).",
		[["key", "String"], ["value", "float"]])
	src.expression("load_number", "Load Number",
		"Reads a number (0 when missing).",
		[["key", "String"]], TYPE_FLOAT)
	src.verb("save_text", "Save Text",
		"Writes a string under the key (active slot).",
		[["key", "String"], ["value", "String"]])
	src.expression("load_text", "Load Text",
		"Reads a string (\"\" when missing).",
		[["key", "String"]], TYPE_STRING)
	src.condition("has_save_key", "Has Save Key",
		"Whether the key exists in the active slot.",
		[["key", "String"]])
	src.expression("read_all", "Read All",
		"Reads the whole active slot as one Dictionary (every saved key and value).",
		[], TYPE_DICTIONARY)
	src.expression("save_keys", "List Save Keys",
		"The keys stored in the active slot (loop them to read a whole save).",
		[], TYPE_ARRAY)
	src.expression("read_file", "Read Save File",
		"Reads ANY save file at a path in the given format (config/json/binary/csv/ini/xml; blank = the active format) and returns its Dictionary.",
		[["path", "String"], ["file_format", "String"]], TYPE_DICTIONARY)
	src.expression("save_file_format", "Save File Format",
		"Detects the format of the save file at the path (config/json/binary/csv/ini/xml), or \"\" when it is missing or unrecognised. Feed it to Read Save File.",
		[["path", "String"]], TYPE_STRING)
	src.condition("save_file_is_format", "Save File Is Format",
		"Whether the save file at the path is the given format (config/json/binary/csv/ini/xml).",
		[["path", "String"], ["expected_format", "String"]])
	src.condition("save_format_is", "Save Format Is",
		"Whether the active save format (the Inspector format property) equals the given one.",
		[["expected_format", "String"]])
	src.verb("delete_slot", "Delete Slot",
		"Removes the active slot's save file (and its slot picture, which lives beside it).",
		[])
	src.verb("save_game", "Save Game",
		"Broadcasts On Before Save (every sheet writes its state), snapshots every node in the persist group, stamps the slot card, then fires On Save Written (or On Save Failed).",
		[])
	src.verb("load_game", "Load Game",
		"Reads the slot, gives migration rows their moment (On Save Needs Upgrade) when an older build wrote it, restores every persist-group snapshot, then broadcasts On After Load. A file it cannot read fires On Load Failed instead.",
		[])
	src.verb("save_node_state", "Save Node State",
		"Snapshots a node and its behaviors (any child with save_state) under the key.",
		[["node", "Node"], ["key", "String"]])
	src.verb("load_node_state", "Load Node State",
		"Restores a node and its behaviors from the key's snapshot.",
		[["node", "Node"], ["key", "String"]])
	src.verb("save_group_state", "Save Group State",
		"Snapshots every node in the scene-tree group (and their behaviors) under the key.",
		[["group", "String"], ["key", "String"]])
	src.verb("load_group_state", "Load Group State",
		"Restores the group snapshot saved under the key (nodes matched by scene path).",
		[["key", "String"]])
	src.verb("save_singleton_state", "Save Singleton State",
		"Snapshots an autoload addon (Currency Ledger, Upgrades, Prestige...) by its autoload name.",
		[["singleton_name", "String"], ["key", "String"]])
	src.verb("load_singleton_state", "Load Singleton State",
		"Restores an autoload addon's snapshot from the key.",
		[["singleton_name", "String"], ["key", "String"]])
	src.condition("slot_exists", "Slot Exists",
		"Whether the slot has a save file.",
		[["slot_index", "int"]])
	src.expression("list_slots", "List Slots",
		"Slot numbers that have save files (for menus).",
		[], TYPE_ARRAY)
	src.expression("slot_modified_time", "Slot Modified Time",
		"Unix mtime of the slot's file (0 when missing).",
		[["slot_index", "int"]], TYPE_INT)
	src.verb("set_slot_detail", "Set Slot Detail",
		"Writes one line of the active slot's card - the header a load menu reads without ever calling Load Game (chapter, hero name, percent, difficulty...). Playtime rides along automatically.",
		[["detail_name", "String"], ["value", "Variant"]])
	src.expression("slot_detail", "Slot Detail",
		"Reads one card field of any slot straight off disk (your fallback when that slot has no such detail). Nothing is loaded and nothing is applied - safe to call for every tile of a load menu.",
		[["slot_index", "int"], ["detail_name", "String"], ["fallback", "Variant"]], TYPE_MAX)
	src.expression("slot_playtime", "Slot Playtime",
		"Seconds played on that slot, accumulated by this pack and stamped on every save (0 when the slot has none). Feed it to Format Time for a 4h12m tile.",
		[["slot_index", "int"]], TYPE_FLOAT)
	src.verb("capture_slot_thumbnail", "Capture Slot Thumbnail",
		"Photographs the viewport, shrinks it to tile size and writes it beside the active slot's file, so the picture travels with the save - Copy Slot brings it along, Delete Slot takes it away, and an encryption key covers the picture exactly as it covers the save. Hide your pause menu first.",
		[["width", "int"], ["height", "int"]])
	src.object_expression("slot_thumbnail", "Slot Thumbnail",
		"The picture saved beside that slot, ready to drop into a TextureRect (null when the slot has none). Read off disk, so a load menu never loads a game to draw its tiles.",
		[["slot_index", "int"]], "Texture2D")
	src.verb("copy_slot", "Copy Slot",
		"Duplicates one slot's save file (and its picture) onto another slot - branching a save as one row. The destination is overwritten.",
		[["from_slot", "int"], ["to_slot", "int"]])
	src.expression("slot_path", "Slot Path",
		"Where that slot's file lives (built from the Save Directory and File Pattern properties). Feed it to Read Save File, File Size or Copy File - the paths the pack uses are no longer private.",
		[["slot_index", "int"]], TYPE_STRING)
	src.verb("delay_autosave_by", "Delay Autosave By",
		"Pushes the next autosave out by this many seconds. The beat is deferred, never dropped - use it in the not-now branch of On Autosave Due.",
		[["seconds", "float"]])
	src.verb("pause_autosave", "Pause Autosave",
		"Stops the autosave clock without losing the interval - for a boss fight, a cutscene, or a scene transition. Resume Autosave starts it again.",
		[])
	src.verb("resume_autosave", "Resume Autosave",
		"Starts the autosave clock again after Pause Autosave, from a fresh interval.",
		[])
	src.expression("seconds_until_autosave", "Seconds Until Autosave",
		"How long until the next autosave beat - for a countdown pip in the corner. 0 when autosave is off or paused.",
		[], TYPE_FLOAT)
	src.condition("autosave_is_paused", "Autosave Is Paused",
		"Whether Pause Autosave is currently holding the clock.",
		[])
	src.condition("can_save_now", "Safe To Save Now",
		"Whether writing the active slot right now would lose nothing: the slot either has no file yet, or its file reads back cleanly. Guard Save Game with it (and read it inside On Autosave Due before you commit to a write).",
		[])
	src.verb("use_upgraded_save", "Use Upgraded Save",
		"Writes the record the migration rows just fixed back to the slot, stamped with the current Save Version, and lets Load Game carry on with it. Run it once at the end of On Save Needs Upgrade - the stamp makes the trigger stop firing for that file.",
		[["save_data", "Dictionary"]])
	src.expression("slot_save_version", "Slot Save Version",
		"Which Save Version wrote that slot's file. A file with no stamp counts as 1, so saves written before you ever bumped the number still answer.",
		[["slot_index", "int"]], TYPE_INT)
	src.condition("slot_is_readable", "Slot Is Readable",
		"Whether that slot's file opens and parses. A slot with NO file reads as false, so pair it with Slot Exists to tell a slot with no save yet apart from a damaged one.",
		[["slot_index", "int"]])
	src.expression("last_save_problem", "Last Save Problem",
		"The last save or load failure as one readable sentence (\"\" when both worked). Show it in a label, or log it.",
		[], TYPE_STRING)
	src.expression("slot_problem", "Slot Problem",
		"What is wrong with that slot's file, as one readable sentence (\"\" when it reads fine or does not exist) - the tooltip for a greyed-out Continue button.",
		[["slot_index", "int"]], TYPE_STRING)
	src.verb("save_all_addons", "Save All Addons",
		"Snapshots every autoload that exposes the save_state seam - Currency Ledger, Upgrades, Prestige, Skin Vault, StatForge and anything you wrote - each under its own autoload name. There is no list to maintain: install a pack, register it, and it is in the save.",
		[])
	src.verb("load_all_addons", "Load All Addons",
		"Restores every autoload snapshot Save All Addons wrote, matched by autoload name. An addon the save knows but this build does not have is reported, never dropped in silence.",
		[])
	src.condition("addon_saves_itself", "Addon Saves Itself",
		"Whether that autoload takes part in Save All Addons (it exposes save_state, itself or through a behavior child). Invert it to catch the pack somebody forgot to give a save seam.",
		[["addon_name", "String"]])
	src.verb("never_save_key", "Never Save This Key",
		"Keeps this key out of every save from now on - cached node lists, throwaway buffers, totals you recompute. It is dropped on the way to the file whichever row wrote it, and an already-saved copy disappears on the next write.",
		[["key", "String"]])
	src.expression("save_size", "Save Size",
		"How many bytes the active slot's file takes on disk (0 when there is none) - the number nobody sees until a player reports a 40MB save.",
		[], TYPE_INT)
	src.expression("save_report", "Save Report",
		"A plain-text breakdown of the active save: total bytes, key count, then the heaviest keys in order. Log it, or show it in a debug overlay when a player reports a save that will not stop growing. The total is the real size of the file on disk; the per-key numbers are relative WEIGHTS (each value written out as text, measured in characters), so they rank the keys against one another rather than adding up to the total.",
		[], TYPE_STRING)
	src.verb("restore_slot_from_backup", "Restore Slot From Backup",
		"Puts an earlier version of the slot back (1 = the save before this one, 2 = the one before that). The CURRENT file is backed up first, so a restore is never a one-way door. Needs Backup Count above 0.",
		[["slot_index", "int"], ["how_many_back", "int"]])
	src.expression("slot_backup_count", "Slot Backup Count",
		"How many earlier versions of that slot are kept right now (0 when backups are off or nothing has been overwritten yet).",
		[["slot_index", "int"]], TYPE_INT)
	src.verb("carry_value_into_next_run", "Carry Value Into Next Run",
		"Marks one key to survive Start New Run - unlocked skins, a best time, the settings. Everything not marked is wiped. Marks last for the session, so declare them right before the reset.",
		[["key", "String"]])
	src.verb("start_new_run", "Start New Run",
		"Wipes the slot and writes back ONLY the carried keys, its slot card, and a run counter one higher than before, then fires On New Run Started. New Game Plus, a chapter reset, a seasonal wipe, or the Reset Progress button that must keep the settings.",
		[["slot_index", "int"]])
	src.expression("run_number", "Run Number",
		"1 on a fresh save, 2 after the first New Game Plus, and so on - the number every NG+ banner, difficulty curve and you-have-beaten-this-N-times line is really asking for.",
		[], TYPE_INT)
	src.verb("remove_save_key", "Remove Save Key",
		"Takes one key out of the active slot and rewrites the file, then fires On Key Removed. A key the slot does not hold fires On Save Key Missing instead. Never Save This Key blocks a key forever; this removes the one copy that is already there.",
		[["key", "String"]])
	src.verb("clear_slot_keys", "Clear Slot Keys",
		"Empties the active slot of everything the game saved, and fires On Key Removed once per key. The file itself stays, and so do its slot card, its version stamp, its run number and its backups - the reset-profile button that does not cost the player their save file.",
		[])
	src.verb("check_save_key", "Check Save Key",
		"Asks the slot whether it holds the key and answers with a row: On Key Loaded when it does, On Save Key Missing when it does not. The row that turns a silent default into a first-run seed.",
		[["key", "String"]])
	src.condition("is_saving", "Is Saving",
		"Whether a write is in flight right now - inside On Before Save, a Save All Addons sweep, or an autosave. Guard a second write with it, or hold a quit until it clears.",
		[])
	src.condition("is_loading", "Is Loading",
		"Whether a load is in flight right now - the read, the migration gap and the On After Load broadcast are all inside it. Rows that must not fight the restore can stand aside while it is true.",
		[])
	src.condition("save_key_is", "Save Key Is",
		"Whether the stored key equals this value, without loading it into a variable first. A key the slot does not hold never equals anything, so a missing key reads as false.",
		[["key", "String"], ["value", "Variant"]])
	src.expression("save_key_count", "Save Key Count",
		"How many keys the active slot holds - the number a save inspector puts in its header. Counts exactly what List Save Keys lists, the pack's own reserved keys included.",
		[], TYPE_INT)
	src.expression("save_key_at", "Save Key At",
		"The key at this position in the active slot, for a numbered or paged list (\"\" when the position is past the end). Loop List Save Keys instead when you just want them all.",
		[["index", "int"]], TYPE_STRING)
	Lib.verb_sentences(src.sheet, {
		"set_slot_detail": "remember [b]{detail_name}[/b] = [b]{value}[/b] on this slot",
		"capture_slot_thumbnail": "photograph this slot at [b]{width}[/b] x [b]{height}[/b]",
		"copy_slot": "copy slot [b]{from_slot}[/b] onto slot [b]{to_slot}[/b]",
		"delay_autosave_by": "put the autosave off for [b]{seconds}[/b] more seconds",
		"use_upgraded_save": "use [b]{save_data}[/b] as the save from here on",
		"slot_is_readable": "slot [b]{slot_index}[/b] can be read",
		"save_all_addons": "save every addon that saves itself",
		"never_save_key": "never put [b]{key}[/b] in a save",
		"restore_slot_from_backup": "put slot [b]{slot_index}[/b] back to backup [b]{how_many_back}[/b]",
		"carry_value_into_next_run": "carry [b]{key}[/b] into the next run",
		"start_new_run": "start a new run in slot [b]{slot_index}[/b]",
		"remove_save_key": "forget [b]{key}[/b] from this slot",
		"clear_slot_keys": "forget everything this slot saved",
		"check_save_key": "ask whether [b]{key}[/b] is saved",
	})
	Lib.feature_verbs(src.sheet, ["save_game", "load_game", "save_all_addons"])
	return Lib.publish(src, "res://eventsheet_addons/save_system/save_system_addon")
