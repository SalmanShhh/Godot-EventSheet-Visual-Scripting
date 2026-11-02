@tool
extends RefCounted
# Functions moved VERBATIM out of viewport_row_builder.gd so that opening a sheet does not compile them
# (an open never calls them). Reading rows, head bars and findings that only some sheets show.
# Each is reached through a thin delegate in viewport_row_builder.gd; an instance function takes its owner as `_owner`.


## The muted count a FOLDED region wears: how many EVENTS it holds when it holds any (the word
## structure is read for), else how many rows. The closing fence rides as the last child and is
## plumbing, so it is never counted.
static func _region_member_count_text(_owner: ViewportRowBuilder, region_children: Array[EventRowData]) -> String:
	var events: int = 0
	var rows: int = 0
	for index: int in range(maxi(region_children.size() - 1, 0)):
		rows += 1
		if region_children[index].row_type == EventRowData.RowType.EVENT:
			events += 1
	if events > 0:
		return EventSheetL10n.translate("%d event") % events if events == 1 \
			else EventSheetL10n.translate("%d events") % events
	return EventSheetL10n.translate("%d row") % rows if rows == 1 \
		else EventSheetL10n.translate("%d rows") % rows


## The fold mark, in the shape the script editor draws it: a dashed `#` box in the badge
## column, the name in the row's own ink, the description muted beside it, and the fence line
## echoed at the right edge. No folder, no chapter-bar height, no "end region" prose - a region is
## two lines of the file, and the row says exactly those two lines.
static func _dress_region_fence_row(_owner: ViewportRowBuilder, row_data: EventRowData, block: CustomBlockRow) -> void:
	row_data.row_type = EventRowData.RowType.REGION
	# The accent travels on the row so the renderer's wash, the dashed badge and the dashed rule
	# down the body all read the region's own colour without parsing its field three times.
	row_data.custom_color = _region_accent(_owner, block)
	if EventSheetRegionFacts.is_closing_fence(block):
		row_data.spans = [_owner._code_echo_span(
			EventSheetRegionFacts.CLOSING_LINE,
			{
				"kind": "custom_block_row",
				"region_fence": "close",
				"font_size_delta": ViewportRowBuilder.REGION_CLOSER_FONT_DELTA,
				"hover_note": EventSheetL10n.translate("Where this region ends.")
			},
			ViewportRowBuilder.REGION_CLOSER_ECHO_ALPHA,
			false
		)]
		return
	_apply_region_opener_spans(_owner, row_data, "")


## Whether a row's words can be brought up to date with its fold state without building it again.
## An event (or a function's head) says nothing different folded; a group head names what it holds when folded; a region
## opener counts its events when folded. Any other kind that wears its fold state (an enum's
## sentence, a moment's steps) is built again in full.
static func can_redress_fold(_owner: ViewportRowBuilder, row_data: EventRowData) -> bool:
	if row_data.source_resource is EventRow or row_data.source_resource is EventFunction:
		return row_data.row_type == EventRowData.RowType.EVENT
	if row_data.source_resource is EventGroup:
		return row_data.row_type == EventRowData.RowType.GROUP and not row_data.spans.is_empty() \
			and row_data.spans[0].metadata is Dictionary and bool((row_data.spans[0].metadata as Dictionary).get("group_fold_mark", false))
	if row_data.source_resource is CustomBlockRow:
		return row_data.row_type == EventRowData.RowType.REGION and row_data.has_meta("region_fold_key") \
			and not EventSheetRegionFacts.is_closing_fence(row_data.source_resource)
	# A code card ("Script block - 12 lines") builds its opened code as its one child whether it is
	# folded or not, and says the same words either way: the fold only decides whether that child
	# shows, which the flatten already honours.
	if row_data.source_resource is RawCodeRow:
		return row_data.row_type == EventRowData.RowType.SECTION and row_data.children.size() == 1 \
			and row_data.children[0].row_uid == "%s_code" % row_data.row_uid
	return false


## Brings the words of a row that passed can_redress_fold up to date with its fold state, using the
## very builders the full build uses, so the two cannot disagree.
static func redress_fold(_owner: ViewportRowBuilder, row_data: EventRowData) -> void:
	if row_data.source_resource is EventGroup:
		# The status spans (what the head holds, the on/off mark) are the tail of the head and the only
		# part that reads the fold; take them off and say them again.
		while not row_data.spans.is_empty():
			var tail: Variant = row_data.spans[row_data.spans.size() - 1].metadata
			if not (tail is Dictionary) or not (bool((tail as Dictionary).get("group_counts", false)) 					or str((tail as Dictionary).get("group_action", "")) == "enabled"):
				break
			row_data.spans.pop_back()
		row_data.spans.append_array(_owner._group_head_status_spans(row_data.source_resource as EventGroup,
			row_data.folded, _owner._viewport._get_reading_style()))
	elif row_data.source_resource is CustomBlockRow:
		_apply_region_opener_spans(_owner, row_data, _region_member_count_text(_owner, row_data.children))


## The opening fence's spans, built from what the row knows right now. Called once while the row is
## made (open, no count yet) and again by the pairing pass once the fold state and the member count
## are known - one description of the row, never a second one bolted on.
static func _apply_region_opener_spans(_owner: ViewportRowBuilder, row_data: EventRowData, count_text: String) -> void:
	var block: CustomBlockRow = row_data.source_resource as CustomBlockRow
	if block == null:
		return
	var reading_style: EventSheetReadingStyle = _owner._viewport._get_reading_style()
	var accent: Color = _region_accent(_owner, block)
	var spans: Array[SemanticSpan] = [_owner._make_span(
		EventSheetRegionFacts.FENCE_GLYPH,
		SemanticSpan.SpanType.KEYWORD,
		{
			"kind": "custom_block_row",
			"region_badge": true,
			"badge": true,
			"badge_style": "outline",
			"badge_dashed": true,
			"badge_natural_width": true,
			"badge_fixed_width": ViewportRowBuilder.KIND_BADGE_WIDTH,
			"line_index": 0,
			"badge_bg": accent,
			"badge_fg": accent
		}
	)]
	var words: Dictionary = _fold_mark_words(_owner, block, row_data.folded, count_text)
	var title: String = str(words["title"])
	spans.append(_owner._make_span(
		title,
		SemanticSpan.SpanType.OBJECT,
		{
			"kind": "custom_block_row",
			"region_title": true,
			"editable": true,
			"edit_kind": "region_name",
			"line_index": 0,
			"text_color": reading_style.primary_text_color,
			"bbcode_segments": [{
				"text": title,
				"color": reading_style.primary_text_color,
				"bold": true,
				"italic": false
			}]
		}
	))
	# Open, the row carries the author's own description; folded, what it holds - the one thing
	# worth knowing before deciding whether to open it.
	var note: String = str(words["note"])
	if not note.is_empty():
		spans.append(_owner._make_span(note, SemanticSpan.SpanType.COMMENT, {
			"kind": "custom_block_row",
			"region_note": true,
			"line_index": 0,
			"text_color": reading_style.muted_text_color
		}))
	spans.append(_owner._code_echo_span(
		str(words["echo"]),
		{
			"kind": "custom_block_row",
			"region_fence": "open",
			"hover_note": EventSheetL10n.translate("The line this row writes. Click to open it in the code panel.")
		},
		EventSheetCodeEcho.REST_ALPHA,
		true
	))
	row_data.spans = spans
	row_data.line_count = 1


## The three things a fold-mark row says: the name it leads with, the muted line beside it, and the
## line of the file it echoes. The built-in fences answer from EventSheetRegionFacts - a label
## field, a description field, the fence line. ANY OTHER KIND that asked for this look through
## `row_style()` answers from the Custom Block API it already implements: its summary is the title
## and the last line it emits is the echo, so the fold-mark shape is reusable rather than region-
## only, and one place decides which of the two readings a row gets.
static func _fold_mark_words(_owner: ViewportRowBuilder, block: CustomBlockRow, folded: bool, count_text: String) -> Dictionary:
	if EventSheetRegionFacts.is_fence(block):
		return {
			"title": EventSheetRegionFacts.display_name(block),
			"note": count_text if folded else EventSheetRegionFacts.description(block),
			"echo": EventSheetRegionFacts.folded_echo(block) if folded else EventSheetRegionFacts.fence_line(block)
		}
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind(block.kind_id)
	var emitted: PackedStringArray = kind.emit_lines(block) if kind != null else PackedStringArray()
	return {
		"title": kind.summary(block) if kind != null else block.kind_id,
		"note": count_text if folded else "",
		"echo": emitted[emitted.size() - 1] if not emitted.is_empty() else ""
	}


## The region's own colour; failing that the kind's own tint, and failing that the theme's behaviour
## accent. A kind that asked for this look tints its badge through `style()`, the very hook that
## tints a flat block row's - one answer about a kind's colour, whichever shape its rows take.
static func _region_accent(_owner: ViewportRowBuilder, block: CustomBlockRow) -> Color:
	var stored: String = EventSheetRegionFacts.accent_hex(block)
	if not stored.is_empty():
		return Color.html(stored)
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind(block.kind_id)
	var styled: Dictionary = kind.style(block) if kind != null else {}
	return styled.get("accent", _owner._viewport._get_event_style().behavior_accent_color)


## The badge on a band that HAS a picture - the class icon on the name band, the `@icon` image on
## the icon band. One shape, because clicking the picture is the way to change what it shows in
## both: only the image and the gesture behind it differ. A band whose picture cannot be loaded
## still draws its badge, so the gesture stays reachable.
static func _head_band_icon_span(_owner: ViewportRowBuilder, band_meta: Dictionary, action: String, art: Texture2D, hover_note: String) -> SemanticSpan:
	var reading_style: EventSheetReadingStyle = _owner._viewport._get_reading_style()
	var badge_meta: Dictionary = band_meta.merged({
		"badge": true,
		"badge_style": "trigger",
		"badge_bg": reading_style.setup_badge_background_color,
		"badge_fg": reading_style.setup_badge_foreground_color,
		"head_action": action,
		"hover_note": hover_note
	}, true)
	if art != null:
		badge_meta["badge_icon"] = art
	return _owner._make_span("▣", SemanticSpan.SpanType.KEYWORD, badge_meta)


## The class head's own words after the name: the kind of file this is, what it extends (the extends
## band's words, control and gesture, drawn here instead of on a row of their own), and - for a
## shared sheet - the drawn share mark and the sheets that include it.
static func _class_head_spans(_owner: ViewportRowBuilder, sheet: EventSheetResource, extends_band: Dictionary) -> Array[SemanticSpan]:
	var reading_style: EventSheetReadingStyle = _owner._viewport._get_reading_style()
	var event_style: EventSheetEventStyle = _owner._viewport._get_event_style()
	var spans: Array[SemanticSpan] = []
	var name_meta: Dictionary = {"editable": false, "kind": "head_band_%s" % EventSheetHeadBands.BAND_NAME,
		"head_band": EventSheetHeadBands.BAND_NAME, "line_index": 0}
	# Only a node runs a script it is attached to: a Resource or RefCounted script is made and held
	# by other code, so its head says what it is and no more.
	var script_note: String = EventSheetL10n.translate("What this file is: a script, run by the node it is attached to.") \
		if ViewportRowBuilder.host_is_node(str(sheet.host_class)) else EventSheetL10n.translate("What this file is: a script.")
	# A quiet class head has no "change…" word, so the kind and "· extends" ARE the gesture: a click
	# changes what kind of script this is, as their hover says.
	var quiet_head: bool = event_style.inspector_class_head
	var kind_meta: Dictionary = name_meta.merged({
		"text_color": reading_style.secondary_text_color,
		"hover_note": script_note
	}, true)
	var change_note: String = EventSheetL10n.translate("Click to change what kind of script it is.")
	if quiet_head and not sheet.read_only and not extends_band.is_empty():
		kind_meta["head_action"] = EventSheetHeadBands.BAND_EXTENDS
		kind_meta["hover_note"] = "%s %s" % [script_note, change_note]
	# A behaviour or a global says which it is, quietly, where any other file says Script.
	var kind_word: String = ViewportRowBuilder.script_kind_word(sheet)
	if not kind_word.is_empty():
		kind_meta["text_color"] = reading_style.muted_text_color
	spans.append(_owner._make_span(kind_word if not kind_word.is_empty() else EventSheetL10n.translate("Script"),
		SemanticSpan.SpanType.KEYWORD, kind_meta))
	if not extends_band.is_empty():
		var extends_meta: Dictionary = {"editable": false, "kind": "head_band_%s" % EventSheetHeadBands.BAND_EXTENDS,
			"head_band": EventSheetHeadBands.BAND_EXTENDS, "line_index": 0}
		var leader_meta: Dictionary = extends_meta.merged({"text_color": reading_style.muted_text_color}, true)
		if quiet_head and not sheet.read_only:
			leader_meta["head_action"] = EventSheetHeadBands.BAND_EXTENDS
			leader_meta["hover_note"] = change_note
		spans.append(_owner._make_span("· %s" % str(extends_band["leader"]), SemanticSpan.SpanType.KEYWORD, leader_meta))
		# The quiet head says what it extends in the faint colour, all of it, as one aside.
		var base_meta: Dictionary = extends_meta.merged({
			"text_color": reading_style.muted_text_color if bool(extends_band["value_muted"]) or quiet_head \
				else reading_style.primary_text_color
		}, true)
		# A base that is another SCRIPT of this project opens as its own sheet, the door the pack
		# head's base word has always had.
		var base_path: String = ViewportRowBuilder.base_script_path(sheet)
		if not base_path.is_empty():
			base_meta["include_path"] = base_path
			base_meta["hover_note"] = EventSheetL10n.translate("Open the base script as a sheet.")
		elif quiet_head and not sheet.read_only:
			base_meta["head_action"] = EventSheetHeadBands.BAND_EXTENDS
			base_meta["hover_note"] = change_note
		spans.append(_owner._make_span(str(extends_band["value"]), SemanticSpan.SpanType.VALUE, base_meta))
		for word: String in [str(extends_band["prompt"]), "" if quiet_head else str(extends_band["control"])]:
			if word.is_empty() or sheet.read_only:
				continue
			spans.append(_owner._make_span(word, SemanticSpan.SpanType.COMMENT, extends_meta.merged({
				"head_action": EventSheetHeadBands.BAND_EXTENDS,
				"text_color": event_style.behavior_accent_color
			}, true)))
	var source_path: String = str(sheet.external_source_path)
	if ViewportRowBuilder.NativeHeadMarks.shared_wiring(source_path).is_empty():
		return spans
	# A shared sheet says so with a drawn mark on a small tile, and names who includes it. Both are
	# facts about the project rather than lines of the file, read off the include index.
	spans.append(_owner._make_span("⇆", SemanticSpan.SpanType.KEYWORD, name_meta.merged({
		"badge": true,
		"badge_style": "glyph",
		"badge_plate": true,
		"badge_natural_width": true,
		"badge_fixed_width": ViewportRowBuilder.KIND_BADGE_WIDTH,
		"badge_bg": event_style.inspector_badge_background_color,
		"badge_fg": event_style.inspector_badge_foreground_color,
		"hover_note": EventSheetL10n.translate("A shared sheet: other sheets can include it.")
	}, true)))
	var includers: PackedStringArray = ViewportRowBuilder.NativeHeadMarks.includers_of(source_path)
	if not includers.is_empty():
		var includers_meta: Dictionary = name_meta.merged({
			"text_color": reading_style.muted_text_color,
			# The longest words on the head and the last of its sentence, so on a narrow dock they
			# are the ones that give way to the right-anchored echo - with an ellipsis, never sliced.
			"elide": true,
			# Named in the hover too, so a list the dock cut short is still one hover away.
			"hover_note": "%s %s" % [EventSheetL10n.translate("The sheets that include this one."),
				", ".join(includers)]
		}, true)
		if event_style.inspector_class_head:
			# The card's one aside, in italics like a variable's note.
			includers_meta["italic_note"] = true
		spans.append(_owner._make_span(EventSheetL10n.translate("Included by %s") % ", ".join(includers),
			SemanticSpan.SpanType.COMMENT, includers_meta))
	return spans


## The scene this script is attached to, at the right of the class head: "Scene gate.tscn". Only
## when exactly one scene runs it - the answer the head's lighting bands already ask for, so it costs
## no walk of its own - and never on a sheet with no file. A read-only preview says its scene on the
## head bar it opens on, so the class head inside that bar's fold does not say it twice.
##
## `hovered_facts` are the scene's facts a quiet class head keeps off the canvas ("spawns shot.tscn"):
## said in this hover, one per line, and a click on the scene shows it in the FileSystem dock.
static func _class_head_scene_spans(_owner: ViewportRowBuilder, sheet: EventSheetResource, band_meta: Dictionary, hovered_facts: PackedStringArray = PackedStringArray()) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	var source_path: String = str(sheet.external_source_path)
	if source_path.is_empty() or sheet.read_only:
		return spans
	var scene_path: String = EventSheetSceneLightingFacts.attached_scene(source_path)
	if scene_path.is_empty():
		return spans
	var reading_style: EventSheetReadingStyle = _owner._viewport._get_reading_style()
	var scene_note: String = EventSheetL10n.translate("The scene this script is attached to.")
	if not hovered_facts.is_empty():
		scene_note = "%s\n%s" % [scene_note, "\n".join(hovered_facts)]
	var scene_meta: Dictionary = band_meta.merged({
		"editable": false,
		"align_right": true,
		"hover_note": scene_note
	}, true)
	if _owner._viewport._get_event_style().inspector_class_head:
		# The scene's own gesture on a quiet head: show the file where it lives, the gesture the
		# spawns rows it stands in for had.
		scene_meta["head_action"] = "%s:%s" % [EventSheetHeadBands.BAND_SPAWNS, scene_path]
	spans.append(_owner._make_span(EventSheetL10n.translate("Scene"), SemanticSpan.SpanType.KEYWORD,
		scene_meta.merged({"text_color": reading_style.muted_text_color}, true)))
	spans.append(_owner._make_span(scene_path.get_file(), SemanticSpan.SpanType.COMMENT,
		scene_meta.merged({"text_color": reading_style.primary_text_color}, true)))
	return spans


## The `@tool` band's switch: a mark, never a word. Clicking it writes or removes the line.
static func _head_band_switch_span(_owner: ViewportRowBuilder, band_meta: Dictionary, switched_on: bool) -> SemanticSpan:
	var reading_style: EventSheetReadingStyle = _owner._viewport._get_reading_style()
	return _owner._make_span(
		ViewportRowBuilder.HEAD_SWITCH_ON_GLYPH if switched_on else ViewportRowBuilder.HEAD_SWITCH_OFF_GLYPH,
		SemanticSpan.SpanType.KEYWORD,
		band_meta.merged({
			"badge": true,
			"badge_style": "glyph",
			"badge_natural_width": true,
			"badge_fixed_width": ViewportRowBuilder.KIND_BADGE_WIDTH,
			"head_action": EventSheetHeadBands.BAND_TOOL,
			"badge_bg": reading_style.plain_chip_background_color,
			"badge_fg": reading_style.primary_text_color if switched_on else reading_style.muted_text_color,
			"hover_note": EventSheetL10n.translate("Runs in the editor too.")
		}, true)
	)


## The "+ add" row under the stack: the lines this sheet COULD have and does not, offered where the
## reader is already looking. Never autoload or host - those come from choosing a kind.
static func _build_head_add_row(_owner: ViewportRowBuilder, sheet: EventSheetResource, add_text: String) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = 0
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = "%sadd_%d" % [ViewportRowBuilder.HEAD_BAND_UID_PREFIX, sheet.get_instance_id()]
	row_data.folded = false
	row_data.spans = [
		_owner._make_span(add_text, SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "head_band_add",
			"head_band": "add",
			"head_action": "add",
			"line_index": 0,
			"text_color": _owner._viewport._get_reading_style().muted_text_color
		})
	]
	return row_data


## The head bar's "Runs in the editor" chip: a `@tool` script's one fact about when it runs, in the
## theme's violet pair - the one the range tile wears, which every theme derives for its dark and its
## light ground.
static func _runs_in_editor_chip_span(_owner: ViewportRowBuilder, meta: Dictionary, editable: bool) -> SemanticSpan:
	var event_style: EventSheetEventStyle = _owner._viewport._get_event_style()
	var hover: String = "%s\n\n@tool" % EventSheetL10n.translate("Runs in the editor too.")
	var chip_meta: Dictionary = meta.merged({
		"badge": true,
		"badge_style": "scope",
		"badge_natural_width": true,
		"badge_bg": event_style.range_badge_background_color,
		"badge_fg": event_style.range_badge_foreground_color,
		"hover_note": hover,
	}, true)
	if editable:
		chip_meta["head_action"] = EventSheetHeadBands.BAND_EXTENDS
		chip_meta["hover_note"] = "%s\n%s" % [hover, EventSheetL10n.translate("Click to change what kind of script it is.")]
	return _owner._make_span(EventSheetL10n.translate("Runs in the editor"), SemanticSpan.SpanType.KEYWORD, chip_meta)


## THE ONE HEAD BAR: `▣ Player extends CharacterBody2D · reads as events · 4 input actions ·
## 1 variable · 2 script blocks`, with every bar it stands for hanging under its ▸.
##
## Six bars said what one line can. Each fact here is COUNTED FROM the bar it folds - the input
## count is that bar's own members, the variable count is the variables bar's - so the line and the
## fold can never disagree, and the doors survive: the base class opens the base script, the
## coverage walks the script blocks, and the ▸ brings back the Input bar and the variables bar with
## everything they always said.
##
## A GROUP row, so the fold, the arrow and the remembered state are the sheet's own machinery rather
## than a second one written here. Inert (null source): nothing about it is stored, and an opened
## file still re-emits byte for byte.
static func _build_one_head_bar_row(_owner: ViewportRowBuilder, sheet: EventSheetResource, detail: Array[EventRowData], input_bars: Array[EventRowData], knob_bars: Array[EventRowData]) -> EventRowData:
	var reading_style: EventSheetReadingStyle = _owner._viewport._get_reading_style()
	var row_data := EventRowData.new()
	row_data.indent = 0
	row_data.row_type = EventRowData.RowType.GROUP
	row_data.source_resource = null
	row_data.row_uid = "sheet_head_bar_%d" % sheet.get_instance_id()
	# The bands the bar quotes fold under it, closed, and the bar is one row tall and flat with
	# nothing trailing it - the shape an Include row has in every other event-sheet editor.
	row_data.children = detail
	row_data.folded = bool(_owner._viewport._fold_state.get(row_data.row_uid, true))
	row_data.custom_color = _owner._viewport._get_event_style().head_bar_color
	var bar_meta: Dictionary = {"editable": false, "kind": "head_bar", "line_index": 0}
	# What the class extends is read off the class head row, which carries the extends band's words.
	var extends_word: String = _head_band_value_of(_owner, _head_band_row(_owner, detail, EventSheetHeadBands.BAND_NAME),
		EventSheetHeadBands.BAND_EXTENDS)
	var spans: Array[SemanticSpan] = [_head_band_icon_span(_owner, bar_meta, EventSheetHeadBands.BAND_NAME,
		EventSheetACEIcons.editor_icon(extends_word) if not extends_word.is_empty() else null,
		EventSheetL10n.translate("What this file is. ▸ opens the lines behind it."))]
	var class_word: String = _head_band_value(_owner, _head_band_row(_owner, detail, EventSheetHeadBands.BAND_NAME))
	if not class_word.is_empty():
		spans.append(_owner._make_span(class_word, SemanticSpan.SpanType.OBJECT, bar_meta.merged({
			"text_color": _owner._viewport._get_event_style().object_label_color
		}, true)))
	if not extends_word.is_empty():
		spans.append(_owner._make_span(str(EventSheetHeadBands.LEADERS[EventSheetHeadBands.BAND_EXTENDS]),
			SemanticSpan.SpanType.KEYWORD, bar_meta.merged({
				"text_color": reading_style.muted_text_color
			}, true)))
		# The base class keeps its door: a base that is another SCRIPT of this project opens as its
		# own sheet, which is the one gesture the second Include bar existed for.
		var base_path: String = ViewportRowBuilder.base_script_path(sheet)
		var base_meta: Dictionary = bar_meta.merged({
			"text_color": reading_style.primary_text_color
		}, true)
		if not base_path.is_empty():
			base_meta["kind"] = "include_open"
			base_meta["include_path"] = base_path
			base_meta["hover_note"] = EventSheetL10n.translate("Open the base script as a sheet.")
		spans.append(_owner._make_span(extends_word, SemanticSpan.SpanType.VALUE, base_meta))
	var muted_meta: Dictionary = bar_meta.merged({"text_color": reading_style.muted_text_color}, true)
	# A file that reads whole says nothing about it: the only coverage word left is the count of
	# blocks that did NOT arrive as events, below, which still walks them one per click.
	var coverage_meta: Dictionary = muted_meta.merged({"kind": "reading_coverage"}, true)
	var actions: int = 0
	for bar: EventRowData in input_bars:
		actions += bar.children.size()
	if actions > 0:
		spans.append(_owner._make_span("· %s" % (EventSheetL10n.translate("1 input action") if actions == 1 \
			else EventSheetL10n.translate("%d input actions") % actions),
			SemanticSpan.SpanType.COMMENT, muted_meta.merged({"kind": "head_bar_input"}, true)))
	var variables: int = 0
	for bar: EventRowData in knob_bars:
		variables += bar.children.size()
	if variables > 0:
		spans.append(_owner._make_span("· %s" % (EventSheetL10n.translate("1 variable") if variables == 1 \
			else EventSheetL10n.translate("%d variables") % variables),
			SemanticSpan.SpanType.COMMENT, muted_meta.merged({"kind": "head_bar_variables"}, true)))
	var blocks: int = int(EventSheetReadingCoverage.measure(sheet).get("block_rows", 0))
	if blocks > 0:
		spans.append(_owner._make_span("· %s" % (EventSheetL10n.translate("1 script block") if blocks == 1 \
			else EventSheetL10n.translate("%d script blocks") % blocks),
			SemanticSpan.SpanType.COMMENT, coverage_meta))
	row_data.spans = spans
	# THE QUIET SHEET, at the head: a control this file asks for that the project has not got used to
	# put a warning mark and a sentence inside the Input bar. It is a finding, so the bar says nothing
	# at all now - the head bar wears the amber state, the sentence is read in the help strip once the
	# bar is selected, and the Doctor's inbox carries the same line with the fix beside it.
	var head_findings: Array[Dictionary] = _owner._tagged(ViewportRowBuilder.FINDINGS_INPUT, _owner._sheet_findings(ViewportRowBuilder.FINDINGS_INPUT))
	head_findings.append_array(_owner._tagged(ViewportRowBuilder.FINDINGS_INCLUDES, _owner._sheet_findings(ViewportRowBuilder.FINDINGS_INCLUDES)))
	_owner._stamp_attention(row_data, head_findings)
	return row_data


## The head band row of one kind among the rows about to be folded under the bar, or null when the
## file has no such line - which is how the bar quotes the bands rather than re-deriving what they
## already read out of the file.
static func _head_band_row(_owner: ViewportRowBuilder, rows: Array[EventRowData], band_kind: String) -> EventRowData:
	var prefix: String = "%s%s" % [ViewportRowBuilder.HEAD_BAND_UID_PREFIX, band_kind]
	for row_data: EventRowData in rows:
		if row_data.row_uid.begins_with(prefix):
			return row_data
	return null


## One band's own words - its VALUE span, which is the fact rather than the leader word, the badge or
## the echo. "" for a band that is not there.
static func _head_band_value(_owner: ViewportRowBuilder, row_data: EventRowData) -> String:
	if row_data == null:
		return ""
	for span: SemanticSpan in row_data.spans:
		if span.type == SemanticSpan.SpanType.VALUE:
			return span.text
	return ""


## The VALUE words a head row carries for one band - the extends band's base class on the class
## head row, which draws two bands' words. "" when the row or the band is not there.
static func _head_band_value_of(_owner: ViewportRowBuilder, row_data: EventRowData, band_kind: String) -> String:
	if row_data == null:
		return ""
	for span: SemanticSpan in row_data.spans:
		if span.type == SemanticSpan.SpanType.VALUE and span.metadata is Dictionary \
				and str((span.metadata as Dictionary).get("head_band", "")) == band_kind:
			return span.text
	return ""


## The file's `##` prose as the COMMENT row it is, at the top of the sheet and drawn once. Inert
## (null source, nothing to edit through it on a read-only preview) and wrapping, because a class
## description is a sentence rather than a label.
## The whole `##` block as one sentence, "" for a file whose only `##` line is an annotation and for
## a file with no prose at all. The BAND's value is one line by design (a band stands for one line of
## the file); a comment row stands for the block, so the block is what it says - joined with spaces,
## because a paragraph broken across `## ` lines is one sentence to everybody but the parser.
static func _head_description_text(_owner: ViewportRowBuilder, sheet: EventSheetResource, band_value: String) -> String:
	if band_value.is_empty() or band_value.begins_with("@"):
		return ""
	var block: String = sheet.class_description.strip_edges()
	if block.is_empty() or EventSheetHeadBands.description_line(block) != band_value:
		return band_value
	var lines: PackedStringArray = PackedStringArray()
	for line: String in block.split("\n"):
		var said: String = line.strip_edges()
		if not said.is_empty() and not said.begins_with("@"):
			lines.append(said)
	return " ".join(lines)


static func _build_head_description_row(_owner: ViewportRowBuilder, sheet: EventSheetResource, described: String) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = 0
	row_data.row_type = EventRowData.RowType.COMMENT
	row_data.source_resource = null
	# Deliberately NOT `sheet_head_description_…`: that is the description BAND's own uid, and two
	# rows sharing one key would let a fold state written for one be read back for the other.
	row_data.row_uid = "head_description_row_%d" % sheet.get_instance_id()
	row_data.spans = [
		_owner._make_span(described, SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "head_description",
			"line_index": 0,
			"text_color": _owner._viewport._get_event_style().comment_text_color
		})
	]
	return row_data


## The prose of a comment-only block, "" when it carries only `## @ace_*` annotations (which say
## nothing to a reader) - what a stray doc comment above a variable contributes as its description.
static func _head_comment_text(_owner: ViewportRowBuilder, code_lines: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for line: String in code_lines:
		var stripped: String = line.strip_edges()
		if stripped.is_empty() or ViewportRowBuilder.is_ace_annotation_line(stripped):
			continue
		parts.append(ViewportRowBuilder.strip_comment_prefix(stripped).strip_edges())
	return " ".join(parts).strip_edges()


## What the opened file is as a PACKAGE, in the slot an event sheet uses for its "Include: Sheet"
## strip: `⇥ Addon Pack [v1.0.0] behaves on a [CharacterBody3D]  reads as events ▸`, and for any
## other script its receipts and coverage - `⇥ · player.gd · scene Player.tscn  96% reads as events ▸`.
##
## The file's own IDENTITY is not here: `class_name`, `extends`, `@tool` and an autoload's name
## are lines of the file, and the band stack above states each of them once, with its own echo and
## its own control. This bar says only what no line says - the version, the host it behaves on, how
## much of it read as events, which file it is - so nothing on the head is stated twice.
##
## Inert (null source) and wearing the same accent band + 1.5x presence the Class setup and Host
## binding bars wore, because it replaces both of them on a read-only preview.
static func _build_pack_include_bar_row(_owner: ViewportRowBuilder, sheet: EventSheetResource, host_class: String) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = 0
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = "pack_include_bar_%d" % sheet.get_instance_id()
	row_data.height_scale = 1.5
	var accent: Color = _owner._viewport._get_event_style().behavior_accent_color
	row_data.custom_color = Color(accent.r, accent.g, accent.b, 0.22)
	var badge_meta: Dictionary = {
		"editable": false,
		"badge": true,
		"badge_style": "trigger",
		"badge_bg": _owner._viewport._get_reading_style().setup_badge_background_color,
		"badge_fg": _owner._viewport._get_reading_style().setup_badge_foreground_color,
		"kind": "pack_include",
		"line_index": 0
	}
	var icon_class: String = host_class if not host_class.is_empty() else sheet.host_class
	var identity_icon: Texture2D = EventSheetACEIcons.editor_icon(icon_class) if not icon_class.is_empty() else null
	if identity_icon != null:
		badge_meta["badge_icon"] = identity_icon
	var spans: Array[SemanticSpan] = [_owner._make_span("⇥", SemanticSpan.SpanType.KEYWORD, badge_meta)]
	spans.append_array(_script_include_spans(_owner, sheet))
	# What every shape of the bar ends with, in one place: how much of the file read as events, the
	# buttons a tool sheet is run from, and - only inside this plugin's own repo - the bar a file of
	# the RUNNING editor wears. Each is silent for the files it has nothing to say about.
	spans.append_array(_reading_coverage_spans(_owner, sheet))
	spans.append_array(_owner._editor_tool_bar_spans(sheet))
	spans.append_array(_owner._this_editor_bar_spans(sheet))
	row_data.spans = spans
	return row_data


## The two things a reader wants to know about an opened file before reading a line of it: how
## much of it arrived as events, and whether it even compiles.
##
## The coverage chip (`96% reads as events · 3 script blocks ▸`) is measured by the SAME static the
## corpus gate measures with, so the chip and the test can never disagree about the same file; a
## click walks the script blocks one at a time. A fully-lifted file drops the number and just says
## `reads as events`. The error line is the ENGINE's own count, in red, saying what it costs - a
## script that does not parse does not run, and that is worth more than any styling.
static func _reading_coverage_spans(_owner: ViewportRowBuilder, sheet: EventSheetResource) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	var errors: String = EventSheetReadingCoverage.parse_error_text(sheet)
	if not errors.is_empty():
		spans.append(_owner._make_span(errors, SemanticSpan.SpanType.VALUE, {
			"editable": false, "kind": "pack_include", "line_index": 0,
			"text_color": _owner._viewport._get_reading_style().error_text_color
		}))
	var coverage: String = EventSheetReadingCoverage.chip_text(sheet)
	if coverage.is_empty():
		return spans
	spans.append(_owner._make_span(coverage, SemanticSpan.SpanType.KEYWORD, {
		"editable": false,
		"badge": true,
		"badge_style": "scope",
		"badge_bg": _owner._viewport._get_reading_style().plain_chip_background_color,
		"badge_fg": _owner._viewport._get_reading_style().plain_chip_foreground_color,
		"kind": "reading_coverage",
		"line_index": 0
	}))
	return spans


## The scene's own bar, at the top of a scene view: the same 30 px grey head bar a script opens on -
## the root's icon, the scene's file name, `Scene · root Node2D`, and on the right how many scripts it
## uses, whose card names them. Inert: there is nothing to edit on it.
static func build_scene_bar_row(_owner: ViewportRowBuilder, sheet: EventSheetResource) -> EventRowData:
	var event_style: EventSheetEventStyle = _owner._viewport._get_event_style()
	var reading_style: EventSheetReadingStyle = _owner._viewport._get_reading_style()
	var row_data := EventRowData.new()
	row_data.indent = 0
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = "scene_bar_%d" % sheet.get_instance_id()
	row_data.fixed_height = ViewportRowBuilder.SHEET_HEAD_BAR_HEIGHT
	row_data.custom_color = event_style.head_bar_color
	row_data.outline_color = event_style.head_bar_color
	row_data.outline_radius = ViewportRowBuilder.HEAD_BAR_RADIUS
	row_data.outline_width = 1.0
	var meta: Dictionary = {"editable": false, "kind": "sheet_head", "line_index": 0}
	var root_type: String = EventSheetSceneSheet.root_type_of(sheet)
	var icon_meta: Dictionary = meta.merged({
		"badge": true,
		"badge_style": "glyph",
		"badge_natural_width": true,
		"badge_fixed_width": ViewportRowBuilder.KIND_BADGE_WIDTH,
		"badge_fg": reading_style.primary_text_color,
	}, true)
	var root_icon: Texture2D = EventSheetACEIcons.editor_icon(root_type) if not root_type.is_empty() else null
	if root_icon != null:
		icon_meta["badge_icon"] = root_icon
	var spans: Array[SemanticSpan] = [_owner._make_span("◆", SemanticSpan.SpanType.KEYWORD, icon_meta)]
	var scene_name: String = EventSheetSceneSheet.scene_path_of(sheet).get_file()
	spans.append(_owner._make_span(scene_name, SemanticSpan.SpanType.OBJECT, meta.merged({
		"text_color": reading_style.primary_text_color,
		"bbcode_segments": [{"text": scene_name, "color": reading_style.primary_text_color, "bold": true, "italic": false}],
		"hover_note": EventSheetL10n.translate(
			"Every script this scene uses, in tree order. Click a script's file on its bar to open it and edit it."),
	}, true)))
	if not root_type.is_empty():
		spans.append(_owner._make_span("%s · %s" % [EventSheetL10n.translate("Scene"), EventSheetL10n.translate("root")],
			SemanticSpan.SpanType.KEYWORD, meta.merged({"text_color": reading_style.muted_text_color}, true)))
		spans.append(_owner._make_span(root_type, SemanticSpan.SpanType.VALUE,
			meta.merged({"text_color": reading_style.primary_text_color}, true)))
	var nodes: PackedStringArray = PackedStringArray()
	for entry: Variant in EventSheetSceneSheet.members_of(sheet):
		var member_sheet: EventSheetResource = (entry as Dictionary).get("sheet") as EventSheetResource
		var bar: Dictionary = EventSheetSceneSheet.object_bar_of(member_sheet)
		nodes.append("%s (%s)" % [str(bar.get("node", "")), str(bar.get("script_path", "")).get_file()] if not bar.is_empty()
			else str((entry as Dictionary).get("script_path", "")).get_file())
	var scripts: int = EventSheetSceneSheet.members_of(sheet).size()
	spans.append(_owner._make_span(EventSheetL10n.translate("1 script") if scripts == 1
		else EventSheetL10n.translate("{n} scripts").replace("{n}", str(scripts)),
		SemanticSpan.SpanType.COMMENT, meta.merged({
			"kind": "sheet_head_count",
			"align_right": true,
			"text_color": reading_style.muted_text_color,
			"hover_card_mark": true,
			"head_card": {"id": "scripts", "title": EventSheetL10n.translate("Scripts in this scene"),
				"lines": PackedStringArray(["%s." % ", ".join(nodes)]), "width": ViewportRowBuilder.HEAD_CARD_COUNT_WIDTH, "anchor": "right"},
		}, true)))
	row_data.spans = spans
	return row_data


## What an opened script is BEYOND its own first lines: the shape it plays in this project (a
## data type, a behavior, a store, a page of the vocabulary, an editor add-on and its constant facts),
## whatever it is as tooling, and the receipts - `⇥ data type · item.gd`, `⇥ · player.gd · scene
## Player.tscn`.
##
## The NAME and the class are not here: `class_name` and `extends` are lines of the file, and the
## band stack above states each of them once, with its own control and its own echo. What is left is
## what no line of the file says.
static func _script_include_spans(_owner: ViewportRowBuilder, sheet: EventSheetResource) -> Array[SemanticSpan]:
	var source_path: String = str(sheet.external_source_path)
	# Inside a scene view this bar is the OBJECT bar of the node carrying the script, so it says
	# what the scene tree says ("HUD a CanvasLayer") and skips the scene receipt: the whole sheet is
	# that one scene already. A node's NAME is a fact of the SCENE rather than a line of the script, so
	# this is the one shape that still leads with an identity. Double-click opens the script as its
	# own sheet.
	var object_bar: Dictionary = EventSheetSceneSheet.object_bar_of(sheet)
	if not object_bar.is_empty():
		return _scene_object_bar_spans(_owner, object_bar, _owner._viewport._get_event_style())
	var base_class: String = sheet.host_class.strip_edges()
	var scene: Dictionary = ViewportRowBuilder.scene_using_script(source_path) if not source_path.is_empty() else {}
	var spans: Array[SemanticSpan] = []
	# A script with no `class_name` is known by the NODE that runs it: "SpawnerPad" is what its
	# author calls this thing. That name is a fact of the SCENE rather than a line of the file, so it
	# is this bar's to say; a file that declares a class is named by its name band instead.
	var scene_name: String = str(scene.get("root_name", "")).strip_edges() \
		if sheet.custom_class_name.strip_edges().is_empty() else ""
	if not scene_name.is_empty():
		spans.append(_owner._make_span(scene_name, SemanticSpan.SpanType.OBJECT, {
			"editable": false, "kind": "pack_include", "line_index": 0,
			"text_color": _owner._viewport._get_event_style().object_label_color
		}))
	# ───────────────────────────────────────────────────────────────────────────────────────
	# A script that extends a Resource is not an object in the scene: it is a DATA TYPE, and every
	# .tres saved from it is one asset of that type. `extends Resource` is the line; this is the word
	# a designer would use for what that line makes.
	if EventSheetScriptIntent.is_resource_host(base_class):
		spans.append(_pack_include_chip(_owner, EventSheetL10n.translate("data type")))
		return _append_include_receipts(_owner, spans, source_path, {})
	# ─────────────────────────────────────────────────────────────────────────────────────
	# What this file IS to the editor it is part of, said instead of the class it happens to extend: a
	# behavior of the object it was made with, a store nothing is ever made of, or a page of the
	# vocabulary. All three replace "a RefCounted", which is the least useful true thing about them.
	var tool_shape: Array[SemanticSpan] = _owner._tool_shape_spans(sheet)
	if not tool_shape.is_empty():
		spans.append_array(tool_shape)
		return _append_include_receipts(_owner, spans, source_path, {})
	# ─────────────────────────────────────────────────────────────────────────────────────
	# A script extending one of the editor's plugin classes states the questions with constant answers
	# as the facts they are: an EditorPlugin's name, its main screen and its icon are three lines of
	# code that say one thing each, and reading them as three events would be reading three lies.
	if EventSheetEditorPluginWords.is_editor_plugin_class(base_class):
		spans.append(_owner._make_span(" · ".join(_editor_plugin_head_facts(_owner, sheet, base_class)),
			SemanticSpan.SpanType.COMMENT, {
				"editable": false, "kind": "pack_include", "line_index": 0,
				"text_color": _owner._viewport._get_reading_style().muted_text_color
			}))
	# ── lens hook ──────────────────────────────────────────────────────────────────────────
	# What this file is as a piece of TOOLING, in the same chips: a test sheet and how many checks it
	# makes, a command tool that runs headless, a pack recipe and the behavior it builds. A recipe's
	# sheet-level property writes are FACTS about the pack, so they read here rather than as rows.
	spans.append_array(_owner._tool_file_chip_spans(sheet, source_path))
	return _append_include_receipts(_owner, spans, source_path, scene)


## The muted receipts every shape of the bar ends with, as one span: which file this is, and the scene
## that runs it. One place, because "which file am I looking at" is the same question in all of them.
static func _append_include_receipts(_owner: ViewportRowBuilder, spans: Array[SemanticSpan], source_path: String, scene: Dictionary) -> Array[SemanticSpan]:
	var receipts: PackedStringArray = PackedStringArray()
	if not source_path.is_empty():
		receipts.append("· %s" % source_path.get_file())
	if not scene.is_empty():
		receipts.append("· %s %s" % [EventSheetL10n.translate("scene"), str(scene.get("scene_path", "")).get_file()])
	if receipts.is_empty():
		return spans
	spans.append(_owner._make_span(" ".join(receipts), SemanticSpan.SpanType.COMMENT, {
		"editable": false, "kind": "pack_include", "line_index": 0,
		"text_color": _owner._viewport._get_reading_style().muted_text_color
	}))
	return spans


## The facts an editor add-on's head bar states, in reading order: what kind of add-on it
## is, then whatever its constant-answer virtuals answer. `editor plugin · main screen "EventSheet"
## · icon eventsheet.svg` for a plugin that owns a workspace, and just `editor plugin` for one that
## does not - a main-screen line on a plugin with no main screen would be a fact it never claimed.
static func _editor_plugin_head_facts(_owner: ViewportRowBuilder, sheet: EventSheetResource, host_class: String) -> PackedStringArray:
	var facts: PackedStringArray = PackedStringArray([
		EventSheetL10n.translate(EventSheetEditorPluginWords.head_word_for(host_class))
	])
	match host_class:
		"EditorPlugin":
			if _constant_return_of(_owner, sheet, "_has_main_screen") == "true":
				var screen_name: String = _constant_return_of(_owner, sheet, "_get_plugin_name")
				if not screen_name.is_empty():
					facts.append("%s %s" % [EventSheetL10n.translate("main screen"), screen_name])
			var icon_file: String = _first_quoted_file(_owner, sheet, "_get_plugin_icon")
			if not icon_file.is_empty():
				facts.append("%s %s" % [EventSheetL10n.translate("icon"), icon_file])
		"EditorImportPlugin":
			var importer_name: String = _constant_return_of(_owner, sheet, "_get_visible_name")
			if importer_name.is_empty():
				importer_name = _constant_return_of(_owner, sheet, "_get_importer_name")
			if not importer_name.is_empty():
				facts.append("%s %s" % [EventSheetL10n.translate("named"), importer_name])
	# The receipt that says who registered this add-on with the editor, found by reading the plugins
	# of THIS project - never a guess, and silent when no file of this project registers it.
	var owner: String = EventSheetEditorPluginWords.added_by(str(sheet.custom_class_name).strip_edges())
	if not owner.is_empty():
		facts.append("%s %s ▸ %s" % [
			EventSheetL10n.translate("added by"), owner, EventSheetL10n.translate("On plugin enabled")
		])
	return facts


## The one value a constant-answer virtual answers with, as the file writes it (`"EventSheet"`,
## `true`) - "" when the sheet has no such function or its body does more than answer.
static func _constant_return_of(_owner: ViewportRowBuilder, sheet: EventSheetResource, function_name: String) -> String:
	# The one-line body of a constant-answer virtual lifts to a Return Value row inside an event, so
	# the answer is a parameter rather than a line of text - read it there first, and fall back to the
	# raw text below for a body the lifter left alone.
	for entry: Variant in _function_body_entries(_owner, sheet, function_name):
		var steps: Array = (entry as EventRow).actions if entry is EventRow else [entry]
		for step: Variant in steps:
			if not (step is ACEAction) or (step as ACEAction).ace_id != "ReturnValue":
				continue
			var params: Dictionary = (step as ACEAction).params
			if params.is_empty():
				params = (step as ACEAction).parameters
			return str(params.get("value", "")).strip_edges()
	for line: String in _owner._function_body_lines(sheet, function_name):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("return "):
			return stripped.substr(7).strip_edges()
	return ""


## The FILE NAME of the first quoted res:// path a function names - what `_get_plugin_icon` is for,
## where the value is behind a `load()` and the folder it lives in is filing rather than a fact.
static func _first_quoted_file(_owner: ViewportRowBuilder, sheet: EventSheetResource, function_name: String) -> String:
	var searched: PackedStringArray = PackedStringArray([_constant_return_of(_owner, sheet, function_name)])
	searched.append_array(_owner._function_body_lines(sheet, function_name))
	for line: String in searched:
		var at: int = line.find("\"res://")
		if at < 0:
			continue
		var rest: String = line.substr(at + 1)
		var close_at: int = rest.find("\"")
		if close_at > 0:
			return rest.substr(0, close_at).get_file()
	return ""


## One of the sheet's functions as the resources its body is made of, in file order. Empty when the
## sheet declares no such function.
static func _function_body_entries(_owner: ViewportRowBuilder, sheet: EventSheetResource, function_name: String) -> Array:
	if sheet == null:
		return []
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			var body: Array = (entry as EventFunction).events
			return body if not body.is_empty() else (entry as EventFunction).rows
	return []


## One node's object bar inside a scene view: the node's own name, the class it is, the file its
## script lives in, and "(x3)" when the same script sits on more than one node of this scene. Every
## span carries the script path, so a double-click anywhere on the bar opens that file as its own
## sheet - which is where editing happens, because a scene view never writes anything.
static func _scene_object_bar_spans(_owner: ViewportRowBuilder, object_bar: Dictionary, event_style: EventSheetEventStyle) -> Array[SemanticSpan]:
	var script_path: String = str(object_bar.get("script_path", ""))
	var open_meta: Dictionary = {
		"editable": false,
		"kind": "scene_object_open",
		"include_path": script_path,
		"line_index": 0
	}
	var spans: Array[SemanticSpan] = []
	spans.append(_owner._make_span(str(object_bar.get("node", "")), SemanticSpan.SpanType.OBJECT,
		open_meta.duplicate().merged({"text_color": event_style.object_label_color}, true)))
	var node_type: String = str(object_bar.get("type", ""))
	if not node_type.is_empty():
		spans.append(_owner._make_span(EventSheetL10n.translate("a"), SemanticSpan.SpanType.VALUE,
			open_meta.duplicate().merged({"text_color": _owner._viewport._get_reading_style().muted_text_color}, true)))
		spans.append(_owner._make_span(node_type, SemanticSpan.SpanType.KEYWORD, open_meta.duplicate().merged({
			"badge": true,
			"badge_style": "scope",
			"badge_bg": _owner._viewport._get_reading_style().plain_chip_background_color,
			"badge_fg": _owner._viewport._get_reading_style().plain_chip_foreground_color
		}, true)))
	var receipt: String = "· %s" % script_path.get_file()
	var instances: int = int(object_bar.get("instances", 1))
	if instances > 1:
		receipt += " (x%d)" % instances
	spans.append(_owner._make_span(receipt, SemanticSpan.SpanType.COMMENT,
		open_meta.duplicate().merged({"text_color": _owner._viewport._get_reading_style().muted_text_color}, true)))
	return spans


## The second head bar: `⇥ Include <base.gd> - open as a sheet`. Null when the base is an engine
## class. Inert as a resource (a lens over the `extends` line, which stays exactly where it is); the
## chip carries the path so opening it goes through the same jump the rest of the canvas uses.
static func _build_base_script_include_bar_row(_owner: ViewportRowBuilder, sheet: EventSheetResource) -> EventRowData:
	var base_path: String = ViewportRowBuilder.base_script_path(sheet)
	if base_path.is_empty():
		return null
	var row_data := EventRowData.new()
	row_data.indent = 0
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = "base_include_bar_%d" % sheet.get_instance_id()
	# Flat and pill-free, the way every head line is drawn: the tint says "the head", the words
	# say the rest. A shared sheet wired as the base is drawn by _build_include_line_rows instead,
	# which also says which wiring it is.
	for include: Dictionary in _owner._includes_of(sheet):
		if str(include["wiring"]) == EventSheetSharedSheets.WIRING_BASE_CLASS:
			return null
	var inks: Dictionary = _include_line_inks(_owner, row_data)
	var open_meta: Dictionary = {
		"editable": false,
		"kind": "include_open",
		"include_path": base_path,
		"line_index": 0
	}
	var spans: Array[SemanticSpan] = [
		_owner._make_span("⇥", SemanticSpan.SpanType.KEYWORD, open_meta.duplicate().merged({"text_color": inks["arrow"]}, true)),
		_owner._make_span(_owner._include_word(), SemanticSpan.SpanType.VALUE, open_meta.duplicate().merged({
			"text_color": inks["tag"]
		}, true)),
		_owner._make_span(base_path.get_file(), SemanticSpan.SpanType.KEYWORD, open_meta.duplicate().merged({
			"text_color": inks["name"]
		}, true)),
		_owner._make_span(EventSheetL10n.translate("- open as a sheet"), SemanticSpan.SpanType.COMMENT,
			open_meta.duplicate().merged({"text_color": inks["note"]}, true))
	]
	row_data.spans = spans
	return row_data


## Dresses an Include line in the theme's Include colours and returns the inks for its words:
## {arrow, tag, name, note}. Each Include token the theme leaves clear keeps the head bar look - the
## head bar fill, no edge, the primary ink on the word, the object ink on the name, muted ink on the
## arrow and the note - so a theme saved before the tokens existed draws the line as it always did.
static func _include_line_inks(_owner: ViewportRowBuilder, row_data: EventRowData) -> Dictionary:
	var event_style: EventSheetEventStyle = _owner._viewport._get_event_style()
	var reading: EventSheetReadingStyle = _owner._viewport._get_reading_style()
	row_data.custom_color = EventSheetEventStyle.stated_or(event_style.include_fill_color, event_style.head_bar_color)
	row_data.outline_color = event_style.include_border_color
	if event_style.include_border_color.a > 0.01:
		# A theme that states the Include edge draws the line as a rounded bar, a little taller than
		# a row so the bar's ends read as round.
		row_data.outline_radius = ViewportRowBuilder.INCLUDE_BAR_RADIUS
		row_data.height_scale = ViewportRowBuilder.INCLUDE_BAR_HEIGHT_SCALE
	return {
		"arrow": EventSheetEventStyle.stated_or(event_style.include_tag_color, reading.muted_text_color),
		"tag": EventSheetEventStyle.stated_or(event_style.include_tag_color, reading.primary_text_color),
		"name": EventSheetEventStyle.stated_or(event_style.include_name_color, event_style.object_label_color),
		"note": EventSheetEventStyle.stated_or(event_style.include_note_color, reading.muted_text_color),
	}


## The variables an included shared sheet declares, one read-only row each under its Include bar,
## drawn dashed and named by where they come from: `int health = 100  from EnemyCommon`. They are
## the included sheet's own, so nothing about them is editable here - one click opens the sheet that
## declares them, the same door the bar is.
static func _build_included_variable_rows(_owner: ViewportRowBuilder, sheet: EventSheetResource, include: Dictionary, indent: int) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	var include_path: String = str(include["path"])
	var event_style: EventSheetEventStyle = _owner._viewport._get_event_style()
	var reading_style: EventSheetReadingStyle = _owner._viewport._get_reading_style()
	var muted: Color = reading_style.muted_text_color
	var edge: Color = EventSheetEventStyle.stated_or(event_style.include_border_color,
		Color(muted.r, muted.g, muted.b, muted.a * 0.6))
	var tag: Color = EventSheetEventStyle.stated_or(event_style.include_tag_color, muted)
	for variable: Dictionary in ViewportRowBuilder.NativeHeadMarks.shared_variables(include_path):
		var row_data := EventRowData.new()
		row_data.indent = indent
		row_data.row_type = EventRowData.RowType.SECTION
		row_data.source_resource = null
		row_data.row_uid = "include_variable_%s_%s_%d" % [str(include["class"]), str(variable["name"]),
			sheet.get_instance_id()]
		row_data.variable_row = true
		row_data.outline_color = edge
		row_data.outline_dashed = true
		var meta: Dictionary = {"editable": false, "kind": "include_variable", "include_path": include_path,
			"line_index": 0,
			"hover_note": EventSheetL10n.translate("A variable of the included sheet, read-only here. Click to open that sheet.")}
		var type_text: String = str(variable["type"])
		var value_text: String = str(variable["value"])
		if not type_text.is_empty():
			row_data.spans.append(_owner._make_span(type_text, SemanticSpan.SpanType.KEYWORD, meta.merged({
				"variable_type_span": true,
				"variable_type_family": ViewportRowBuilder.NativeVariableMarks.type_family(type_text, value_text, true),
				"text_color": reading_style.secondary_text_color
			}, true)))
		row_data.spans.append(_owner._make_span(str(variable["name"]), SemanticSpan.SpanType.OBJECT, meta.merged({
			"text_color": event_style.object_label_color
		}, true)))
		if not value_text.is_empty():
			row_data.spans.append(_owner._make_span("=", SemanticSpan.SpanType.OPERATOR, meta.merged({"text_color": muted}, true)))
			row_data.spans.append(_owner._make_span(value_text, SemanticSpan.SpanType.VALUE, meta.merged({
				"text_color": event_style.value_highlight_color
			}, true)))
		row_data.spans.append(_owner._make_span(EventSheetL10n.translate("from %s") % str(include["class"]),
			SemanticSpan.SpanType.COMMENT, meta.merged({"text_color": tag}, true)))
		rows.append(row_data)
	return rows


static func _parent_chain_stamp(_owner: ViewportRowBuilder, parent_text: String, classes: Dictionary, kinds: GDScript) -> String:
	var stamp: String = ""
	var walk: String = parent_text
	var guard: int = 0
	while classes.has(walk) and guard < 32:
		guard += 1
		var path: String = str((classes[walk] as Dictionary).get("path", ""))
		stamp += "%s@%d;" % [path, FileAccess.get_modified_time(path)]
		walk = kinds.parent_of(walk, classes)
	return stamp


static func _pack_include_chip(_owner: ViewportRowBuilder, text: String, chip_kind: String = "pack_include") -> SemanticSpan:
	# A plain word, muted, on the bar's one line. It used to be a filled pill, and a head made of
	# pills read as a row of buttons on a sheet that draws none; a word says the same thing quietly.
	return _owner._make_span(text, SemanticSpan.SpanType.KEYWORD, {
		"editable": false,
		"kind": chip_kind,
		"line_index": 0,
		"text_color": _owner._viewport._get_reading_style().muted_text_color
	})


## Index of the pack's about text among the already-built rows - the class doc a pack repeats at the
## END of its file, which reads there as a grey wall nobody scrolls to. Only the LAST content row
## qualifies, and only when it is a paragraph rather than a note about the code above it.
static func _pack_about_row_index(_owner: ViewportRowBuilder, rows: Array[EventRowData], from_index: int) -> int:
	for index in range(rows.size() - 1, maxi(from_index, 0) - 1, -1):
		var row_data: EventRowData = rows[index]
		if row_data.source_resource is RawCodeRow and ViewportRowBuilder.is_blank_block((row_data.source_resource as RawCodeRow).code.split("\n")):
			continue
		if row_data.row_type == EventRowData.RowType.COMMENT and row_data.source_resource is CommentRow \
				and (row_data.source_resource as CommentRow).text.strip_edges().length() >= 60:
			return index
		return -1
	return -1


## One global's muted line in the folder: what it is declared as, and on which autoload. A global
## the autoload does not declare is the typo the reader wants told, the same way an unknown input
## action is - a name that resolves to nothing at runtime looks identical to one that works.
static func _global_variable_detail(_owner: ViewportRowBuilder, source: String, variable_name: String, declared: Array) -> String:
	for entry: Variant in declared:
		if str((entry as Dictionary).get("name", "")) != variable_name:
			continue
		var type_name: String = str((entry as Dictionary).get("type", "")).strip_edges()
		var word: String = ViewportRowBuilder.friendly_type_word(type_name) if not type_name.is_empty() else ""
		var value: String = str((entry as Dictionary).get("value", "")).strip_edges()
		if word.is_empty():
			return "%s = %s · %s" % [variable_name, value, source]
		return "%s %s = %s · %s" % [word, variable_name, value, source]
	return EventSheetL10n.translate("not declared on %s") % source


## The Input Map bar: which controls this script uses, and what each one is bound to. The
## project-wide Input Map is what every input row in the file is really about, and until this bar a
## reader had to leave the sheet and open Project Settings to find out what "jump" was.
##
## PURE VIEW, like every other head bar: null sources, folded by default, nothing added to
## `sheet.events` and nothing emitted, so an opened file still re-emits byte for byte. A script that
## names no control grows no bar.
static func _build_input_actions_bar_rows(_owner: ViewportRowBuilder, sheet: EventSheetResource) -> Array[EventRowData]:
	var bars: Array[EventRowData] = []
	var actions: Array[Dictionary] = EventSheetInputMapFacts.actions_named_by(sheet)
	if actions.is_empty():
		return bars
	var names: PackedStringArray = PackedStringArray()
	var members: Array[EventRowData] = []
	for index in range(actions.size()):
		var facts: Dictionary = actions[index]
		var action_name: String = str(facts.get("name", ""))
		names.append(action_name)
		members.append(_owner._build_object_fact_row(
			sheet, "input_action_%d" % index, action_name, _input_action_detail(_owner, facts)))
	var uses: String = EventSheetL10n.translate("this script uses 1 action") if actions.size() == 1 \
		else EventSheetL10n.translate("this script uses %d actions") % actions.size()
	bars.append(_owner._build_head_group_row(
		sheet, "input_actions", EventSheetL10n.translate("Input"),
		"%s - %s - %s" % [uses, ", ".join(names), EventSheetL10n.translate("Project ▸ Input Map")],
		members))
	return bars


## One control's muted line in the Input bar: what it is bound to. An action the project does not
## have says NOTHING here - it is a finding, and under the quiet sheet law a finding never renders in
## the sheet: the head bar wears the amber state, the sentence is in the help strip and the Doctor's
## inbox carries it with the fix beside it.
static func _input_action_detail(_owner: ViewportRowBuilder, facts: Dictionary) -> String:
	if not bool(facts.get("known", false)):
		return ""
	var bindings: PackedStringArray = facts.get("bindings", PackedStringArray())
	if bindings.is_empty():
		return EventSheetL10n.translate("unbound")
	return " · ".join(bindings)


## The Behaviors band's two halves: the CHIPS on the folded line (`Spring ×7`, `Juice`) and the
## MEMBER rows under it, one per kind - or more than one, when a member of a kind was tuned
## differently from its siblings, because that difference is the whole reason to open the fold.
##
## Grouped by name in first-mention order, then by the settings the scene wrote, so a kind mounted
## eight times on eight identical tiles is one line and the ninth with a knob turned is its own.
## Returns {"chips": PackedStringArray, "members": Array[EventRowData]}.
static func _behavior_kind_reading(_owner: ViewportRowBuilder, sheet: EventSheetResource, behaviors: Array) -> Dictionary:
	# Arrays, not PackedStringArrays: a packed array is a VALUE, so a list read back out of the
	# dictionary and appended to would be appended to a copy and every run would end up empty.
	var kind_order: Array = []
	var by_kind: Dictionary = {}
	for entry: Variant in behaviors:
		var behavior: Dictionary = entry
		var kind: String = str(behavior.get("name", ""))
		if not by_kind.has(kind):
			by_kind[kind] = {"order": [], "runs": {}, "count": 0, "script": ""}
			kind_order.append(kind)
		var bucket: Dictionary = by_kind[kind]
		bucket["count"] = int(bucket["count"]) + 1
		if str(bucket["script"]).is_empty():
			bucket["script"] = str(behavior.get("script", ""))
		var settings: String = _owner._behavior_settings_text(behavior)
		var runs: Dictionary = bucket["runs"]
		if not runs.has(settings):
			runs[settings] = []
			(bucket["order"] as Array).append(settings)
		(runs[settings] as Array).append(str(behavior.get("host", "")))
	var chips: PackedStringArray = PackedStringArray()
	# The sheet each chip opens, in the same order as the chips - "" for a kind whose scene line
	# named no script, which is a chip that stays a word.
	var chip_paths: PackedStringArray = PackedStringArray()
	var members: Array[EventRowData] = []
	for kind: Variant in kind_order:
		var bucket: Dictionary = by_kind[kind]
		var total: int = int(bucket["count"])
		chips.append(str(kind) if total == 1 else "%s ×%d" % [str(kind), total])
		chip_paths.append(str(bucket["script"]))
		for settings: Variant in (bucket["order"] as Array):
			var hosts: Array = (bucket["runs"] as Dictionary)[settings]
			var detail: PackedStringArray = PackedStringArray()
			if not str(settings).is_empty():
				detail.append(str(settings))
			var worn: String = _owner._behavior_host_words(hosts)
			if not worn.is_empty():
				detail.append(worn)
			members.append(_owner._build_object_fact_row(
				sheet, "object_behavior_%s_%d" % [str(kind), members.size()],
				str(kind) if hosts.size() == 1 else "%s ×%d" % [str(kind), hosts.size()],
				" · ".join(detail)))
	return {"chips": chips, "chip_paths": chip_paths, "members": members}


## The pack's knobs as event-sheet setting folders: one bar per @export_group in FILE order, a Settings
## bar for exported knobs declared before any group, and Internal state for the rest.
static func _build_knob_group_rows(_owner: ViewportRowBuilder, sheet: EventSheetResource, all_knobs: Array) -> Array[EventRowData]:
	# The compiler's own bookkeeping members are left out where the theme asks (hide_compiler_variables).
	var knobs: Array = []
	for entry: Variant in all_knobs:
		var knob_variable: LocalVariable = (entry as Dictionary).get("variable") if entry is Dictionary else null
		if knob_variable != null and (_owner.hides_compiler_variable(knob_variable.name)
				or EventSheetStateFacts.hides_declaration(sheet, knob_variable)):
			continue
		knobs.append(entry)
	# On an autoload every one of these IS a global variable, exported or not: the whole point
	# of the singleton is that the rest of the project reads them. Splitting them into Settings and
	# Internal state would be drawing a line a reader of an event sheet has no use for, so they read
	# as the ONE folder the sheet already has a name for.
	if ViewportRowBuilder.is_autoload(sheet):
		return _build_global_variables_folder(_owner, sheet, knobs)
	var order: PackedStringArray = PackedStringArray()
	var buckets: Dictionary = {}
	var internal: Array[EventRowData] = []
	# Inside an opened PACK the two DO get their own folders. A pack's exported knobs are its
	# published settings - the face a designer turns, listed in its guide - and everything else is
	# machinery it keeps to itself. That is the one file where the line is worth drawing, and drawing
	# it is what lets the pack open on its settings and its verbs with the rest folded away.
	var settings_rows: Array[EventRowData] = []
	var pack_name: String = _owner.pack_object_name()
	# How many Inspector-editable rows already lead the one folder - the insert point that keeps them
	# first without re-sorting a list whose order is otherwise the file's.
	var exported_count: int = 0
	for entry: Variant in knobs:
		var record: Dictionary = entry as Dictionary
		var variable: LocalVariable = record.get("variable")
		# A prebuilt row (a `preload` block read as an Object) is never exported - it is something the
		# file keeps for itself, so it lands with the rest of the internal state, in file order.
		if variable == null:
			internal.append(record.get("row") as EventRowData)
			continue
		var row_data: EventRowData = _owner._build_reading_variable_row(variable, str(record.get("description", "")), 1)
		var group_name: String = str(record.get("group", "")).strip_edges()
		if not variable.exported or group_name.is_empty():
			# One folder, not two. A variable is Inspector-editable or it is not, and the row
			# now says so with its own chip, so a Settings / Internal state split would only be
			# telling a reader twice what the chip already tells them once. The Inspector ones lead,
			# because those are the ones a designer came to look at.
			if variable.exported:
				if not pack_name.is_empty():
					settings_rows.append(row_data)
					continue
				internal.insert(exported_count, row_data)
				exported_count += 1
			else:
				internal.append(row_data)
			continue
		if not buckets.has(group_name):
			buckets[group_name] = [] as Array[EventRowData]
			order.append(group_name)
		(buckets[group_name] as Array[EventRowData]).append(row_data)
	var bars: Array[EventRowData] = []
	for group_name: String in order:
		var members: Array[EventRowData] = buckets[group_name]
		bars.append(_owner._build_head_group_row(
			sheet,
			"pack_settings_%s" % group_name,
			group_name,
			(EventSheetL10n.translate("%d setting") if members.size() == 1 else EventSheetL10n.translate("%d settings")) % members.size(),
			members
		))
	if not settings_rows.is_empty():
		bars.append(_owner._build_head_group_row(
			sheet,
			"pack_settings_bar",
			EventSheetL10n.translate("Settings"),
			(EventSheetL10n.translate("%d setting") if settings_rows.size() == 1 else EventSheetL10n.translate("%d settings")) % settings_rows.size(),
			settings_rows
		))
	if not internal.is_empty():
		var object_name: String = EventSheetViewportReadingRows.script_object_name(sheet)
		var subtitle: String = "%d" % internal.size() if object_name.is_empty() \
			else EventSheetL10n.translate("of %s") % object_name
		var title: String = EventSheetL10n.translate("Instance variables")
		if not pack_name.is_empty():
			# With the settings in a folder of their own, what is left is exactly what the pack keeps
			# to itself - so the folder says that rather than naming a language construct.
			title = EventSheetL10n.translate("Internal state")
			subtitle = "%d" % internal.size()
		bars.append(_owner._build_head_group_row(
			sheet,
			"pack_internal_state",
			title,
			subtitle,
			internal
		))
	return bars


## An autoload's knobs as the sheet's ONE Global variables folder, in file order. Same rows,
## same reading; only the folders they live in change, because on a global there is nothing for a
## second folder to mean.
static func _build_global_variables_folder(_owner: ViewportRowBuilder, sheet: EventSheetResource, knobs: Array) -> Array[EventRowData]:
	var members: Array[EventRowData] = []
	for entry: Variant in knobs:
		var record: Dictionary = entry as Dictionary
		var variable: LocalVariable = record.get("variable")
		if variable == null:
			members.append(record.get("row") as EventRowData)
			continue
		members.append(_owner._build_reading_variable_row(variable, str(record.get("description", "")), 1))
	if members.is_empty():
		return [] as Array[EventRowData]
	return [_owner._build_head_group_row(
		sheet,
		"pack_global_variables",
		EventSheetL10n.translate("Global variables"),
		"%d" % members.size(),
		members
	)] as Array[EventRowData]


## A muted, wrapping CAPTION row welded to the row directly below it - the "one line of prose above the
## thing it describes" pattern, which a published verb uses for its @ace_description. COMMENT is the row
## type on purpose: it is the only one the metrics measure for word wrap, so a full sentence wraps
## instead of clipping. source_resource stays null (there is no CommentRow behind it), so no edit / drag
## / delete reaches it, and attached_below welds it to its subject so the block gap opens ABOVE the pair.
static func build_caption_row(_owner: ViewportRowBuilder, text: String, indent: int, row_uid: String, accent: Color = Color(0, 0, 0, 0)) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.COMMENT
	row_data.source_resource = null
	row_data.row_uid = row_uid
	row_data.attached_below = true
	row_data.custom_color = accent
	row_data.spans = [
		_owner._make_span(text, SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "caption",
			"text_color": _owner._viewport._get_event_style().comment_text_color
		})
	]
	return row_data


## The [background, accent] pair a published verb's role paints with, from the PALETTE - the fallback
## used when there is no live style to read (a headless build, a null style). Kept static because the
## function dialog and other style-less callers use it directly.
static func define_role_badge_colors(role: String) -> Array:
	match role:
		"condition":
			return [EventSheetPalette.COLOR_ACE_CONDITION_BADGE_BG, EventSheetPalette.COLOR_ACE_CONDITION_BADGE_FG]
		"expression":
			return [EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_BG, EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_FG]
	return [EventSheetPalette.COLOR_ACE_ACTION_BADGE_BG, EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG]


## What ONE parameter chip on a function's header says: its friendly label, plus the value a
## caller gets when it leaves the input out, plus the ellipsis that marks the one input which
## swallows however many values follow it.
##
## A default is part of the SIGNATURE, not decoration: `Heal [amount = 10]` is the difference between
## a verb a reader may call with nothing and one they may not, and it is the value the picker
## pre-fills. `null` reads as the sheet's word for nothing, because that is the word every other row
## on the sheet uses for it.
static func verb_param_chip_text(param: ACEParam) -> String:
	var label: String = ViewportRowBuilder.friendly_param_label(param)
	if ViewportRowBuilder._is_varargs_param(param):
		return "%s …" % label
	var fallback: String = str(param.default_value).strip_edges()
	if fallback.is_empty():
		return label
	if fallback == "null":
		fallback = EventSheetL10n.translate("empty")
	return "%s = %s" % [label, fallback]


## The auto verb line's parameter slice - each param's friendly label, comma-joined ("from x, from y,
## width, color"). Empty when the verb takes none. Falls back to the legacy `parameters` string alias
## when a lifted verb carries no ACEParam metadata.
static func friendly_param_labels(event_function: EventFunction) -> String:
	var labels: PackedStringArray = PackedStringArray()
	for param: Variant in event_function.params:
		if param is ACEParam:
			labels.append(ViewportRowBuilder.friendly_param_label(param as ACEParam))
	if labels.is_empty():
		for legacy: String in event_function.parameters:
			labels.append(str(legacy).replace("_", " ").strip_edges())
	return ", ".join(labels)


## Writes every function head's hover card again in place, under `rows` and their children, and
## returns how many it wrote. The card names who else calls the function, an answer the project index
## gives only once it has finished counting - so the rows built before that carry a card without it,
## and this puts it in without building a single row again.
static func refresh_function_cards(_owner: ViewportRowBuilder, rows: Array) -> int:
	var written: int = 0
	var editable: bool = _owner._verb_metadata_editable()
	for row_variant: Variant in rows:
		var row_data: EventRowData = row_variant as EventRowData
		if row_data == null:
			continue
		var event_function: EventFunction = row_data.source_resource as EventFunction
		if event_function != null:
			for span: SemanticSpan in row_data.spans:
				var metadata: Dictionary = span.metadata as Dictionary
				if bool(metadata.get("function_name", false)) and metadata.has("hover_note"):
					metadata["hover_note"] = _owner._function_head_card(event_function, str(metadata.get("function_kind", "")), editable)
					written += 1
		written += refresh_function_cards(_owner, row_data.children)
	return written


## One parameter's line under its function, as the code names it: "int amount = 1".
static func function_param_line(param: ACEParam) -> String:
	var line: String = param.id
	if not param.type_name.strip_edges().is_empty():
		line = "%s %s" % [param.type_name.strip_edges(), param.id]
	if not param.gdscript_default.strip_edges().is_empty():
		line += " = %s" % param.gdscript_default.strip_edges()
	return line


## Which object a function reads its trigger under. A test's `run` and a command tool's
## `_init` are what the file EXISTS to do and the runner calls them by name, so they belong to Test
## and to Command tool, and both read "On run": the files are RUN. Every other function is a Function.
static func _verb_trigger_object(_owner: ViewportRowBuilder, event_function: EventFunction) -> String:
	match _owner._tool_file_entry_kind(event_function):
		EventSheetToolFiles.KIND_TEST_SHEET:
			return EventSheetL10n.translate(EventSheetToolFiles.OBJECT_TEST)
		EventSheetToolFiles.KIND_COMMAND_TOOL:
			return EventSheetL10n.translate(EventSheetToolFiles.OBJECT_COMMAND_TOOL)
	return EventSheetL10n.translate("Functions")


## The state machine as ONE row: the state icon, the type, the variable's own name, "is one of", the
## states exactly as the code writes them with the default marked, and what the machine is for - muted and
## italic like any variable's note. It reads the enum and the variable together, so it stands where the
## enum stood and stands in for both: the sheet says the machine once.
##
## The row is the variable's row (same keys, same selection, same gutter) with its value replaced by the
## list of states, and every word of it that names a state carries the state's own card. Nothing here
## writes anything: the declarations stay in the code, the helper ones among them.
static func build_state_row(_owner: ViewportRowBuilder, machine: Dictionary, indent: int) -> EventRowData:
	var variable: LocalVariable = machine["variable"] as LocalVariable
	var enum_row: EnumRow = machine["enum"] as EnumRow
	var sheet: EventSheetResource = _owner._viewport._sheet as EventSheetResource
	var row_data: EventRowData = _owner._build_variable_row("tree", variable.name, variable.type_name,
		variable.default_value, indent, {
			"is_constant": false,
			"exported": false,
			"expression_default": true,
			# The row IS the machine and is drawn where the enum sits, so it acts where it is drawn:
			# insert-after, a drag and the jump to code anchor on the enum, and delete, cut and copy
			# widen to every line the row stands for (EventSheetStateFacts.machine_parts).
			"source_resource": enum_row,
			"variable_resource": variable,
			"row_uid": "state_row_%d" % enum_row.get_instance_id(),
			"reading_scope": _owner._member_scope_key(variable),
			"description": EventSheetStateFacts.machine_description(sheet, machine),
		})
	var reading_style: EventSheetReadingStyle = _owner._viewport._get_reading_style()
	var style: EventSheetEventStyle = _owner._viewport._get_event_style()
	var default_member: String = EventSheetStateFacts.default_member(sheet, machine)
	var row_meta: Dictionary = {"state_machine": true, "kind": "variable", "editable": false, "variable_name": variable.name}
	# Only the primary machine streams its live state, so only its tokens carry a state_name to light up.
	var primary_machine: bool = variable.name.strip_edges() == EventSheetStateFacts.STATE_VARIABLE
	# The value goes: the states take its place, right after the name.
	var at: int = -1
	for index: int in row_data.spans.size():
		var metadata: Variant = row_data.spans[index].metadata
		if metadata is Dictionary and bool((metadata as Dictionary).get("variable_value_span", false)):
			at = index
			break
	var states: Array[SemanticSpan] = [_owner._make_span(EventSheetL10n.translate("is one of"),
		SemanticSpan.SpanType.COMMENT, row_meta.merged({"text_color": reading_style.muted_text_color}, true))]
	var members: PackedStringArray = EventSheetStateFacts.bare_members(sheet, machine)
	for member_index: int in members.size():
		var member: String = members[member_index]
		var token_meta: Dictionary = row_meta.merged({
			"state_token": member,
			"text_color": style.value_highlight_color,
			"hover_card_mark": true,
			"head_card": EventSheetStateFacts.state_card(sheet, member, machine),
		}, true)
		var token_text: String = member
		if primary_machine:
			token_meta["state_name"] = member
			# The state a running game is in holds room for its time ("RUN · 3.2 s"), drawn inside the
			# token by the renderer; the rows are laid out again when the live state changes.
			if EventSheetStateWatch.is_live() and EventSheetStateWatch.live_members().has(member):
				token_text = EventSheetStateWatch.token_reserve(member)
		states.append(_owner._make_span(token_text, SemanticSpan.SpanType.VALUE, token_meta))
		if member == default_member:
			states.append(_owner._make_span(EventSheetL10n.translate("(default)"), SemanticSpan.SpanType.COMMENT,
				row_meta.merged({"text_color": reading_style.muted_text_color}, true)))
		if member_index < members.size() - 1:
			states.append(_owner._make_span("·", SemanticSpan.SpanType.COMMENT, row_meta.merged({
				"text_color": reading_style.muted_text_color}, true)))
	if at >= 0:
		# The "=" before the value goes with it.
		if at > 0 and row_data.spans[at - 1].text == "=":
			row_data.spans.remove_at(at - 1)
			at -= 1
		row_data.spans.remove_at(at)
		for added: int in states.size():
			row_data.spans.insert(at + added, states[added])
	# Every span of the row knows it stands for a machine, so a double-click anywhere on it opens the
	# States window rather than the variable's own dialog. The type word wears the state glyph.
	for span: SemanticSpan in row_data.spans:
		if span.metadata is Dictionary:
			(span.metadata as Dictionary)["state_machine"] = true
			if bool((span.metadata as Dictionary).get("variable_type_span", false)):
				(span.metadata as Dictionary)["object_glyph"] = ViewportRowBuilder.NativeRowMarks.OBJECT_GLYPH_STATE
				(span.metadata as Dictionary)["object_icon"] = _owner._glyph_icon_slot()
			# The variable's name opens the card of the lines the row keeps out of sight.
			if bool((span.metadata as Dictionary).get("variable_name_span", false)) and primary_machine:
				var hidden_card: Dictionary = EventSheetStateFacts.machine_card(sheet)
				if not hidden_card.is_empty():
					(span.metadata as Dictionary)["head_card"] = hidden_card
					(span.metadata as Dictionary)["hover_card_mark"] = true
	return row_data


## A Moment block: the head names the beat, and one child row per step reads in the sheet's own
## two-lane grammar - the timing word ("At 0.05 s", "Hold, then 0.1 s", "Loop back 2 x") as the
## condition, the step's actions as the actions. Nothing is drawn INSIDE a row: playing it, saving
## it to a file and opening one back are toolbar and Inspector doors, not widgets in the sheet.
static func _build_moment_block_row(_owner: ViewportRowBuilder, block: MomentBlockRow, indent: int) -> EventRowData:
	var event_style: EventSheetEventStyle = _owner._viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = block
	row_data.row_uid = "moment_%s_%d" % [str(block.get_instance_id()), indent]
	row_data.disabled = not block.enabled or bool(_owner._viewport._row_disabled_state.get(row_data.row_uid, false))
	row_data.breakpoint_enabled = bool(_owner._viewport._breakpoint_rows.get(row_data.row_uid, false))
	row_data.folded = bool(_owner._viewport._fold_state.get(row_data.row_uid, false))
	# A moment is a DEFINITION - the beat something else plays by name - so it wears the same
	# identity bar the enum and the class-setup rows wear rather than an event row's height.
	row_data.height_scale = 1.5
	row_data.custom_color = Color(event_style.behavior_accent_color.r, event_style.behavior_accent_color.g, event_style.behavior_accent_color.b, 0.22)
	row_data.spans = [
		_owner._make_span("Moment", SemanticSpan.SpanType.KEYWORD, {
			"editable": false,
			"badge": true,
			"badge_style": "trigger",
			"badge_bg": event_style.behavior_accent_color.lerp(event_style.lane_divider_color, 0.45),
			"badge_fg": event_style.trigger_badge_foreground_color,
			"kind": "moment_row",
			"line_index": 0
		}),
		_owner._make_span(block.moment_name, SemanticSpan.SpanType.VALUE, {
			"kind": "moment_row", "text_color": event_style.object_label_color
		}),
		_owner._make_span(_moment_head_note(_owner, block), SemanticSpan.SpanType.COMMENT, {
			"kind": "moment_row", "text_color": _owner._viewport._get_reading_style().muted_text_color
		})
	]
	if not row_data.folded:
		for step_row: EventRowData in _build_moment_step_rows(_owner, block, indent + 1):
			row_data.children.append(step_row)
	return row_data


## What the head says after the name: the parameters every step is written against, and the range
## when the moment has one. Short, because the numbers themselves live on the steps.
static func _moment_head_note(_owner: ViewportRowBuilder, block: MomentBlockRow) -> String:
	# The two names are the coroutine's own PARAMETERS, so they are spelled as the emitted code
	# spells them rather than translated - a reader typing `strength` into a step's field is typing
	# this word.
	var note: String = "(strength, from)"
	if block.within > 0.0:
		note += " · %s %s" % [EventSheetL10n.translate("within"), String.num(block.within, 2).rstrip("0").rstrip(".")]
	return note


## One condition/action child row per step of a Moment block: the timing word reads as the WHEN,
## the step's actions as the WHAT. Rows carry the step itself, so a double-click edits that step.
static func _build_moment_step_rows(_owner: ViewportRowBuilder, block: MomentBlockRow, indent: int) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	for step: MomentStepRow in block.live_steps():
		var texts: PackedStringArray = PackedStringArray()
		for action_item: Variant in step.actions:
			if action_item is ACEAction:
				texts.append(_owner._format_action_descriptor(action_item as ACEAction))
			elif action_item is RawCodeRow:
				texts.append(_owner._friendly_statement_text((action_item as RawCodeRow).code))
			elif action_item is CommentRow:
				texts.append("# " + (action_item as CommentRow).text)
		if texts.is_empty():
			texts.append(" ")
		var step_row: EventRowData = _owner._build_condition_action_row(step.reading(), texts, indent, step)
		step_row.language_block = true
		rows.append(step_row)
	return rows


## A Custom Block API row: kind badge + the kind's one-line summary, both owned by the
## registered EventSheetBlockKind. A block whose kind is unregistered (its pack was removed)
## renders with a muted generic badge so the sheet stays readable; its emitted GDScript is
## plain code either way, so nothing else degrades.
static func _build_custom_block_row(_owner: ViewportRowBuilder, block: CustomBlockRow, indent: int) -> EventRowData:
	var event_style: EventSheetEventStyle = _owner._viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = block
	row_data.row_uid = "custom_block_%s_%d" % [str(block.get_instance_id()), indent]
	row_data.disabled = not block.enabled or bool(_owner._viewport._row_disabled_state.get(row_data.row_uid, false))
	row_data.breakpoint_enabled = bool(_owner._viewport._breakpoint_rows.get(row_data.row_uid, false))
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind(block.kind_id)
	# A region asks for its own look through the Custom Block API rather than borrowing the
	# group bar's chrome: it is a FOLD MARK, the same thing the script editor draws, and it holds
	# none of what a group holds. Any registered kind can ask for the same shape.
	if kind != null and kind.row_style(block) == "region":
		_dress_region_fence_row(_owner, row_data, block)
		return row_data
	# First-class display: a kind may describe variable-style spans (name / operator / value /
	# keyword pills) and its rows read like the plugin's own variable rows - the built-in
	# preload kind ships through this hook, so it is load-bearing, not just an extension seam.
	var described: Array[Dictionary] = kind.display_spans(block) if kind != null else []
	if not described.is_empty():
		row_data.spans = []
		for span_descriptor: Dictionary in described:
			var span_text: String = str(span_descriptor.get("text", ""))
			match str(span_descriptor.get("role", "value")):
				"name":
					row_data.spans.append(_owner._make_span(span_text, SemanticSpan.SpanType.OBJECT, {"kind": "custom_block_row"}))
				"operator":
					row_data.spans.append(_owner._make_span(span_text, SemanticSpan.SpanType.OPERATOR, {"kind": "custom_block_row"}))
				"type":
					row_data.spans.append(_owner._make_span(span_text, SemanticSpan.SpanType.VALUE, {"kind": "custom_block_row"}))
				"badge":
					var is_const_style: bool = str(span_descriptor.get("badge_style", "scope")) == "const"
					row_data.spans.append(_owner._make_span(span_text, SemanticSpan.SpanType.KEYWORD, {
						"kind": "custom_block_row",
						"badge": true,
						"badge_style": "const" if is_const_style else "scope",
						"badge_bg": _owner._viewport._get_reading_style().constant_badge_background_color if is_const_style else _owner._viewport._get_reading_style().inspector_chip_background_color,
						"badge_fg": _owner._viewport._get_reading_style().constant_badge_foreground_color if is_const_style else _owner._viewport._get_reading_style().inspector_chip_foreground_color
					}))
				_:
					row_data.spans.append(_owner._make_span(span_text, SemanticSpan.SpanType.VALUE, {"kind": "custom_block_row", "text_color": event_style.object_label_color}))
	else:
		var badge_text: String = kind.title if kind != null else "block"
		var summary_text: String = kind.summary(block) if kind != null else block.kind_id
		# Extension hooks: a kind may tint its badge (style) and flag bad fields live (validate).
		var kind_style: Dictionary = kind.style(block) if kind != null else {}
		var badge_color: Color = kind_style.get("accent", event_style.behavior_accent_color)
		row_data.spans = [
			_owner._make_span(
				badge_text,
				SemanticSpan.SpanType.KEYWORD,
				{"badge": true, "text_color": badge_color}
			),
			_owner._make_span(
				summary_text,
				SemanticSpan.SpanType.VALUE,
				{"kind": "custom_block_row", "text_color": event_style.object_label_color}
			)
		]
	var problem: String = kind.validate(block) if kind != null else ""
	if not problem.is_empty():
		row_data.spans.append(_owner._make_span(
			"⚠ " + problem,
			SemanticSpan.SpanType.VALUE,
			{"kind": "custom_block_row", "text_color": _owner._viewport._get_reading_style().error_text_color}
		))
	# A preload of a file the project does not have wears the quiet red state; the words are the strip's.
	if block.kind_id == "preload":
		var about_block: Array[Dictionary] = []
		for finding: Dictionary in _owner._sheet_findings(ViewportRowBuilder.FINDINGS_MISTAKES):
			if str(finding.get("anchor", "")) == ViewportRowBuilder.MISTAKE_ANCHOR_BLOCK and is_same(finding.get("block"), block):
				about_block.append(finding)
		_owner._stamp_attention(row_data, _owner._tagged(ViewportRowBuilder.FINDINGS_MISTAKES, about_block))
	return row_data


## A mid-file lifted function's position marker: the function itself is a real EventFunction
## (edited via its Define block / the Functions panel); this row just shows WHERE it lives in
## the file, muted so it reads as structure rather than content.
static func _build_function_anchor_row(_owner: ViewportRowBuilder, anchor: FunctionAnchorRow, indent: int) -> EventRowData:
	var event_style: EventSheetEventStyle = _owner._viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = anchor
	row_data.row_uid = "fn_anchor_%s_%d" % [str(anchor.get_instance_id()), indent]
	row_data.spans = [
		_owner._make_span(
			"ƒ",
			SemanticSpan.SpanType.KEYWORD,
			{"badge": true, "text_color": event_style.behavior_accent_color}
		),
		_owner._make_span(
			"%s()  - defined here" % anchor.function_name,
			SemanticSpan.SpanType.VALUE,
			{"kind": "function_anchor_row", "text_color": event_style.object_label_color}
		)
	]
	return row_data


## True when a line carries nothing but closing brackets - the `}` that ends a literal split into
## one action per line. It closes the statement above rather than starting one, so it wears no
## badge of its own.
static func _is_closer_line(line: String) -> bool:
	var text: String = line.strip_edges()
	if text.is_empty():
		return false
	for character: String in text:
		if not (character in "}]),"):
			return false
	return true


## Structured field ADD (the "add an action" gesture, for data classes): appends a canonical
## `\tvar name: Type[ = default]` to the class body and re-emits. "" when the code is not a
## LIFTING data class, the name is not a plain identifier, or a field with that name exists -
## the caller leaves the code untouched (degrade, never corrupt). Static + pure for tests.
static func data_class_add_field(code: String, field_name: String, field_type: String, default_value: String) -> String:
	if not ViewportRowBuilder.data_class_lifts(code) or not field_name.is_valid_identifier() or field_type.strip_edges().is_empty():
		return ""
	var model: Dictionary = ViewportRowBuilder.parse_data_class(code)
	for entry: Dictionary in model.get("body", []):
		if str(entry.get("kind")) == "field" and str(entry.get("name")) == field_name:
			return ""
	(model["body"] as Array).append({
		"kind": "field",
		"name": field_name,
		"type": field_type.strip_edges(),
		"default": default_value,
		"has_default": not default_value.is_empty()
	})
	return ViewportRowBuilder.emit_data_class(model)


## Structured field REMOVE: drops the body entry at field_index (must be a field) and
## re-emits. "" when the code is not a lifting data class or the index is not a field.
static func data_class_remove_field(code: String, field_index: int) -> String:
	if not ViewportRowBuilder.data_class_lifts(code):
		return ""
	var model: Dictionary = ViewportRowBuilder.parse_data_class(code)
	var body: Array = model.get("body", [])
	if field_index < 0 or field_index >= body.size() or str((body[field_index] as Dictionary).get("kind")) != "field":
		return ""
	body.remove_at(field_index)
	return ViewportRowBuilder.emit_data_class(model)


## Re-emits a parse_structured_class model: the verbatim prefix, the verbatim header, then every
## member's own source lines in order. A concatenation on purpose - nothing here rebuilds a line
## from parts, so the only way bytes could move is a member the walk failed to record.
static func emit_structured_class(model: Dictionary) -> String:
	var out: PackedStringArray = PackedStringArray()
	for prefix_line: String in model.get("prefix", []):
		out.append(prefix_line)
	out.append(str(model.get("header")))
	_append_structured_member_lines(model.get("members", []), out)
	return "\n".join(out)


## `class Name[ extends Base]:` split into {name, extends}, or {} when the line is not one. The one
## place the header shape is spelled, so the top-level walk and the nested one cannot disagree.
##
## Its OWN regex, deliberately. `_class_extends_regex` beside it is lazily compiled by whichever
## caller reaches it first and captures only the base class, so reading a name out of its group 1
## gave "" or the base depending on which reading ran earlier in the session - a state-order bug that
## passes alone and fails in a suite. A second pattern is cheaper than that class of failure.
static func _class_header_parts(line: String) -> Dictionary:
	if ViewportRowBuilder._structured_class_header_regex == null:
		ViewportRowBuilder._structured_class_header_regex = RegEx.new()
		if ViewportRowBuilder._structured_class_header_regex.compile("^class ([A-Za-z_][A-Za-z0-9_]*)(?: extends ([A-Za-z_][A-Za-z0-9_.]*))?:$") != OK:
			return {}
	var parts: RegExMatch = ViewportRowBuilder._structured_class_header_regex.search(line)
	if parts == null:
		return {}
	return {"name": parts.get_string(1), "extends": parts.get_string(2)}


## Walks one class body at `depth` tabs of indentation from `start`, returning {members, next} - or
## {} when it meets something this reading cannot hold, which is how a class stays honest code.
## Recursive: a nested class member is this same walk one tab deeper.
static func _scan_class_members(lines: PackedStringArray, start: int, depth: int) -> Dictionary:
	var members: Array = []
	var indent: String = "\t".repeat(depth)
	var i: int = start
	while i < lines.size():
		var line: String = lines[i]
		if line.strip_edges().is_empty():
			members.append({"kind": "blank", "depth": depth, "lines": PackedStringArray([line])})
			i += 1
			continue
		if not line.begins_with(indent):
			break  # a dedent - this class body ended on the line before
		var inner: String = line.substr(depth)
		if inner.begins_with("\t"):
			return {}  # deeper than the body with no member above it to belong to
		if inner.begins_with("#"):
			members.append({"kind": "note", "depth": depth, "lines": PackedStringArray([line])})
			i += 1
			continue
		if inner.begins_with("func ") or inner.begins_with("static func "):
			var block: PackedStringArray = _consume_member_block(lines, i, depth)
			members.append({"kind": "method", "depth": depth, "lines": block})
			i += block.size()
			continue
		if inner.begins_with("class "):
			var nested_header: Dictionary = _class_header_parts(inner)
			if nested_header.is_empty():
				return {}
			var nested: Dictionary = _scan_class_members(lines, i + 1, depth + 1)
			if nested.is_empty():
				return {}
			var nested_members: Array = nested.get("members", [])
			if _reading_member_count(nested_members) == 0:
				return {}  # a nested class with nothing in it this walk can name - keep the code
			members.append({
				"kind": "class",
				"depth": depth,
				"class_name": str(nested_header.get("name")),
				"extends": str(nested_header.get("extends")),
				"header": line,
				"members": nested_members
			})
			i = int(nested.get("next", i + 1))
			continue
		if inner.begins_with("enum ") or inner.begins_with("signal "):
			var kind_id: String = "enum" if inner.begins_with("enum ") else "signal"
			var claimed: Dictionary = _dedented_kind_claim(kind_id, lines, i, depth)
			if not claimed.is_empty():
				var consumed: int = int(claimed.get("consumed", 1))
				members.append({
					"kind": kind_id,
					"depth": depth,
					"lines": ViewportRowBuilder._line_slice(lines, i, consumed),
					"reading": str(claimed.get("reading", "")),
					"count": int(claimed.get("count", 0))
				})
				i += consumed
				continue
			# The kind refused this one. A single-line declaration still stands as a plain member
			# line (honest, and one line either way); a MULTI-line enum whose shape the enum reading
			# cannot hold would strand its member lines, so the whole class stays code instead.
			if kind_id == "enum" and not inner.ends_with("}"):
				return {}
			members.append({"kind": "member", "depth": depth, "lines": PackedStringArray([line])})
			i += 1
			continue
		if inner.begins_with("var ") or inner.begins_with("const ") or inner.begins_with("@"):
			members.append({"kind": "member", "depth": depth, "lines": PackedStringArray([line])})
			i += 1
			continue
		return {}  # a bare statement in a class body - not a shape this reading holds
	return {"members": members, "next": i}


## One member and everything indented under it (a method and its body), as its verbatim source
## lines. Trailing blank lines are handed BACK to the class body: they separate this member from the
## next, and counted here they would make a method report somebody else's gap as its own length.
static func _consume_member_block(lines: PackedStringArray, header_index: int, depth: int) -> PackedStringArray:
	var deeper: String = "\t".repeat(depth + 1)
	var block: PackedStringArray = PackedStringArray([lines[header_index]])
	var i: int = header_index + 1
	while i < lines.size() and (lines[i].strip_edges().is_empty() or lines[i].begins_with(deeper)):
		block.append(lines[i])
		i += 1
	while block.size() > 1 and block[block.size() - 1].strip_edges().is_empty():
		block.resize(block.size() - 1)
	return block


## What a registered block kind makes of a member once it is dedented to column 0 - which is exactly
## the question "what row would this be at top level?", asked of the one place that answers it. {}
## when the kind refuses. Returns how many lines it claimed, its own summary of the row, and the
## member count behind that summary (an enum's values, a signal's parameters).
static func _dedented_kind_claim(kind_id: String, lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	var kind: EventSheetBlockKind = EventSheetBlockRegistry.get_kind(kind_id)
	if kind == null:
		return {}
	var indent: String = "\t".repeat(depth)
	var dedented: PackedStringArray = PackedStringArray()
	for i: int in range(index, lines.size()):
		if not lines[i].begins_with(indent):
			break
		dedented.append(lines[i].substr(depth))
	if dedented.is_empty():
		return {}
	var claim: Dictionary = kind.lift(dedented, 0)
	if claim.is_empty():
		return {}
	var claimed_row: Resource = claim.get("resource") as Resource
	if claimed_row == null:
		return {}
	var count: int = 0
	if claimed_row is EnumRow:
		count = (claimed_row as EnumRow).members.size()
	elif claimed_row is SignalRow:
		count = (claimed_row as SignalRow).params.size()
	return {
		"consumed": maxi(1, int(claim.get("consumed", 1))),
		"reading": kind.summary_for(claimed_row),
		"count": count
	}


## The members that will RENDER as rows - blanks and comments are the class's own spacing, and a
## nested class made of nothing else has no structure for this reading to show.
static func _reading_member_count(members: Array) -> int:
	var shown: int = 0
	for member: Dictionary in members:
		var kind: String = str(member.get("kind"))
		if kind != "blank" and kind != "note":
			shown += 1
	return shown


static func _append_structured_member_lines(members: Array, into: PackedStringArray) -> void:
	for member: Dictionary in members:
		if str(member.get("kind")) == "class":
			into.append(str(member.get("header")))
			_append_structured_member_lines(member.get("members", []), into)
			continue
		for line: String in member.get("lines", PackedStringArray()):
			into.append(line)


## A TOP-LEVEL structured collection declaration (a const table, a var default set): ONE variable row,
## `Array[Vector2] spawn_points = 3 entries`, folded. Its entries are the rows under it - opened by the
## fold arrow or a double-click - one single-cell line each, no bracket rows. Entries edit in place
## (edit_kind "decl_entry_line:-1:<entry>" - the -1 says the row's own resource IS the declaration, and
## every entry row carries the declaration as its resource), and the row menu offers Add/Edit/Remove
## Entry. The uid is the declared name, so the fold survives the edits that replace the resource.
static func _build_collection_decl_row(_owner: ViewportRowBuilder, decl: CollectionDeclRow, indent: int) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = decl
	row_data.row_uid = "collection_decl_%s" % _owner._unique_class_scope("value:" + decl.variable_name(), decl)
	row_data.line_count = 1
	var decl_style: EventSheetEventStyle = _owner._viewport._get_event_style()
	var reading_style: EventSheetReadingStyle = _owner._viewport._get_reading_style()
	var head: Dictionary = {"editable": false, "kind": "collection_decl", "line_index": 0}
	var count: int = decl.entry_values.size()
	row_data.spans = [
		_owner._make_span(("const %s" if decl.is_constant() else "%s") % decl.declared_type(), SemanticSpan.SpanType.VALUE,
			head.merged({"text_color": reading_style.muted_text_color}, true)),
		_owner._make_span(decl.variable_name(), SemanticSpan.SpanType.VALUE,
			head.merged({"text_color": reading_style.primary_text_color}, true)),
		_owner._make_span("=", SemanticSpan.SpanType.VALUE, head.merged({"text_color": reading_style.muted_text_color}, true)),
		_owner._make_span(EventSheetL10n.translate("1 entry") if count == 1 else EventSheetL10n.translate("%d entries") % count,
			SemanticSpan.SpanType.VALUE, head.merged({"text_color": decl_style.value_highlight_color}, true)),
	]
	for entry_index: int in count:
		var entry_key: String = decl.entry_keys[entry_index] if entry_index < decl.entry_keys.size() else ""
		# An entry written over several lines is one entry, shown on its one line; it is edited as code,
		# because a one-line edit of it would rewrite the lines the file has.
		var entry_value: String = decl.entry_value_on_one_line(entry_index)
		var entry_row := EventRowData.new()
		entry_row.indent = indent + 1
		entry_row.row_type = EventRowData.RowType.SECTION
		entry_row.source_resource = decl
		entry_row.row_uid = "%s/%d" % [row_data.row_uid, entry_index]
		entry_row.spans = [_owner._make_span(entry_value if entry_key.is_empty() else "%s = %s" % [entry_key, entry_value],
			SemanticSpan.SpanType.VALUE, {
			"kind": "collection_decl",
			"decl_entry_index": entry_index,
			"editable": not decl.entry_spans_lines(entry_index),
			"edit_kind": "decl_entry_line:-1:%d" % entry_index,
			"line_index": 0,
			"text_color": decl_style.value_highlight_color
		})]
		row_data.children.append(entry_row)
	row_data.folded = bool(_owner._viewport._fold_state.get(row_data.row_uid, true))
	# Folded, the head already says what it holds - its count - so no summary of the entries trails it.
	row_data.set_meta("collapse_summary", "")
	return row_data


## "+ Add field" at the foot of an open data class: the same gesture as the block's right-click Add
## Field…, offered where the fields end.
static func _build_data_class_add_field_row(_owner: ViewportRowBuilder, raw_row: RawCodeRow, class_name_str: String, indent: int) -> EventRowData:
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = null
	row_data.row_uid = "data_class_add_field_%s" % class_name_str
	row_data.spans = [_owner._make_span(EventSheetL10n.translate("+ Add field"), SemanticSpan.SpanType.COMMENT, {
		"editable": false,
		"kind": "data_class_add_field",
		"raw_row": raw_row,
		"line_index": 0,
		"text_color": _owner._viewport._get_event_style().class_tag_color,
		"hover_note": EventSheetL10n.translate("Adds a field to this class: a name, a type and a starting value.")
	})]
	return row_data


## What a class is for, under its fields while the block is open: when to reach for one, and which
## variables of this sheet already hold it. Teaching text, never a finding.
static func _build_data_class_why_rows(_owner: ViewportRowBuilder, sheet: EventSheetResource, display_name: String, class_name_str: String, indent: int) -> Array[EventRowData]:
	var event_style: EventSheetEventStyle = _owner._viewport._get_event_style()
	var lines: Array[Dictionary] = [
		{"text": EventSheetL10n.translate("Use a class when values belong together"), "color": event_style.class_name_color},
		{"text": EventSheetL10n.translate("• Give each enemy, level or item its own settings in one variable, edited together in the Inspector."),
			"color": event_style.class_note_color},
		{"text": EventSheetL10n.translate("• Keep a list of them: every wave, every shop item, every line of dialogue."),
			"color": event_style.class_note_color},
	]
	var users: PackedStringArray = ViewportRowBuilder.NativeHeadMarks.class_users_in_sheet(sheet, display_name)
	if not users.is_empty():
		lines.append({"text": EventSheetL10n.translate("Used by %s") % ", ".join(users), "color": event_style.class_note_color})
	var rows: Array[EventRowData] = []
	for index: int in range(lines.size()):
		var row_data := EventRowData.new()
		row_data.indent = indent
		row_data.row_type = EventRowData.RowType.SECTION
		row_data.source_resource = null
		row_data.row_uid = "data_class_why_%s_%d" % [class_name_str, index]
		row_data.spans = [_owner._make_span(str(lines[index]["text"]), SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "data_class_why",
			"line_index": 0,
			"text_color": lines[index]["color"]
		})]
		rows.append(row_data)
	return rows


## A member-held inner class (structured_class_name) rendered as a foldable, READ-ONLY block: the
## class in the condition cell, what it holds in the action cell, and one child row per member -
## each read as the row it would be at TOP LEVEL. A nested class becomes its own fold inside this
## one, as deep as the file goes. Pure view: the RawCodeRow stays the source (double-click opens the
## code editor), nothing here is editable, and the byte round-trip is untouched.
static func _build_structured_class_row(_owner: ViewportRowBuilder, raw_row: RawCodeRow, indent: int) -> EventRowData:
	var model: Dictionary = ViewportRowBuilder.parse_structured_class(raw_row.code)
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.EVENT
	row_data.source_resource = raw_row
	row_data.line_count = 1
	# Uid scope, NOT the display name (same-named repeats suffix "-2" so rows never alias).
	var scope: String = _owner._unique_class_scope(str(model.get("class_name")), raw_row)
	row_data.row_uid = "structured_class_%s" % scope
	row_data.language_block = true  # a class declaration, not a regular ACE event - language stripe
	row_data.disabled = not raw_row.enabled or bool(_owner._viewport._row_disabled_state.get(row_data.row_uid, false))
	row_data.spans = _build_class_header_spans(_owner, str(model.get("class_name")), str(model.get("extends", "")),
		model.get("members", []))
	row_data.children = _build_class_member_rows(_owner, model.get("members", []), scope, indent + 1)
	if not row_data.children.is_empty():
		row_data.folded = bool(_owner._viewport._fold_state.get(row_data.row_uid, true))
	return row_data


## The header of a class block: its declaration in the CONDITION cell, and what it holds - counted by
## kind - in the ACTION cell. Shared by the outer block and every class nested inside it, so a fold
## three deep reads the same way the one at the top does.
static func _build_class_header_spans(_owner: ViewportRowBuilder, display_name: String, base: String, members: Array) -> Array[SemanticSpan]:
	var condition_style: Dictionary = _owner._viewport._build_element_style_metadata(_owner._viewport._get_condition_style())
	var action_style: Dictionary = _owner._viewport._build_element_style_metadata(_owner._viewport._get_action_style())
	var event_style: EventSheetEventStyle = _owner._viewport._get_event_style()
	var header_text: String = "class %s" % display_name
	if not base.is_empty():
		header_text += " extends %s" % base
	var spans: Array[SemanticSpan] = [
		_owner._make_span(header_text, SemanticSpan.SpanType.OBJECT, {
			"lane": "condition", "editable": false, "kind": "raw_code", "line_index": 0,
			"text_color": event_style.object_label_color
		}.merged(condition_style, true))
	]
	spans.append(_owner._make_span(_class_member_cue(members), SemanticSpan.SpanType.VALUE, {
		"lane": "action", "editable": false, "kind": "raw_code", "line_index": 0,
		"text_color": event_style.value_highlight_color
	}.merged(action_style, true)))
	return spans


## What a class holds, counted by kind, in the same "N x · N y" idiom the methods-class header uses.
## Kinds with nothing in them are left out rather than reported as zero.
static func _class_member_cue(members: Array) -> String:
	var counts: Dictionary = {"member": 0, "method": 0, "enum": 0, "signal": 0, "class": 0}
	for member: Dictionary in members:
		var kind: String = str(member.get("kind"))
		if counts.has(kind):
			counts[kind] = int(counts[kind]) + 1
	var words: Array = [["member", "field", "fields"], ["method", "method", "methods"],
		["enum", "enum", "enums"], ["signal", "signal", "signals"], ["class", "class", "classes"]]
	var parts: PackedStringArray = PackedStringArray()
	for word: Array in words:
		var count: int = int(counts[str(word[0])])
		if count > 0:
			parts.append("%d %s" % [count, str(word[1]) if count == 1 else str(word[2])])
	return " · ".join(parts)


## One child row per member of a class block, each read as the row it would be at top level. Blank
## lines and comments are the class's own spacing and carry no row. `scope` keys the uids - a nested
## class extends it with its own name, so a member of Outer.Inner never aliases one of Outer.
static func _build_class_member_rows(_owner: ViewportRowBuilder, members: Array, scope: String, indent: int) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	var index: int = 0
	for member: Dictionary in members:
		var kind: String = str(member.get("kind"))
		if kind == "blank":
			continue
		var depth: int = int(member.get("depth", 1))
		if kind == "class":
			rows.append(_build_nested_class_row(_owner, member, scope, index, indent))
		elif kind == "method":
			rows.append(_owner._build_class_method_row(scope, index,
				_dedent_lines(member.get("lines", PackedStringArray()), depth), indent))
		elif kind == "enum" or kind == "signal":
			rows.append(_build_class_reading_row(_owner, member, scope, index, indent))
		else:
			rows.append(_owner._build_data_class_member_row(scope, index,
				str(member.get("lines", PackedStringArray([""]))[0]), indent))
		index += 1
	return rows


## A class nested inside another one: the same header + member rows as the block above it, one
## indent deeper and folded on its own. The uid scope carries the outer class's, so two nested
## classes with the same name under different parents keep their own fold and selection state.
static func _build_nested_class_row(_owner: ViewportRowBuilder, member: Dictionary, scope: String, index: int, indent: int) -> EventRowData:
	var nested_scope: String = "%s.%s" % [scope, str(member.get("class_name"))]
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.EVENT
	row_data.source_resource = null
	row_data.line_count = 1
	row_data.row_uid = "structured_class_nested_%s_%d" % [nested_scope, index]
	row_data.language_block = true
	row_data.spans = _build_class_header_spans(_owner, str(member.get("class_name")),
		str(member.get("extends", "")), member.get("members", []))
	row_data.children = _build_class_member_rows(_owner, member.get("members", []), nested_scope, indent + 1)
	if not row_data.children.is_empty():
		row_data.folded = bool(_owner._viewport._fold_state.get(row_data.row_uid, true))
	return row_data


## An enum or a signal declared inside a class, read the way the same declaration reads at top level:
## the block kind's OWN summary of the row it lifted, in the condition cell, with the enum's value
## count beside it. That is what collapses a five-line enum to one row - the reading comes from the
## kind, not from a second spelling of the same thing kept here.
static func _build_class_reading_row(_owner: ViewportRowBuilder, member: Dictionary, scope: String, index: int, indent: int) -> EventRowData:
	var kind: String = str(member.get("kind"))
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.EVENT
	row_data.source_resource = null
	row_data.line_count = 1
	row_data.row_uid = "structured_class_%s_%s_%d" % [kind, scope, index]
	row_data.language_block = true
	var condition_style: Dictionary = _owner._viewport._build_element_style_metadata(_owner._viewport._get_condition_style())
	var action_style: Dictionary = _owner._viewport._build_element_style_metadata(_owner._viewport._get_action_style())
	var spans: Array[SemanticSpan] = [
		_owner._make_span("%s %s" % [kind, str(member.get("reading"))], SemanticSpan.SpanType.OBJECT, {
			"lane": "condition", "editable": false, "kind": "raw_code", "line_index": 0,
			"text_color": _owner._viewport._get_event_style().object_label_color
		}.merged(condition_style, true))
	]
	var count: int = int(member.get("count", 0))
	if kind == "enum" and count > 0:
		spans.append(_owner._make_span("%d %s" % [count, EventSheetL10n.translate("values")],
			SemanticSpan.SpanType.VALUE, {
				"lane": "action", "editable": false, "kind": "raw_code", "line_index": 0,
				"text_color": _owner._viewport._get_reading_style().muted_text_color
			}.merged(action_style, true)))
	row_data.spans = spans
	return row_data


## The same lines with `depth` leading tabs taken off each, so a member reads (and matches the
## method-header shape) exactly as it would at column 0. Blank lines are left alone.
static func _dedent_lines(lines: PackedStringArray, depth: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var indent: String = "\t".repeat(depth)
	for line: String in lines:
		out.append(line.substr(depth) if line.begins_with(indent) else line)
	return out


## A preloaded scene, script or resource is an OBJECT, not a value: `bullet_scene` holding
## `preload("res://bullet.tscn")` reads `Object bullet_scene = Bullet  scene · bullet.tscn`, with the
## scene root's own class icon. The res:// path is punctuation to a reader; the THING at the end of it
## is what they are looking for, and the file name stays as the muted receipt. Returns null when the
## value is not a preload/load of a project path.
## Display-only: `source` and `row_uid` come from whatever row carried the preload (a lifted
## LocalVariable or a `preload` block), so selection and the byte round-trip are untouched.
static func _build_preload_object_row(_owner: ViewportRowBuilder, object_name: String, res_path: String, indent: int, source: Resource, row_uid: String) -> EventRowData:
	var resolved: Dictionary = resolve_res_object(res_path)
	if resolved.is_empty():
		return null
	var event_style: EventSheetEventStyle = _owner._viewport._get_event_style()
	var row_data := EventRowData.new()
	row_data.indent = indent
	row_data.row_type = EventRowData.RowType.SECTION
	row_data.source_resource = source
	row_data.row_uid = row_uid
	row_data.line_count = 1
	var icon_class: String = str(resolved.get("icon_class", ""))
	var icon: Texture2D = null
	if _owner._viewport.show_object_icons and not icon_class.is_empty():
		icon = EventSheetACEIcons.editor_icon(icon_class)
	# No kind word in front: the scene's own icon and the name say what it is.
	row_data.spans = [
		_owner._make_span(object_name, SemanticSpan.SpanType.OBJECT, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": event_style.object_label_color
		}),
		_owner._make_span("=", SemanticSpan.SpanType.OPERATOR, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": _owner._viewport._get_reading_style().muted_text_color
		}),
		_owner._make_span(str(resolved.get("name", "")), SemanticSpan.SpanType.VALUE, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": event_style.value_highlight_color,
			"object_icon": icon
		}),
		_owner._make_span("%s · %s" % [str(resolved.get("kind_word", "")), res_path.get_file()], SemanticSpan.SpanType.COMMENT, {
			"editable": false, "kind": "variable", "line_index": 0,
			"text_color": _owner._viewport._get_reading_style().muted_text_color
		})
	]
	return row_data


## What sits at the end of a res:// path, as {name, kind_word, icon_class} - the noun a reader wants
## instead of the path. A scene answers with its ROOT NODE (name and class, straight from the
## `[node ...]` line, which is the first node the file lists); a resource with the class it was saved
## as (its `script_class` when it has one, because that is the name the author gave it); a script with
## its `class_name`. Anything else keeps its file name, which is all a .png or a .ogg has to give.
## Returns {} for a path the project does not have, so the caller can fall back to the plain value.
## Parsed off DISK and cached per session - these files do not change while a sheet is open, and the
## reader would otherwise re-read them on every redraw.
static func resolve_res_object(res_path: String) -> Dictionary:
	if res_path.is_empty():
		return {}
	if ViewportRowBuilder._res_object_cache.has(res_path):
		return ViewportRowBuilder._res_object_cache[res_path]
	var resolved: Dictionary = {}
	if FileAccess.file_exists(res_path):
		match res_path.get_extension().to_lower():
			"tscn":
				resolved = _resolve_scene_object(res_path)
			"tres":
				resolved = _resolve_resource_object(res_path)
			"gd":
				resolved = _resolve_script_object(res_path)
			_:
				resolved = {
					"name": res_path.get_file().get_basename(),
					"kind_word": res_path.get_extension().to_lower(),
					"icon_class": ""
				}
	ViewportRowBuilder._res_object_cache[res_path] = resolved
	return resolved


static func _resolve_scene_object(res_path: String) -> Dictionary:
	var root: Dictionary = scene_root_of(res_path)
	if root.is_empty():
		return {}
	return {
		"name": str(root.get("name", "")),
		"kind_word": EventSheetL10n.translate("scene"),
		"icon_class": str(root.get("type", ""))
	}


static func _resolve_resource_object(res_path: String) -> Dictionary:
	var handle: FileAccess = FileAccess.open(res_path, FileAccess.READ)
	if handle == null:
		return {}
	var header: String = handle.get_line()
	handle.close()
	var script_class: String = ViewportRowBuilder._quoted_attribute(header, "script_class")
	var base_type: String = ViewportRowBuilder._quoted_attribute(header, "type")
	var shown: String = script_class if not script_class.is_empty() else base_type
	if shown.is_empty():
		shown = res_path.get_file().get_basename()
	return {"name": shown, "kind_word": EventSheetL10n.translate("resource"), "icon_class": base_type}


static func _resolve_script_object(res_path: String) -> Dictionary:
	var handle: FileAccess = FileAccess.open(res_path, FileAccess.READ)
	if handle == null:
		return {}
	var shown: String = ""
	var base_type: String = ""
	while not handle.eof_reached():
		var line: String = handle.get_line().strip_edges()
		if line.begins_with("class_name "):
			shown = line.substr("class_name ".length()).strip_edges()
		elif line.begins_with("extends "):
			base_type = line.substr("extends ".length()).strip_edges()
		elif line.begins_with("func ") or line.begins_with("var ") or line.begins_with("const "):
			break
	handle.close()
	if shown.is_empty():
		shown = res_path.get_file().get_basename()
	return {"name": shown, "kind_word": EventSheetL10n.translate("script"), "icon_class": base_type}


## The root node of a .tscn as {name, type}, read straight off the text: the FIRST `[node ...]` line
## is the root by the scene format's own rule. {} when the file cannot be read or lists no node. An
## instanced root (`instance=ExtResource(...)`) declares no type, so only the name comes back.
static func scene_root_of(scene_path: String) -> Dictionary:
	var handle: FileAccess = FileAccess.open(scene_path, FileAccess.READ)
	if handle == null:
		return {}
	while not handle.eof_reached():
		var line: String = handle.get_line()
		if not line.begins_with("[node "):
			continue
		handle.close()
		return {"name": ViewportRowBuilder._quoted_attribute(line, "name"), "type": ViewportRowBuilder._quoted_attribute(line, "type")}
	handle.close()
	return {}


## The sub-rows a NAMED property grows: one per accessor the declaration points at, saying which
## function runs and when. `set = _set_health` reads `➜ <Object> On health set  → _set_health`, the
## same trigger row an inline `set(value):` reads as, with the function's name where its body would
## have been.
##
## AND THE GETTER IS AN EXPRESSION, not a trigger - the same word the inline spelling two functions
## below already reads it as. A `set` block fires when the value is written, which is exactly an
## event; a `get` block is a function that gives a value back, which is an expression, and the
## grammar says an expression answers inside a value slot rather than being an event. Naming one
## spelling of that a trigger and the other an expression would show a reader the same idea in two
## grammatical categories in one opened file, since a file may write its properties either way.
##
## Nothing is inlined here on purpose. The function is written somewhere else in the file, it reads as
## itself where it was written, and copying its rows under the declaration would show the same code
## twice and leave a reader wondering which of the two they are allowed to edit.
##
## Pure view: the rows are inert, nothing addresses them, and the file's own text is untouched - the
## byte round-trip never sees this.
static func _build_named_accessor_rows(_owner: ViewportRowBuilder, variable: LocalVariable, indent: int, uid_base: String) -> Array[EventRowData]:
	var rows: Array[EventRowData] = []
	var object_name: String = _owner._script_object_name()
	if object_name.strip_edges().is_empty():
		object_name = EventSheetSentence.OBJECT_SYSTEM
	if not variable.setter_name.strip_edges().is_empty():
		rows.append(_build_named_accessor_row(_owner, variable, object_name, "set",
			variable.setter_name.strip_edges(), EventSheetL10n.translate("On %s set"), indent,
			uid_base))
	if not variable.getter_name.strip_edges().is_empty():
		rows.append(_build_named_getter_row(_owner, variable, object_name,
			variable.getter_name.strip_edges(), indent, uid_base))
	return rows


## The named getter's row: the SAME expression header the inline spelling reads with - the ƒ scope
## badge, the property's name and the muted word `expression` - with the function that gives the value
## on the right, where the inline spelling shows its body instead.
static func _build_named_getter_row(_owner: ViewportRowBuilder, variable: LocalVariable, object_name: String, function_name: String, indent: int, uid_base: String) -> EventRowData:
	var row := EventRowData.new()
	row.indent = indent
	row.row_type = EventRowData.RowType.EVENT
	row.row_uid = "property_named_get_%s" % uid_base
	row.line_count = 1
	row.spans.append_array(_getter_head_spans(_owner, variable, object_name))
	row.spans.append(_accessor_function_span(_owner, function_name, object_name))
	_owner._dress_line_object_icons(row.spans)
	return row


## One named accessor's row: the trigger badge, the sentence, and the function it calls on a chip.
static func _build_named_accessor_row(_owner: ViewportRowBuilder, variable: LocalVariable, object_name: String, kind: String, function_name: String, sentence: String, indent: int, uid_base: String) -> EventRowData:
	var row := EventRowData.new()
	row.indent = indent
	row.row_type = EventRowData.RowType.EVENT
	row.row_uid = "property_named_%s_%s" % [kind, uid_base]
	row.line_count = 1
	# The name as written: `brush_size`, never "brush size" - it is the word the reader typed and the
	# word they will search for.
	row.spans.append_array(_owner._plain_trigger_spans(sentence % variable.name, object_name))
	# The function goes in the RIGHT lane, where a thing that runs belongs - the trigger asks and the
	# action does, which is the sheet's whole grammar. It also gives the row a right half: a trigger
	# row with nothing on its right keeps the condition lane at its minimum, and the sentence is then
	# cut off after two characters.
	row.spans.append(_accessor_function_span(_owner, function_name, object_name))
	_owner._dress_line_object_icons(row.spans)
	return row


## A named accessor's function, in the RIGHT lane where a thing that runs belongs.
static func _accessor_function_span(_owner: ViewportRowBuilder, function_name: String, object_name: String) -> SemanticSpan:
	var action_style: Dictionary = _owner._viewport._build_element_style_metadata(_owner._viewport._get_action_style())
	return _owner._make_span(function_name, SemanticSpan.SpanType.ACTION, {
		"lane": "action",
		"kind": "property_accessor_function",
		"ace_index": 0,
		"editable": false,
		"hoverable": false,
		"line_index": 0,
		"object_label": object_name
	}.merged(action_style, true))


## A getter's header, the one an expression function reads with: the ƒ scope badge, the property's
## name and the muted word `expression`.
static func _getter_head_spans(_owner: ViewportRowBuilder, variable: LocalVariable, object_name: String) -> Array[SemanticSpan]:
	var badge_colors: Array = _owner._define_role_colors("expression")
	return [_owner._make_span("ƒ", SemanticSpan.SpanType.KEYWORD, {
		"editable": false,
		"badge": true,
		"badge_style": "scope",
		"badge_bg": badge_colors[0],
		"badge_fg": badge_colors[1],
		"lane": "condition",
		"line_index": 0
	}), _owner._make_span(variable.name.replace("_", " "), SemanticSpan.SpanType.OBJECT, {
		"editable": false,
		"kind": "property_getter",
		"lane": "condition",
		"line_index": 0,
		"chip": true,
		"object_label": object_name,
		"text_color": _owner._define_role_name_color("expression")
	}), _owner._make_span(EventSheetL10n.translate("expression"), SemanticSpan.SpanType.COMMENT, {
		"editable": false,
		"lane": "condition",
		"line_index": 0,
		"natural_width": true,
		"text_color": _owner._viewport._get_reading_style().muted_text_color
	})]


## The getter's expression row: the ƒ badge, the property's name, and the muted kind word beside it -
## the same header an expression function reads with. Its body says `Set return value to …`, so the
## step is left where it is rather than folded into the header. null when the body does not lift.
static func _build_property_getter_row(_owner: ViewportRowBuilder, variable: LocalVariable, object_name: String, indent: int, uid_base: String) -> EventRowData:
	var row := EventRowData.new()
	row.indent = indent
	row.row_type = EventRowData.RowType.EVENT
	row.row_uid = "property_getter_%s" % uid_base
	row.line_count = 1
	row.spans.append_array(_getter_head_spans(_owner, variable, object_name))
	_owner._dress_line_object_icons(row.spans)
	if not _owner._append_property_body_rows(row, variable.getter_body, indent, row.row_uid,
			EventSheetSentence.VerbKind.EXPRESSION):
		return null
	return row


## One accessor of a property variable (`set(value)` / `get`) as a read-only condition/action row: the
## accessor header in the CONDITION cell, its body lines as ACTION cells. source_resource stays null so
## select/drag/delete skip it; the parent variable row's double-click edits the property in the dialog.
static func _build_property_accessor_row(_owner: ViewportRowBuilder, variable: LocalVariable, header: String, body: String, indent: int, accessor: String) -> EventRowData:
	var body_lines: PackedStringArray = PackedStringArray()
	for line: String in body.split("\n"):
		body_lines.append(line)
	var row: EventRowData = _owner._build_condition_action_row(header, body_lines, indent, null)
	row.language_block = true
	row.row_uid = "property_accessor_%s_%d" % [accessor, variable.get_instance_id()]
	return row


static func _collect_group_object_labels(_owner: ViewportRowBuilder, rows: Array, labels: PackedStringArray, seen: Dictionary) -> void:
	for entry: Variant in rows:
		if labels.size() > EventSheetGroupFacts.FOLDED_OBJECT_LIMIT:
			return
		if entry is EventGroup:
			_collect_group_object_labels(_owner, EventSheetGroupFacts.children(entry as EventGroup), labels, seen)
			continue
		var event_row: EventRow = entry as EventRow
		if event_row == null:
			continue
		if not event_row.trigger_id.strip_edges().is_empty():
			_note_object_label(_owner, _owner._object_label_for(event_row.trigger_provider_id, event_row.trigger_id,
				event_row.trigger_params), labels, seen)
		for condition: Variant in event_row.conditions:
			if condition is ACECondition:
				_note_object_label(_owner, _owner._object_label_for((condition as ACECondition).provider_id, (condition as ACECondition).ace_id,
					_owner._row_params(condition)), labels, seen)
		for action: Variant in event_row.actions:
			if action is ACEAction:
				_note_object_label(_owner, _owner._object_label_for((action as ACEAction).provider_id, (action as ACEAction).ace_id,
					_owner._row_params(action)), labels, seen)


static func _note_object_label(_owner: ViewportRowBuilder, label: String, labels: PackedStringArray, seen: Dictionary) -> void:
	var trimmed: String = label.strip_edges()
	if trimmed.is_empty() or seen.has(trimmed):
		return
	seen[trimmed] = true
	labels.append(trimmed)


## Records that this event is a menu answering its items. Claimed here rather than through the
## pending-pattern funnel because a handler is a shape all by itself: a file may answer a menu built
## in another file, and then there is no add_item run on this sheet to hang the claim on.
static func _claim_menu_pattern(_owner: ViewportRowBuilder, event_row: EventRow, menu: Dictionary) -> void:
	var uid: String = event_row.event_uid if event_row != null else ""
	if uid.is_empty():
		return
	var vocabulary: Dictionary = ViewportRowBuilder.PATTERN_VOCABULARY.get(EventSheetMenuFacts.PATTERN_ID, {})
	EventSheetPatternFacts.claim(_owner._viewport._sheet, EventSheetMenuFacts.PATTERN_ID, uid, uid,
		PackedStringArray([str(menu.get("object", ""))]), str(vocabulary.get("words", "")))


## One `match` arm of a menu handler as the trigger it is: the ➜ badge, the menu in the object
## column, and `On <item> chosen` with the id resolved back to the words the user clicks. An id no
## item declared keeps the number and wears the warning colour - the branch is real, and nothing in
## the menu can ever reach it.
static func _menu_arm_condition_spans(_owner: ViewportRowBuilder, menu: Dictionary, pattern_text: String) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	var words: Dictionary = EventSheetMenuFacts.arm_words(menu, pattern_text)
	if words.is_empty():
		return spans
	var condition_style_meta: Dictionary = _owner._viewport._build_element_style_metadata(_owner._viewport._get_condition_style())
	spans.append(_owner._trigger_badge_span("➜", 0, condition_style_meta.get("badge_extra_width", _owner._viewport.BADGE_EXTRA_WIDTH), true))
	var arm_meta: Dictionary = {
		"lane": "condition",
		"kind": "trigger",
		"ace_index": -1,
		"chip": true,
		"editable": false,
		"line_index": 0,
		"object_label": str(menu.get("object", ""))
	}.merged(condition_style_meta, true)
	if not bool(words.get("known", false)):
		arm_meta["text_color"] = EventSheetActiveTheme.chrome().object_bar_warning_color
	spans.append(_owner._make_span(str(words.get("text", "")), SemanticSpan.SpanType.CONDITION, arm_meta))
	return spans


## Which edges a scroll-limits row actually set, said quietly after the sentence. The values of the
## vertical pair are one hover away on the row, which lists every line it stands for.
static func _scroll_limit_note(_owner: ViewportRowBuilder, sides: Dictionary) -> String:
	var named: PackedStringArray = PackedStringArray()
	for side: Variant in ViewportRowBuilder.SCROLL_LIMIT_SIDES.values():
		if sides.has(str(side)):
			named.append(EventSheetL10n.translate(str(side)))
	return "(%s)" % ", ".join(named)


## One line that puts something in a menu -> {menu, line}, or {} for anything else. Both
## spellings are read - the line as typed and the Call Method row the lifter files it as - so a run
## reads the same whichever way the open lifted it.
static func _menu_item_parts(_owner: ViewportRowBuilder, action_resource: Variant) -> Dictionary:
	var text: String = _owner._group_line_text(action_resource)
	if text.is_empty():
		return {}
	var menu_key: String = EventSheetMenuFacts.item_menu_key(text)
	return {} if menu_key.is_empty() else {"menu": menu_key, "line": text}


## True when one line of a recipe states a head fact rather than doing something. The properties are
## the very list the bar reads, so a fact the bar stops showing starts drawing its row again rather
## than vanishing from both.
static func _is_recipe_head_line(_owner: ViewportRowBuilder, line: String) -> bool:
	if not line.begins_with("sheet."):
		return false
	for property: Variant in EventSheetToolFiles.RECIPE_HEAD_PROPERTIES:
		if line.begins_with("sheet.%s = " % str(property)):
			return true
	return false


## The condition cells of one PATTERN arm: the Else chip when the arm takes whatever is left, the
## arm's own sentence otherwise, and the names it binds as chips after it. The chips sit on the same
## line as the sentence, because what the pattern pulled out is part of what the pattern says.
static func _match_pattern_condition_spans(_owner: ViewportRowBuilder, reading: Dictionary, chain_index: int, condition_style_meta: Dictionary) -> Array[SemanticSpan]:
	var spans: Array[SemanticSpan] = []
	var sentence: String = str(reading.get("text", ""))
	var is_else: bool = bool(reading.get("is_else", false))
	var line_index: int = 0
	if chain_index > 0 or is_else:
		spans.append(_owner._make_span(EventSheetL10n.translate("Else"), SemanticSpan.SpanType.CONDITION, {
			"lane": "condition",
			"kind": "else_keyword",
			"chip": true,
			"hoverable": false,
			"line_index": 0,
			"object_label": _owner._object_label_for("Core", "")
		}.merged(condition_style_meta, true)))
		# An Else-if's test sits on the SECOND condition line, under the Else chip, exactly as the
		# plain-value chain draws it.
		line_index = 0 if is_else else 1
	if not sentence.is_empty():
		spans.append(_owner._make_span(sentence, SemanticSpan.SpanType.CONDITION, {
			"lane": "condition",
			"kind": "match_pattern",
			"editable": false,
			"line_index": line_index,
			"object_label": _owner._object_label_for("Core", "")
		}.merged(condition_style_meta, true)))
	for chip_text: String in (reading.get("chips", PackedStringArray()) as PackedStringArray):
		spans.append(_owner._make_span(chip_text, SemanticSpan.SpanType.CONDITION, {
			"lane": "condition",
			"kind": "match_binding",
			"editable": false,
			"chip": true,
			"hoverable": false,
			"line_index": line_index
		}.merged(condition_style_meta, true)))
	return spans


## A guard's plain-language reading: a bare self-call humanizes to its verb the way every
## method name already does ("can_see_player()" reads "Can See Player" - a beginner should
## never meet parentheses in a condition cell). The computed-check cue is the ƒ SVG BADGE the
## caller adds in the icon column (the same ƒ collapsed functions wear, one symbol taught
## once), never inline text. A negated guard does NOT say the word "not" - the sentence is
## the positive one and the inversion is the `not` mark in the badge column, the same mark an inverted
## ACE condition has always worn, so one symbol means one thing everywhere on the sheet. Value
## comparisons ("hp < 20") keep their values. Display-only; the hover carries the code.
static func _friendly_guard_text(_owner: ViewportRowBuilder, guard: String) -> String:
	var text: String = str(EventSheetViewportLenses.strip_leading_not(guard.strip_edges()).get("text", ""))
	var friendly: String = text
	var call: Dictionary = ViewportRowBuilder.call_parts(text)
	if not call.is_empty() and (str(call.get("target", "")).is_empty() or str(call.get("target", "")) == "self"):
		var args_text: String = _owner._joined_call_args(call)
		friendly = str(call.get("verb", "")) if args_text.strip_edges().is_empty() else "%s ( %s )" % [str(call.get("verb", "")), args_text]
	return friendly


## The display leaf of a match pattern: `State.PATROL` -> `PATROL`, `"patrol"` -> `patrol`,
## anything else verbatim. Display-only - the pattern itself is untouched.
static func _pattern_leaf(_owner: ViewportRowBuilder, pattern_text: String) -> String:
	var leaf: String = pattern_text
	if leaf.length() >= 2 and leaf.begins_with("\"") and leaf.ends_with("\""):
		return leaf.substr(1, leaf.length() - 2)
	var last_dot: int = leaf.rfind(".")
	if last_dot >= 0 and last_dot < leaf.length() - 1:
		return leaf.substr(last_dot + 1)
	return leaf


## The Inspector section a folder strip names: the group, plus the subsection when every row in the
## run shares one - which is what the per-row "Group › Subgroup" chip used to say, said once.
static func _folder_strip_label(_owner: ViewportRowBuilder, group_name: String, members: Array[EventRowData]) -> String:
	var shared_subgroup: String = ""
	for index: int in members.size():
		var row: EventRowData = members[index]
		var metadata: Dictionary = row.spans[0].metadata if not row.spans.is_empty() \
			and row.spans[0].metadata is Dictionary else {}
		var subgroup: String = str(metadata.get("variable_subgroup", "")).strip_edges()
		if index == 0:
			shared_subgroup = subgroup
		elif subgroup != shared_subgroup:
			return group_name
	return group_name if shared_subgroup.is_empty() else "%s › %s" % [group_name, shared_subgroup]


## The type word a literal gives away, "" when the value settles nothing. An expression default is
## stored as SOURCE TEXT (`300.0`, `"idle"`, `[]`), so the shapes are matched as written; a real
## Variant default is matched by its actual type.
static func _inferred_type_word(default_value: Variant, expression_default: bool) -> String:
	if not expression_default:
		match typeof(default_value):
			TYPE_STRING, TYPE_STRING_NAME:
				return ViewportRowBuilder.friendly_type_word("String")
			TYPE_INT, TYPE_FLOAT:
				# An undeclared number reads "number" whichever literal it was: nothing in
				# `var hp := 100` says the author refused fractions, and "whole number" would.
				return ViewportRowBuilder.friendly_type_word("float")
			TYPE_BOOL:
				return ViewportRowBuilder.friendly_type_word("bool")
			TYPE_ARRAY:
				return ViewportRowBuilder.friendly_type_word("Array")
			TYPE_DICTIONARY:
				return ViewportRowBuilder.friendly_type_word("Dictionary")
		return ""
	var text: String = str(default_value).strip_edges()
	if text.is_empty():
		return ""
	if text == "true" or text == "false":
		return ViewportRowBuilder.friendly_type_word("bool")
	if text.begins_with("\"") or text.begins_with("'"):
		return ViewportRowBuilder.friendly_type_word("String")
	if text.begins_with("["):
		return ViewportRowBuilder.friendly_type_word("Array")
	if text.begins_with("{"):
		return ViewportRowBuilder.friendly_type_word("Dictionary")
	if text.is_valid_float():
		return ViewportRowBuilder.friendly_type_word("float")
	# The two constructor spellings a reader meets constantly. `var tint := Color.WHITE` is a
	# colour and `var home := Vector2.ZERO` is a vector; reading either as "any" would tell them less
	# than the value in front of them already does.
	for constructed: String in ["Color", "Vector2", "Vector3", "Vector4"]:
		if text.begins_with("%s." % constructed) or text.begins_with("%s(" % constructed):
			return ViewportRowBuilder.friendly_type_word(constructed)
	# A made object - `var _stats := Patrol.new()` - is of the class that made it, the same answer the
	# code type gives (NativeVariableMarks.gdscript_type_word), so the row never says "any" for it.
	if text.contains(".new("):
		var made: String = ViewportRowBuilder.NativeVariableMarks.gdscript_type_word("", text, true)
		if made != "Variant":
			return ViewportRowBuilder.friendly_type_word(made)
	return ""


static func _repeating_timers(_owner: ViewportRowBuilder) -> Dictionary:
	var sheet: EventSheetResource = _owner._viewport._sheet
	var stamp: int = 0 if sheet == null else int(sheet.get_instance_id())
	if stamp == _owner._repeat_timers_stamp:
		return _owner._repeat_timers
	_owner._repeat_timers_stamp = stamp
	_owner._repeat_timers = {}
	if sheet == null:
		return _owner._repeat_timers
	var statements: PackedStringArray = PackedStringArray()
	_collect_statement_text(_owner, sheet.events, statements)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			_collect_statement_text(_owner, (entry as EventFunction).events, statements)
	if ViewportRowBuilder._timer_wait_regex == null:
		ViewportRowBuilder._timer_wait_regex = RegEx.new()
		if ViewportRowBuilder._timer_wait_regex.compile("^([^\\s=]+)\\.wait_time\\s*=\\s*(.+)$") != OK:
			return _owner._repeat_timers
	if ViewportRowBuilder._timer_one_shot_regex == null:
		ViewportRowBuilder._timer_one_shot_regex = RegEx.new()
		if ViewportRowBuilder._timer_one_shot_regex.compile("^([^\\s=]+)\\.one_shot\\s*=\\s*(true|false)$") != OK:
			return _owner._repeat_timers
	var wait_regex: RegEx = ViewportRowBuilder._timer_wait_regex
	var one_shot_regex: RegEx = ViewportRowBuilder._timer_one_shot_regex
	var waits: Dictionary = {}
	var one_shot: Dictionary = {}
	for statement: String in statements:
		var text: String = statement.strip_edges()
		var wait_match: RegExMatch = wait_regex.search(text)
		if wait_match != null:
			waits[timer_node_name(wait_match.get_string(1))] = wait_match.get_string(2).strip_edges()
			continue
		var shot_match: RegExMatch = one_shot_regex.search(text)
		if shot_match != null and shot_match.get_string(2) == "true":
			one_shot[timer_node_name(shot_match.get_string(1))] = true
	for node_name: String in waits.keys():
		if not one_shot.has(node_name):
			_owner._repeat_timers[node_name] = str(waits[node_name])
	return _owner._repeat_timers


## The bare node NAME behind any of the spellings a script reaches a Timer with - `$SpawnTimer`,
## `%Spawn`, `get_node("Timers/Spawn")`, a plain member. "" when there is no name to read.
static func timer_node_name(reference: String) -> String:
	var text: String = reference.strip_edges()
	if text.begins_with("get_node(") and text.ends_with(")"):
		text = text.substr(9, text.length() - 10).strip_edges()
	text = text.lstrip("$%").strip_edges()
	text = text.trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
	if text.contains("/"):
		text = text.get_slice("/", text.get_slice_count("/") - 1)
	return text.strip_edges()


## Every statement the sheet holds, as source text - what the Timer scan reads. Recursive through
## events, sub-events and groups; an ACE contributes the line it compiles to, a verbatim block its
## own lines. Non-mutating.
static func _collect_statement_text(_owner: ViewportRowBuilder, rows: Array, into: PackedStringArray) -> void:
	for row: Variant in rows:
		if row is RawCodeRow:
			into.append_array((row as RawCodeRow).code.split("\n"))
		elif row is ACEAction:
			var generated: String = ActionCodegen.generate_action(row as ACEAction)
			if not generated.is_empty():
				into.append_array(generated.split("\n"))
		elif row is EventGroup:
			_collect_statement_text(_owner, _owner._viewport._group_children(row as EventGroup), into)
		elif row is EventRow:
			var event_row: EventRow = row as EventRow
			_collect_statement_text(_owner, event_row.actions, into)
			_collect_statement_text(_owner, event_row.sub_events, into)


## The action cell for a `super` call: `Include <file> ▸ run its On Ready` / `▸ Call Take Damage x`.
static func _append_super_call_spans(_owner: ViewportRowBuilder, spans: Array[SemanticSpan], reading: Dictionary, action_index: int, action_line_index: int, action_style_meta: Dictionary) -> void:
	var base_meta: Dictionary = {
		"lane": "action",
		"kind": "action",
		"ace_index": action_index,
		"ace_enabled": true,
		"chip": true,
		"code_cell": false,
		"natural_width": true,
		"line_index": action_line_index
	}
	spans.append(_owner._make_span(EventSheetL10n.translate("Include"), SemanticSpan.SpanType.VALUE,
		base_meta.duplicate().merged({"text_color": _owner._viewport._get_reading_style().muted_text_color}, true).merged(action_style_meta, false)))
	spans.append(_owner._make_span(str(reading.get("file", "")), SemanticSpan.SpanType.KEYWORD,
		base_meta.duplicate().merged({
			"text_color": _owner._viewport._get_event_style().object_label_color
		}, true).merged(action_style_meta, false)))
	var runs: String = str(reading.get("runs", ""))
	var tail: String = ""
	if not runs.is_empty():
		tail = "%s %s" % [EventSheetL10n.translate("▸ run its"), runs]
	else:
		tail = "%s %s" % [EventSheetL10n.translate("▸ Call"), str(reading.get("verb", ""))]
	var args: String = str(reading.get("args", ""))
	if not args.is_empty():
		tail = "%s  %s" % [tail, args]
	spans.append(_owner._make_span(tail, SemanticSpan.SpanType.ACTION, base_meta.duplicate().merged({
		"natural_width": false,
		"text_color": _owner._viewport._get_reading_style().primary_text_color
	}, true).merged(action_style_meta, false)))


## The header spans of a function that IS an await beat: the repeating badge, the words, and the
## muted note saying the beat only runs while the loop does.
static func _await_loop_trigger_spans(_owner: ViewportRowBuilder, seconds: String) -> Array[SemanticSpan]:
	var badge_meta: Dictionary = _owner._viewport.BADGE_TRIGGER_METADATA.duplicate(true)
	badge_meta["tempo"] = TriggerResolver.TEMPO_EVERY_TICK
	badge_meta["badge_bg"] = _owner._viewport._get_reading_style().tempo_every_tick_background_color
	badge_meta["badge_fg"] = _owner._viewport._get_reading_style().tempo_every_tick_foreground_color
	badge_meta["badge_style"] = "trigger"
	badge_meta["kind"] = "raw_code"
	badge_meta["line_index"] = 0
	return [
		_owner._make_span("⟳", SemanticSpan.SpanType.KEYWORD, badge_meta),
		_owner._make_span(EventSheetL10n.translate("System"), SemanticSpan.SpanType.OBJECT, {
			"editable": false,
			"kind": "raw_code",
			"line_index": 0,
			"text_color": _owner._viewport._get_event_style().object_label_color
		}),
		_owner._make_span(EventSheetL10n.translate("Every %s seconds") % seconds, SemanticSpan.SpanType.CONDITION, {
			"editable": false,
			"kind": "raw_code",
			"line_index": 0,
			"text_color": _owner._viewport._get_reading_style().primary_text_color
		}),
		_owner._make_span(EventSheetL10n.translate("(while running)"), SemanticSpan.SpanType.COMMENT, {
			"editable": false,
			"kind": "raw_code",
			"line_index": 0,
			"text_color": _owner._viewport._get_reading_style().muted_text_color
		})
	]


## The project's global script class named `class_text` ({class, base, icon, path}), or {}. Read
## from an index of the class list built once per row build, not by walking the list per name.
static func _global_script_class(class_text: String) -> Dictionary:
	if not ViewportRowBuilder._global_class_index_built:
		ViewportRowBuilder._global_class_index = {}
		for entry: Dictionary in ProjectSettings.get_global_class_list():
			ViewportRowBuilder._global_class_index[str(entry.get("class", ""))] = entry
		ViewportRowBuilder._global_class_index_built = true
	return ViewportRowBuilder._global_class_index.get(class_text, {})


## The undo-step row's own cell: the local that catches the answer, the step's name in the words
## Undo will show, and the cue that what follows is the edit. Pure view - the RawCodeRow keeps every
## line it had, so the byte round-trip is untouched and a double-click still opens the statement.
static func _append_undo_step_spans(_owner: ViewportRowBuilder, spans: Array, parts: Dictionary, action_index: int, line_index: int, action_style_meta: Dictionary) -> void:
	var context: Dictionary = _owner.sentence_context()
	var object_name: String = EventSheetSentence.helper_object(str(parts.get("receiver", "")), context)
	if object_name.is_empty():
		object_name = EventSheetSentence.object_of_reference(str(parts.get("receiver", "")))
	var step_text: String = "%s ▸ %s \"%s\"" % [object_name,
		EventSheetL10n.translate("Edit sheet undoably"), str(parts.get("label", ""))]
	var base_meta: Dictionary = {
		"lane": "action",
		"kind": "action",
		"ace_index": action_index,
		"raw_action": true,
		"code_cell": false,
		"chip": true,
		"line_index": line_index
	}
	var type_word: String = ViewportRowBuilder.friendly_type_word(str(parts.get("type_word", "")))
	# The local that catches the answer reads as a local line: its icon, its name, its type.
	spans.append(_owner._make_span(type_word, SemanticSpan.SpanType.VALUE, base_meta.duplicate().merged({
			"natural_width": true,
			"object_label": str(parts.get("name", "")),
			"object_glyph": ViewportRowBuilder.NativeRowMarks.OBJECT_GLYPH_LOCAL,
			"object_icon": _owner._glyph_icon_slot(),
			"local_name": str(parts.get("name", "")),
			"text_color": _owner._viewport._get_event_style().object_label_color
		}, true).merged(action_style_meta, false)))
	spans.append(_owner._make_span("= %s" % step_text, SemanticSpan.SpanType.VALUE,
		base_meta.duplicate().merged({
			"natural_width": true,
			"text_color": _owner._viewport._get_event_style().value_highlight_color
		}, true).merged(action_style_meta, false)))
	spans.append(_owner._make_span(EventSheetL10n.translate("↓ the steps below are the edit"),
		SemanticSpan.SpanType.VALUE, base_meta.duplicate().merged({
			"text_color": _owner._viewport._get_reading_style().muted_text_color
		}, true).merged(action_style_meta, false)))


## Stamps a lifted body row (and everything under it) as a READING of the connect statement: the
## resource it points at is the event the file holds, and the anchor uid is what makes the whole
## reading behave as that one statement rather than as rows of its own.
static func _mark_connect_reading(_owner: ViewportRowBuilder, row_data: EventRowData, event_row: EventRow, anchor: String, action_index: int) -> void:
	if row_data == null:
		return
	# Spans are normally built lazily FROM source_resource, and this row's source is about to become
	# the event the file holds rather than the lifted stand-in it was read from - so its cells are
	# built here, while the stand-in is still what it points at. A row that already has spans is
	# never rebuilt, which is exactly what keeps the reading and the routing from fighting.
	# A reading invites nothing: there is no row here to edit - only one connect statement, which is
	# what a double-click anywhere on this reading opens.
	_owner._keep_reading_spans(row_data)
	row_data.source_resource = event_row
	row_data.row_uid = "%s_%s" % [anchor, row_data.row_uid]
	row_data.ternary_view = true
	row_data.ternary_anchor_uid = anchor
	row_data.ternary_lead = false
	row_data.ternary_action_index = action_index
	for child: EventRowData in row_data.children:
		_mark_connect_reading(_owner, child, event_row, anchor, action_index)


## What a pick FILTERS on, as one line: the legacy predicate expression when the filter carries
## one, else its structured filter conditions joined the way they compile (AND or OR). Read through
## the same operator glyphs a condition row uses, so `hp < 10` looks the same wherever it is shown.
static func _pick_test_text(_owner: ViewportRowBuilder, pick: PickFilter) -> String:
	var predicate: String = pick.predicate_expression.strip_edges()
	if not predicate.is_empty():
		return EventSheetSentence.comparison_symbols(predicate)
	var terms: PackedStringArray = PackedStringArray()
	for entry: Variant in pick.filter_conditions:
		if not (entry is ACECondition) or not (entry as ACECondition).enabled:
			continue
		# An inverted comparison shows its opposite here too, exactly as it does on a condition row
		# and exactly as the filter compiles - one spelling of the same question everywhere.
		var reading: ACECondition = _owner._comparison_flip_of(entry as ACECondition)
		var term: String = ViewportRowBuilder.ReadingDoors.compiler().condition_source_text(reading).strip_edges()
		if term.is_empty():
			continue
		terms.append("%s %s" % [EventSheetL10n.translate("not"), term] if reading.negated else term)
	if terms.is_empty():
		return ""
	var joiner: String = " %s " % EventSheetL10n.translate("or" if pick.filter_mode == 1 else "and")
	return EventSheetSentence.comparison_symbols(joiner.join(terms))


## A reflected `method:<name>` id as a readable sentence with the row's own values in call
## order ("Can Afford Entry ( slot_id )"). Shared by the condition and action fallbacks so
## both lanes read the same way when the registry has no definition; returns the id
## unchanged for anything that is not a reflected member.
static func _reflected_member_sentence(_owner: ViewportRowBuilder, ace_id: String, params_dict: Dictionary) -> String:
	if not ace_id.begins_with("method:"):
		return ace_id
	var shown: PackedStringArray = PackedStringArray()
	for param_key: Variant in params_dict.keys():
		if str(param_key) == "target":
			continue
		shown.append(str(params_dict[param_key]))
	var member_label: String = ace_id.trim_prefix("method:").trim_prefix("_").capitalize()
	return member_label if shown.is_empty() else "%s ( %s )" % [member_label, ", ".join(shown)]


## The whole event read as ONE plain-English sentence for the hover tooltip - "When <trigger> - if <c1>
## and <c2> - do: <a1>, <a2> (+1 more)". Assembled EXCLUSIVELY from the same descriptor strings the cells
## draw (the _base formatters, which don't touch the bbcode render flag), so it can NEVER disagree with
## the row. In-flow RawCode actions have no descriptor, so they summarise honestly as "then N lines of
## code" - the sentence never invents prose for raw statements. "" when there is nothing to say.
static func row_sentence(_owner: ViewportRowBuilder, event_row: EventRow) -> String:
	if event_row == null:
		return ""
	var head: String = _sentence_head(_owner, event_row)
	var conditions_clause: String = _sentence_conditions(_owner, event_row)
	var actions_clause: String = _sentence_actions(_owner, event_row)
	var clauses: PackedStringArray = PackedStringArray()
	if not head.is_empty():
		if head == "Else if" and not conditions_clause.is_empty():
			clauses.append("%s %s" % [head, conditions_clause])
		elif not conditions_clause.is_empty():
			clauses.append(head)
			clauses.append("if %s" % conditions_clause)
		else:
			clauses.append(head)
	elif not conditions_clause.is_empty():
		clauses.append("If %s" % conditions_clause)
	if not actions_clause.is_empty():
		clauses.append(actions_clause)
	# The hover is plain text: a descriptor that emphasises its values (Keep [b]hp[/b] between ...)
	# drew its tags as letters there.
	var sentence: String = " - ".join(clauses)
	return EventSheetBBCodeLite.strip(sentence) if EventSheetBBCodeLite.has_markup(sentence) else sentence


static func _sentence_head(_owner: ViewportRowBuilder, event_row: EventRow) -> String:
	if event_row.else_mode == EventRow.ElseMode.ELSE:
		return "Else"
	if event_row.else_mode == EventRow.ElseMode.ELIF:
		return "Else if"
	# A blank top-level event, and an every-frame handler carrying no condition of its own, are
	# the same event: the empty condition lane says it runs every tick, and the hover says so in words.
	if not _owner._blank_tick_reading(event_row).is_empty():
		return EventSheetL10n.translate("Runs every tick")
	var trigger_text: String = _sentence_trigger(_owner, event_row)
	return "When %s" % trigger_text if not trigger_text.is_empty() else ""


static func _sentence_trigger(_owner: ViewportRowBuilder, event_row: EventRow) -> String:
	if event_row.trigger != null:
		return _owner._format_condition_descriptor_base(event_row.trigger)
	if not event_row.trigger_id.is_empty():
		return str(ViewportRowBuilder._FRIENDLY_TRIGGER.get(event_row.trigger_id, event_row.trigger_id.capitalize()))
	var inline_index: int = _owner._find_inline_trigger_condition_index(event_row)
	if inline_index >= 0 and inline_index < event_row.conditions.size():
		return _owner._format_condition_descriptor_base(event_row.conditions[inline_index])
	return ""


static func _sentence_conditions(_owner: ViewportRowBuilder, event_row: EventRow) -> String:
	var inline_trigger_index: int = _owner._find_inline_trigger_condition_index(event_row)
	var texts: PackedStringArray = PackedStringArray()
	for condition_index in range(event_row.conditions.size()):
		if condition_index == inline_trigger_index:
			continue  # the inline trigger reads as the head, not a condition
		var condition: ACECondition = event_row.conditions[condition_index]
		if condition == null:
			continue
		var text: String = _owner._format_condition_descriptor_base(condition)
		if condition.negated:
			text = "not " + text
		texts.append(text)
	if texts.is_empty():
		return ""
	var joiner: String = " or " if event_row.condition_mode == EventRow.ConditionMode.OR else " and "
	return joiner.join(texts)


static func _sentence_actions(_owner: ViewportRowBuilder, event_row: EventRow) -> String:
	var descriptors: PackedStringArray = PackedStringArray()
	var raw_lines: int = 0
	for action_variant: Variant in event_row.actions:
		if action_variant is ACEAction:
			descriptors.append(_owner._format_action_descriptor_base(action_variant as ACEAction))
		elif action_variant is RawCodeRow:
			var code: String = (action_variant as RawCodeRow).code.strip_edges()
			if not code.is_empty():
				raw_lines += code.split("\n").size()
	var shown: int = mini(descriptors.size(), ViewportRowBuilder._SENTENCE_MAX_ACTIONS)
	var pieces: PackedStringArray = PackedStringArray()
	for index: int in range(shown):
		pieces.append(descriptors[index])
	var body: String = ", ".join(pieces)
	var remaining: int = descriptors.size() - shown
	if remaining > 0:
		body += " (+%d more)" % remaining
	if raw_lines > 0:
		body += ("" if body.is_empty() else ", ") + "then %d %s of code" % [raw_lines, "line" if raw_lines == 1 else "lines"]
	return "do: %s" % body if not body.is_empty() else ""


## The statement split in two so the VALUE can wear its own picture: the sentence up to the value
## (carrying the subject's icon, its object label and its note), then the value itself with the class
## icon the sentence layer named, then whatever the sentence said after it. An icon draws at the
## START of the span it is on, which is exactly why the value needs a span of its own.
##
## False when the sentence has no value piece to split at, which is the caller's cue to keep the
## single-span reading it has today. Display only: every span carries the same row identity
## (`ace_index`, `line_index`, `raw_action`), so selection, editing and the emitted bytes are the
## statement's, untouched - the same shape the multi-line-literal split already uses.
static func _append_value_icon_sentence_spans(_owner: ViewportRowBuilder, spans: Array, pieces: Array, indent: int, object_label: String, object_note: String, sentence_icon: Texture2D, value_icon: Texture2D, raw: RawCodeRow, action_index: int, line_index: int, action_style_meta: Dictionary) -> bool:
	var value_at: int = -1
	for piece_index: int in pieces.size():
		if str((pieces[piece_index] as Array)[1]) == "value":
			value_at = piece_index
			break
	if value_at < 0:
		return false
	var head_pieces: Array = pieces.slice(0, value_at)
	var value_pieces: Array = pieces.slice(value_at, value_at + 1)
	var tail_pieces: Array = pieces.slice(value_at + 1)
	var base_meta: Dictionary = {
		"lane": "action",
		"kind": "action",
		"ace_index": action_index,
		"ace_enabled": raw.enabled,
		"chip": true,
		"raw_action": true,
		"code_cell": false,
		"line_index": line_index
	}
	var head_text: String = "    ".repeat(indent)
	for piece: Array in head_pieces:
		head_text += str(piece[0])
	spans.append(_owner._make_span(head_text, SemanticSpan.SpanType.VALUE, base_meta.duplicate().merged({
		"natural_width": true,
		"object_label": object_label,
		"object_note": object_note,
		"bbcode_segments": _owner._sentence_tone_segments(head_pieces, indent),
		"object_icon": sentence_icon
	}, true).merged(action_style_meta, false)))
	var value_meta: Dictionary = base_meta.duplicate().merged({
		"bbcode_segments": _owner._sentence_tone_segments(value_pieces, 0),
		"object_icon": value_icon
	}, true)
	# The LAST span of a row fills the cell; every earlier one is as wide as its own words.
	if not tail_pieces.is_empty():
		value_meta["natural_width"] = true
	spans.append(_owner._make_span(str((value_pieces[0] as Array)[0]), SemanticSpan.SpanType.VALUE,
		value_meta.merged(action_style_meta, false)))
	if tail_pieces.is_empty():
		return true
	var tail_text: String = ""
	for piece: Array in tail_pieces:
		tail_text += str(piece[0])
	spans.append(_owner._make_span(tail_text, SemanticSpan.SpanType.VALUE, base_meta.duplicate().merged({
		"bbcode_segments": _owner._sentence_tone_segments(tail_pieces, 0)
	}, true).merged(action_style_meta, false)))
	return true


## What an `await` says in event-sheet words. An event sheet has "Wait for signal" as a System
## action and counts ticks, so suspending on a signal reads as that action and suspending on a frame
## reads as the one tick it is. Returns {} for every other await (a timer wait already has its own
## "Wait N seconds" reading, and an await on a call keeps its GDScript) - a sentence must never paper
## over a suspension point it cannot name.
##
## `hourglass` is the RAW-line form: a lifted ACE row gets the ⏳ from the await chip the descriptor
## formatter adds, but a hand-written line has no chip, so the glyph belongs in the sentence.
##
## NOTE for merge: this lives here rather than in the sentence grammar only because the grammar file
## was being edited elsewhere at the time; its natural home is beside _await_statement().
static func await_reading(expression: String, hourglass: bool, context: Dictionary = {}) -> Dictionary:
	var text: String = expression.strip_edges()
	if text == "get_tree().process_frame":
		return _slot_sentence(EventSheetSentence.OBJECT_SYSTEM, "Wait one tick", {}, hourglass)
	if text == "get_tree().physics_frame":
		return _slot_sentence(EventSheetSentence.OBJECT_SYSTEM, "Wait one physics tick", {}, hourglass)
	# Waiting on a tween is waiting for the animation to end, which is the whole thought; the
	# local's name adds nothing a reader of the Tween rows above it does not already have.
	if text.ends_with(".finished") and EventSheetSentence.is_tween_local(
			text.substr(0, text.length() - 9), context):
		return _slot_sentence(EventSheetSentence.OBJECT_SYSTEM, "Wait for tween to finish", {}, hourglass)
	# A call anywhere in the expression is not a signal reference: `create_timer(x).timeout` is the
	# timer wait, which already reads as its own seconds sentence.
	if text.contains("(") or text.contains(")"):
		return {}
	var dot_at: int = text.rfind(".")
	if dot_at <= 0 or dot_at + 1 >= text.length():
		return {}
	var signal_bare: String = text.substr(dot_at + 1)
	if not EventSheetSentence.is_identifier(signal_bare):
		return {}
	var object_word: String = ViewportRowBuilder._await_object_word(text.substr(0, dot_at))
	if object_word.is_empty():
		return {}
	return _slot_sentence(EventSheetSentence.OBJECT_SYSTEM, "Wait for signal {object} {trigger}", {
		"object": [object_word, "name"],
		"trigger": ["On %s" % signal_bare.capitalize(), "name"]
	}, hourglass)


## The grammar's own {slot} template fill, kept locally so a new reading can be added without
## reaching into the sentence file: each `{slot}` becomes its own toned segment, so a locale may
## reorder the sentence and the emphasis still lands on the values.
static func _slot_sentence(object_name: String, template: String, values: Dictionary, hourglass: bool = false) -> Dictionary:
	var rest: String = EventSheetL10n.translate(template)
	var segments: Array = []
	if hourglass:
		# The suspension glyph rides OUTSIDE the translated template, so a locale translates the
		# words alone and every reading of an await wears the same mark the await chip draws.
		segments.append({"text": "⏳ ", "tone": "plain"})
	var guard: int = 0
	while guard < 12:
		guard += 1
		var next_slot: String = ""
		var next_at: int = -1
		for slot: String in values.keys():
			var at: int = rest.find("{%s}" % slot)
			if at >= 0 and (next_at < 0 or at < next_at):
				next_at = at
				next_slot = slot
		if next_at < 0:
			break
		if next_at > 0:
			segments.append({"text": rest.substr(0, next_at), "tone": "plain"})
		var pair: Array = values[next_slot]
		segments.append({"text": str(pair[0]), "tone": str(pair[1])})
		rest = rest.substr(next_at + next_slot.length() + 2)
	if not rest.is_empty():
		segments.append({"text": rest, "tone": "plain"})
	return {"object": object_name, "segments": segments}


## The speed test one of the six body rows compiles to. The 3D rows ask the opposite sign of the
## vertical question, because Y grows upward there - and the grammar turns each back into the same
## word the 2D row reads, which is the whole point of asking it this way.
static func _body_speed_test(_owner: ViewportRowBuilder, ace_id: String) -> String:
	match ace_id:
		"IsJumping":
			return "velocity.y < 0"
		"IsFalling":
			return "velocity.y > 0"
		"IsJumping3D":
			return "velocity.y > 0"
		"IsFalling3D":
			return "velocity.y < 0"
	return "velocity.x != 0"


## The GDScript line a lifted Start Timer / Stop Timer row stands for, so the row reads through
## the SAME timer sentence a hand-written `$Timer.start(2.0)` reads through. "" when the row acts on
## the host rather than on a named node: a timer with no node path has no tag to name, and the row
## keeps the shipped format rather than inventing one.
static func timer_ace_code(ace_id: String, params_dict: Dictionary) -> String:
	var target: String = str(params_dict.get("target", "")).strip_edges()
	if target.is_empty():
		return ""
	if ace_id == "StopTimer":
		return "%s.stop()" % target
	var seconds: String = str(params_dict.get("time", "")).strip_edges()
	# `-1` is the descriptor's "use the Timer's own wait_time", which is the no-seconds sentence.
	if seconds.is_empty() or seconds == "-1":
		return "%s.start()" % target
	return "%s.start(%s)" % [target, seconds]


static func _get_variable_metadata_for_row(_owner: ViewportRowBuilder, row_data: EventRowData) -> Dictionary:
	if row_data == null:
		return {}
	for span in row_data.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		var metadata: Dictionary = span.metadata as Dictionary
		if str(metadata.get("kind", "")) == "variable":
			return metadata.duplicate(true)
	return {}


## One arrangement header: the head-folder archetype, titled with the bucket's own word and noting
## how many events read under it. Null source (nothing to select, drag or delete - it is a lens, not
## a resource) and its fold remembered per session through the shared fold state, keyed on a uid that
## carries the mode so switching arrangements never inherits another one's folds.
static func _build_arrangement_header_row(_owner: ViewportRowBuilder, sheet: EventSheetResource, mode: int, bucket_index: int, title: String, members: Array[EventRowData]) -> EventRowData:
	var subtitle: String = EventSheetL10n.translate("1 event")
	if members.size() != 1:
		subtitle = EventSheetL10n.translate("%d events") % members.size()
	var row_data: EventRowData = _owner._build_head_group_row(sheet,
		"arrange_%s_%d" % [EventSheetArrangement.mode_id(mode), bucket_index],
		title, subtitle, members)
	row_data.folded = bool(_owner._viewport._fold_state.get(row_data.row_uid, false))
	return row_data


## The LAST action of a camera-ray run starting at `first`, or -1 when the lines there are
## not one. Every step is required: two halves of a ray with no query built from them are two
## ordinary declarations, and reading them as a question would be exactly the confident lie this
## grammar refuses. The mask line is the one optional member, because a ray restricted to the floor
## and one that sees everything are the same question asked with a filter.
static func _cursor_ray_run_end(_owner: ViewportRowBuilder, actions: Array, first: int) -> int:
	var origin: Dictionary = EventSheetSentence.cursor_ray_step_parts(
		_cursor_ray_declared_value(_owner, _owner._group_line_text(actions[first])))
	if str(origin.get("step", "")) != "project_ray_origin":
		return -1
	var origin_name: String = _cursor_ray_declared_name(_owner, _owner._group_line_text(actions[first]))
	if origin_name.is_empty():
		return -1
	var direction: Dictionary = EventSheetSentence.cursor_ray_step_parts(
		_cursor_ray_declared_value(_owner, _owner._group_line_text(actions[first + 1])))
	if str(direction.get("step", "")) != "project_ray_normal":
		return -1
	if str(direction.get("point", "")) != str(origin.get("point", "")):
		return -1
	if str(direction.get("camera", "")) != str(origin.get("camera", "")):
		return -1
	var direction_name: String = _cursor_ray_declared_name(_owner, _owner._group_line_text(actions[first + 1]))
	var query: Dictionary = EventSheetSentence.cursor_ray_step_parts(
		_cursor_ray_declared_value(_owner, _owner._group_line_text(actions[first + 2])))
	if str(query.get("step", "")) != "query":
		return -1
	if EventSheetSentence.cursor_ray_reach(str(query.get("to", "")), origin_name, direction_name).is_empty():
		return -1
	var query_name: String = _cursor_ray_declared_name(_owner, _owner._group_line_text(actions[first + 2]))
	if query_name.is_empty():
		return -1
	var cast_at: int = first + 3
	if _owner._cursor_ray_mask_target(_owner._group_line_text(actions[cast_at])) == query_name:
		cast_at += 1
	if cast_at >= actions.size():
		return -1
	var cast: Dictionary = EventSheetSentence.cursor_ray_step_parts(
		_cursor_ray_declared_value(_owner, _owner._group_line_text(actions[cast_at])))
	if str(cast.get("step", "")) != "cast" or str(cast.get("query", "")) != query_name:
		return -1
	return cast_at


## The name a `var x := …` line declares, or "" when the line declares nothing.
static func _cursor_ray_declared_name(_owner: ViewportRowBuilder, text: String) -> String:
	var bare: String = text.strip_edges()
	if not bare.begins_with("var "):
		return ""
	for separator: String in [" := ", " = "]:
		var at: int = bare.find(separator)
		if at < 0:
			continue
		var name_text: String = bare.substr(4, at - 4).strip_edges()
		var colon_at: int = name_text.find(":")
		if colon_at >= 0:
			name_text = name_text.substr(0, colon_at).strip_edges()
		return name_text if EventSheetSentence.is_identifier(name_text) else ""
	return ""


## The value a `var x := …` line is declared from, or "" when the line declares nothing.
static func _cursor_ray_declared_value(_owner: ViewportRowBuilder, text: String) -> String:
	var bare: String = text.strip_edges()
	if not bare.begins_with("var "):
		return ""
	for separator: String in [" := ", " = "]:
		var at: int = bare.find(separator)
		if at >= 0:
			return bare.substr(at + separator.length()).strip_edges()
	return ""


## What THIS run says about itself: how far it reaches, which layers it may see, and the
## object whose canvas position aimed it ("" for the OS pointer). Read off the run's own lines so two
## same-named runs in one file can never borrow each other's numbers.
static func _cursor_ray_run_facts(_owner: ViewportRowBuilder, actions: Array, first: int, last: int) -> Dictionary:
	var origin: Dictionary = EventSheetSentence.cursor_ray_step_parts(
		_cursor_ray_declared_value(_owner, _owner._group_line_text(actions[first])))
	var origin_name: String = _cursor_ray_declared_name(_owner, _owner._group_line_text(actions[first]))
	var direction_name: String = _cursor_ray_declared_name(_owner, _owner._group_line_text(actions[first + 1]))
	var query: Dictionary = EventSheetSentence.cursor_ray_step_parts(
		_cursor_ray_declared_value(_owner, _owner._group_line_text(actions[first + 2])))
	var query_name: String = _cursor_ray_declared_name(_owner, _owner._group_line_text(actions[first + 2]))
	var mask: String = ""
	for index: int in range(first + 3, last + 1):
		var line: String = _owner._group_line_text(actions[index]).strip_edges()
		if _owner._cursor_ray_mask_target(line) != query_name:
			continue
		mask = line.substr(line.find(".collision_mask = ") + 18).strip_edges()
	return {
		"reach": EventSheetSentence.cursor_ray_reach(str(query.get("to", "")), origin_name, direction_name),
		"aimed_at": EventSheetViewportReadingRows.cursor_aim_owner(str(origin.get("point", ""))),
		"mask": mask
	}
