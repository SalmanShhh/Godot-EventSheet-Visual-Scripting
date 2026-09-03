# Godot EventSheets - the view knobs, the scaling words, and the layers.
#
# Twenty-four rows land here across three shelves, and each part of this file holds one promise about
# them:
#
#   1. THE AUTHORED FORM - identity, shelf, host and help straight off the three modules, so a row
#      cannot quietly change which class it belongs to or which page it appears on. Every field
#      carries help too: a dropdown with no words under it is a dropdown nobody can use.
#   2. THE SHIPPED FORM - what the cross-node "On node" pass did to each template. A plain member
#      operation gains the optional prefix and an "On node" field; a template leading with `var` or
#      `await` gains neither and is a self-verb. Both outcomes are deliberate, so both are pinned.
#   3. THE EMITTED CODE - five real sheets compiled, one per host, with the lines pinned exactly and
#      the whole output parse-checked. `{uid}` is baked the way the dock bakes it at apply time.
#   4. THE LIFT - the same output opened back as a sheet. Every row that is a plain member operation
#      comes back as itself, and the whole file re-emits byte for byte either way, which is the
#      lossless contract measured rather than assumed. The rows that do NOT come back as themselves
#      are pinned too, as the ids they DO come back as, because "degrade, never corrupt" is a claim
#      about a specific outcome rather than a hope.
#   5. THE VALUES, RUN FOR REAL - the three families whose emitted code can run with no scene tree
#      at all: the window's content scale (a Window built by hand, standing in for `get_window()`),
#      the relative layer index (two CanvasLayers, the emitted script really executed), and the
#      parallax fractions (a Parallax2D and a ParallaxLayer, written and read back). Smooth Edges
#      With is compiled from the exact text it emits and asked once per word, because a headless run
#      has no rendering server behind the three calls it makes.
#   6. THE QUIET NOTE - keeping pixels sharp and then asking for a fraction. Pure over its own
#      corpus, so the exact sentence a reader meets is pinned rather than a count of findings.
@tool
class_name ViewportAndLayersTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

## The five view rows, the nine rendering rows, and the eleven layer rows, in the order they are
## authored.
const VIEW_ROWS: Array[String] = ["ViewSetSize", "ViewShareWorld2D", "ViewShareWorld3D",
	"ViewSaveStill", "ViewMousePosition"]
const SCALING_ROWS: Array[String] = ["RenderingRender3DAt", "RenderingUpscaleWith",
	"RenderingSmoothEdgesWith", "RenderingSetTaa", "RenderingScaleTheGame", "RenderingFitTheShape",
	"RenderingKeepPixelsSharp", "RenderingPixelSize", "RenderingRendererIs"]
const LAYER_ROWS: Array[String] = ["LayerStayFixedOnScreen", "LayerMoveWithTheWorld",
	"LayerDrawAbove", "LayerDrawBelow", "LayerOffset", "ParallaxScrollAt", "ParallaxRepeatEvery",
	"ParallaxDrift", "ParallaxScrollOffset", "ParallaxLayerScrollAt", "ParallaxLayerRepeatEvery"]

## The one viewport prefix every rendering row shares, spelled once here as it is in the module.
const VIEWPORT_RID := "get_viewport().get_viewport_rid()"


static func run() -> bool:
	var all_passed: bool = true
	var authored: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeViewportACEs.get_descriptors():
		authored[descriptor.ace_id] = descriptor
	for descriptor: ACEDescriptor in EventForgeRenderingACEs.get_descriptors():
		authored[descriptor.ace_id] = descriptor
	for descriptor: ACEDescriptor in EventForgeLayerACEs.get_descriptors():
		authored[descriptor.ace_id] = descriptor
	var shipped: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		shipped[descriptor.ace_id] = descriptor

	all_passed = _pin_authored(authored) and all_passed
	all_passed = _pin_shipped(shipped) and all_passed
	all_passed = _pin_the_reused_rows(shipped) and all_passed
	all_passed = _pin_emitted_views(shipped) and all_passed
	all_passed = _pin_emitted_scaling(shipped) and all_passed
	all_passed = _pin_emitted_layers(shipped) and all_passed
	all_passed = _pin_content_scale_runs(shipped) and all_passed
	all_passed = _pin_layer_index_runs(shipped) and all_passed
	all_passed = _pin_parallax_runs(shipped) and all_passed
	all_passed = _pin_smooth_edges_words(shipped) and all_passed
	all_passed = _pin_the_quiet_note() and all_passed
	return all_passed


## Identity, shelf, host and help, off the modules themselves - before the registry's cross-node
## pass has touched anything.
static func _pin_authored(authored: Dictionary) -> bool:
	var rows: Array = []
	for ace_id: String in VIEW_ROWS + SCALING_ROWS + LAYER_ROWS:
		rows.append(["%s is authored" % ace_id, authored.has(ace_id), true])
	var passed: bool = SUPPORT.pins("viewport_and_layers_test", rows)
	var names: Dictionary = {
		"ViewSetSize": ["Set View Size", "Views", "SubViewport"],
		"ViewShareWorld2D": ["Share The World (2D)", "Views", "SubViewport"],
		"ViewShareWorld3D": ["Share The World (3D)", "Views", "SubViewport"],
		"ViewSaveStill": ["Save A Still Of A View", "Views", ""],
		"ViewMousePosition": ["Mouse Position In View", "Views", ""],
		"RenderingRender3DAt": ["Render 3D At", "Rendering", ""],
		"RenderingUpscaleWith": ["Upscale With", "Rendering", ""],
		"RenderingSmoothEdgesWith": ["Smooth Edges With", "Rendering", ""],
		"RenderingSetTaa": ["Set Temporal AA", "Rendering", ""],
		"RenderingScaleTheGame": ["Scale The Game", "Rendering", ""],
		"RenderingFitTheShape": ["Fit The Shape", "Rendering", ""],
		"RenderingKeepPixelsSharp": ["Keep Pixels Sharp", "Rendering", ""],
		"RenderingPixelSize": ["Pixel Size", "Rendering", ""],
		"RenderingRendererIs": ["Renderer Is", "Rendering", ""],
		"LayerStayFixedOnScreen": ["Stay Fixed On Screen", "Layers", "CanvasLayer"],
		"LayerMoveWithTheWorld": ["Move With The World", "Layers", "CanvasLayer"],
		"LayerDrawAbove": ["Draw Above", "Layers", "CanvasLayer"],
		"LayerDrawBelow": ["Draw Below", "Layers", "CanvasLayer"],
		"LayerOffset": ["Offset Layer", "Layers", "CanvasLayer"],
		"ParallaxScrollAt": ["Scroll At", "Layers", "Parallax2D"],
		"ParallaxRepeatEvery": ["Repeat Every", "Layers", "Parallax2D"],
		"ParallaxDrift": ["Drift", "Layers", "Parallax2D"],
		"ParallaxScrollOffset": ["Scroll Offset", "Layers", "Parallax2D"],
		"ParallaxLayerScrollAt": ["Scroll At (Background Layer)", "Layers", "ParallaxLayer"],
		"ParallaxLayerRepeatEvery": ["Repeat Every (Background Layer)", "Layers", "ParallaxLayer"]
	}
	var kinds: Dictionary = {
		"ViewMousePosition": ACEDescriptor.ACEType.EXPRESSION,
		"ParallaxScrollOffset": ACEDescriptor.ACEType.EXPRESSION,
		"RenderingRendererIs": ACEDescriptor.ACEType.CONDITION
	}
	var detail: Array = []
	var undescribed: PackedStringArray = PackedStringArray()
	for ace_id: String in names:
		if not authored.has(ace_id):
			continue
		var descriptor: ACEDescriptor = authored[ace_id]
		var expected: Array = names[ace_id]
		detail.append(["%s is named for the picker" % ace_id, str(descriptor.display_name), str(expected[0])])
		detail.append(["%s sits on its own shelf" % ace_id, str(descriptor.category), str(expected[1])])
		detail.append(["%s belongs to its host" % ace_id, str(descriptor.node_type), str(expected[2])])
		detail.append(["%s is the right kind of row" % ace_id, descriptor.ace_type,
			kinds.get(ace_id, ACEDescriptor.ACEType.ACTION)])
		if str(descriptor.description).strip_edges().is_empty():
			undescribed.append(ace_id)
		for parameter: ACEParam in descriptor.params:
			if parameter.get_param_description().strip_edges().is_empty():
				undescribed.append("%s.%s" % [ace_id, parameter.id])
	detail.append(["every row, and every field, carries help", ", ".join(undescribed), ""])
	# Two words, one for each dimension, is the promise the 2D and 3D pair makes - and a shelf that
	# had only one of them would be a shelf that answers half the projects that reach for it.
	detail.append(["sharing a world is offered in both dimensions",
		[authored.has("ViewShareWorld2D"), authored.has("ViewShareWorld3D")], [true, true]])
	return SUPPORT.pins("viewport_and_layers_test", detail) and passed


## What the registry's cross-node pass did to each template, and the fields each row asks for.
static func _pin_shipped(shipped: Dictionary) -> bool:
	var rows: Array = [
		["Set View Size writes the one property, under the optional prefix",
			_template(shipped, "ViewSetSize"), "{target.}size = {size}"],
		["Set View Size asks for pixels and then the node", _param_ids(shipped["ViewSetSize"]), "size,target"],
		["Sharing a 2D world reads the OTHER viewport's world",
			_template(shipped, "ViewShareWorld2D"), "{target.}world_2d = {other}.world_2d"],
		["Sharing a 3D world is the same line one dimension up",
			_template(shipped, "ViewShareWorld3D"), "{target.}world_3d = {other}.world_3d"],
		["Sharing a world keeps its own On node field beside the other viewport",
			_param_ids(shipped["ViewShareWorld2D"]), "other,target"],
		["Sharing a world opens on the game's own viewport",
			_default_of(shipped["ViewShareWorld2D"], "other"), "get_viewport()"],
		["Save A Still waits for the frame to finish before it reads anything",
			_template(shipped, "ViewSaveStill"),
			"await RenderingServer.frame_post_draw\n{view}.get_texture().get_image().save_png({path})"],
		["Save A Still gains no On node field, because it leads with an await",
			_param_ids(shipped["ViewSaveStill"]), "view,path"],
		["Save A Still writes where a player can write",
			_default_of(shipped["ViewSaveStill"], "path"), "\"user://still.png\""],
		# A lifted row carries only its ace_id, so an awaiting builtin is recognised by THREE
		# hand-kept lists as well as by the word in its template - and all three are pinned here,
		# because a row in two of them and not the third compiles a coroutine the Doctor cannot see,
		# or one the canvas draws no hourglass on.
		["the compiler knows Save A Still suspends the event",
			SheetCompiler._COROUTINE_ACE_IDS.has("ViewSaveStill"), true],
		["and so does the Doctor",
			EventSheetProjectDoctor.COROUTINE_ACE_IDS.has("ViewSaveStill"), true],
		["and so does the canvas, which draws the hourglass",
			ViewportRowBuilder.action_awaits(_still_row()), true],
		["Mouse Position In View asks one view for its own pointer",
			_template(shipped, "ViewMousePosition"), "{view}.get_mouse_position()"],
		["Render 3D At writes the fraction and then how it is upscaled",
			_template(shipped, "RenderingRender3DAt"),
			"RenderingServer.viewport_set_scaling_3d_scale(%s, {percent} / 100.0)\nRenderingServer.viewport_set_scaling_3d_mode(%s, {method})" % [VIEWPORT_RID, VIEWPORT_RID]],
		["Render 3D At opens at full resolution", _default_of(shipped["RenderingRender3DAt"], "percent"), "100.0"],
		["Smooth Edges With names the chosen word once and then applies it",
			_template(shipped, "RenderingSmoothEdgesWith").begins_with("var __edges_{uid}: String = {how}\n"), true],
		["Smooth Edges With turns every technique it did not pick off",
			[_template(shipped, "RenderingSmoothEdgesWith").contains("viewport_set_screen_space_aa"),
				_template(shipped, "RenderingSmoothEdgesWith").contains("viewport_set_use_taa"),
				_template(shipped, "RenderingSmoothEdgesWith").contains("viewport_set_msaa_3d")],
			[true, true, true]],
		["Smooth Edges With asks one question and no more", _param_ids(shipped["RenderingSmoothEdgesWith"]), "how"],
		["Smooth Edges With offers the six words", _choice_keys(shipped["RenderingSmoothEdgesWith"], "how"),
			"\"none\",\"fxaa\",\"taa\",\"msaa_2x\",\"msaa_4x\",\"msaa_8x\""],
		["Upscale With is the mode line on its own, so a hand-written one reads back",
			_template(shipped, "RenderingUpscaleWith"),
			"RenderingServer.viewport_set_scaling_3d_mode(%s, {method})" % VIEWPORT_RID],
		["Set Temporal AA is the temporal switch on its own, for the same reason",
			_template(shipped, "RenderingSetTaa"),
			"RenderingServer.viewport_set_use_taa(%s, {enabled})" % VIEWPORT_RID],
		["Scale The Game writes the mode on the window",
			_template(shipped, "RenderingScaleTheGame"), "get_window().content_scale_mode = Window.{mode}"],
		["Scale The Game offers the three scaling words", _choice_keys(shipped["RenderingScaleTheGame"], "mode"),
			"CONTENT_SCALE_MODE_CANVAS_ITEMS,CONTENT_SCALE_MODE_VIEWPORT,CONTENT_SCALE_MODE_DISABLED"],
		["Fit The Shape writes the aspect beside it",
			_template(shipped, "RenderingFitTheShape"), "get_window().content_scale_aspect = Window.{aspect}"],
		["Fit The Shape offers every answer Godot has for a different shape",
			_choice_keys(shipped["RenderingFitTheShape"], "aspect"),
			"CONTENT_SCALE_ASPECT_KEEP,CONTENT_SCALE_ASPECT_IGNORE,CONTENT_SCALE_ASPECT_KEEP_WIDTH,CONTENT_SCALE_ASPECT_KEEP_HEIGHT,CONTENT_SCALE_ASPECT_EXPAND"],
		["Keep Pixels Sharp writes the one stretch property",
			_template(shipped, "RenderingKeepPixelsSharp"), "get_window().content_scale_stretch = Window.{stretch}"],
		["Pixel Size writes the one factor", _template(shipped, "RenderingPixelSize"),
			"get_window().content_scale_factor = {factor}"],
		["Renderer Is asks the server which of the three is drawing",
			_template(shipped, "RenderingRendererIs"),
			"RenderingServer.get_current_rendering_method() == {method}"],
		["Renderer Is offers Godot's own three and opens on the one with everything",
			[_choice_keys(shipped["RenderingRendererIs"], "method"),
				_default_of(shipped["RenderingRendererIs"], "method")],
			["\"forward_plus\",\"mobile\",\"gl_compatibility\"", "\"forward_plus\""]],
		["Staying fixed on screen turns the camera follow off",
			_template(shipped, "LayerStayFixedOnScreen"), "{target.}follow_viewport_enabled = false"],
		["Moving with the world turns it on",
			_template(shipped, "LayerMoveWithTheWorld"), "{target.}follow_viewport_enabled = true"],
		["Draw Above is relative to the other layer's own number",
			_template(shipped, "LayerDrawAbove"), "{target.}layer = {other}.layer + 1"],
		["Draw Below is the same line the other way",
			_template(shipped, "LayerDrawBelow"), "{target.}layer = {other}.layer - 1"],
		["Draw Above asks which layer and then which node",
			_param_ids(shipped["LayerDrawAbove"]), "other,target"],
		["Offset Layer moves the layer and nothing on it",
			_template(shipped, "LayerOffset"), "{target.}offset = {by}"],
		["Scroll At writes the modern node's own fraction",
			_template(shipped, "ParallaxScrollAt"), "{target.}scroll_scale = {factor}"],
		["Repeat Every writes the modern node's tiling distance",
			_template(shipped, "ParallaxRepeatEvery"), "{target.}repeat_size = {size}"],
		["Drift writes the modern node's own movement",
			_template(shipped, "ParallaxDrift"), "{target.}autoscroll = {speed}"],
		["Scroll Offset reads how far the layer has scrolled",
			_template(shipped, "ParallaxScrollOffset"), "{target.}scroll_offset"],
		["the same fraction on the older node is motion scale",
			_template(shipped, "ParallaxLayerScrollAt"), "{target.}motion_scale = {factor}"],
		["and the same tiling is motion mirroring",
			_template(shipped, "ParallaxLayerRepeatEvery"), "{target.}motion_mirroring = {size}"],
		["both parallax nodes open on the same fraction",
			[_default_of(shipped["ParallaxScrollAt"], "factor"), _default_of(shipped["ParallaxLayerScrollAt"], "factor")],
			["Vector2(0.5, 1)", "Vector2(0.5, 1)"]]
	]
	return SUPPORT.pins("viewport_and_layers_test", rows)


## The two rows this slice deliberately did NOT mint, because the vocabulary already has them. A
## second row writing the same line would take the reading away from the first, so what is pinned
## here is that the shipped rows still cover the question - including the once-now redraw this slice
## added to the choice list that was already there.
static func _pin_the_reused_rows(shipped: Dictionary) -> bool:
	return SUPPORT.pins("viewport_and_layers_test", [
		["how often a view redraws is still Set Surface Redraw",
			_template(shipped, "SetSurfaceRedraw"), "{target.}render_target_update_mode = SubViewport.{mode}"],
		["and it now offers drawing once, for a thumbnail or a still",
			_choice_keys(shipped["SetSurfaceRedraw"], "mode"),
			"UPDATE_WHEN_VISIBLE,UPDATE_ALWAYS,UPDATE_ONCE,UPDATE_DISABLED"],
		["a view's live picture is still Rendered As An Image",
			_template(shipped, "WindowViewportImage"), "{viewport}.get_texture()"]
	])


## A real SubViewport sheet: size, both worlds, a still and the pointer, in one event.
static func _pin_emitted_views(shipped: Dictionary) -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "SubViewport"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	row.actions.append(_action(shipped, "ViewSetSize", {"size": "Vector2i(200, 120)", "target": ""}, ""))
	row.actions.append(_action(shipped, "ViewShareWorld2D", {"other": "get_viewport()", "target": ""}, ""))
	row.actions.append(_action(shipped, "ViewShareWorld3D", {"other": "get_viewport()", "target": ""}, ""))
	row.actions.append(_action(shipped, "ViewSaveStill",
		{"view": "get_viewport()", "path": "\"user://still.png\""}, ""))
	sheet.events.append(row)
	var output: String = SUPPORT.compile_output(sheet, "user://viewport_views.gd")
	var rows: Array = [
		["the size emits as the one property write", output.contains("\tsize = Vector2i(200, 120)"), true],
		["both worlds emit as one line each",
			output.contains("\tworld_2d = get_viewport().world_2d\n\tworld_3d = get_viewport().world_3d"), true],
		["the still waits for the frame first",
			output.contains("\tawait RenderingServer.frame_post_draw\n\tget_viewport().get_texture().get_image().save_png(\"user://still.png\")"), true],
		["no {uid} token survives into the emitted script", output.contains("{uid}"), false],
		["the compiled view sheet is valid GDScript", _parses(output), true]
	]
	var passed: bool = SUPPORT.pins("viewport_and_layers_test", rows)
	# One deliberate reading is pinned here beside the rows that read back as themselves.
	# SET VIEW SIZE is kept out of the reverse index on purpose (ace_lifter's excluded ids): `size =
	# ...` is a Control's size, a shape's size and a viewport's size all at once, so the row authors
	# and the sentence grammar keeps the reading of that line for every class that has one.
	#
	# THE STILL used to be the second of those: its two lines are each claimed by an older row on
	# their own (the wait by Wait For Signal, the write by Take Screenshot, whose template it is
	# character for character), so a hand-written still opened as two rows and the row that emits it
	# could never read back as itself. It is a RUN now - view_lift.gd - and the pin says so.
	passed = SUPPORT.pins("viewport_and_layers_test", [
		["the size line keeps the reading every class with a size already had, and the still is one row again",
			_lifted_ids(output),
			PackedStringArray(["SetVar", "ViewShareWorld2D", "ViewShareWorld3D", "ViewSaveStill"])]
	]) and passed
	return _pin_lift("views", output, "user://viewport_views_roundtrip.gd",
		["ViewShareWorld2D", "ViewShareWorld3D", "ViewSaveStill"]) and passed


## The scaling sheet: every rendering row this slice added, on a plain Node.
static func _pin_emitted_scaling(shipped: Dictionary) -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	row.actions.append(_action(shipped, "RenderingRender3DAt",
		{"percent": "70.0", "method": "RenderingServer.VIEWPORT_SCALING_3D_MODE_FSR2"}, ""))
	row.actions.append(_action(shipped, "RenderingSmoothEdgesWith", {"how": "\"msaa_4x\""}, "e1"))
	row.actions.append(_action(shipped, "RenderingScaleTheGame", {"mode": "CONTENT_SCALE_MODE_VIEWPORT"}, ""))
	row.actions.append(_action(shipped, "RenderingFitTheShape", {"aspect": "CONTENT_SCALE_ASPECT_KEEP"}, ""))
	row.actions.append(_action(shipped, "RenderingKeepPixelsSharp", {"stretch": "CONTENT_SCALE_STRETCH_INTEGER"}, ""))
	row.actions.append(_action(shipped, "RenderingPixelSize", {"factor": "2.0"}, ""))
	sheet.events.append(row)
	var output: String = SUPPORT.compile_output(sheet, "user://viewport_scaling.gd")
	var rows: Array = [
		["the percentage becomes a fraction in the emitted line",
			output.contains("\tRenderingServer.viewport_set_scaling_3d_scale(%s, 70.0 / 100.0)" % VIEWPORT_RID), true],
		["the upscale method emits beside it",
			output.contains("\tRenderingServer.viewport_set_scaling_3d_mode(%s, RenderingServer.VIEWPORT_SCALING_3D_MODE_FSR2)" % VIEWPORT_RID), true],
		["the chosen word is named once, in a local of its own",
			output.contains("\tvar __edges_e1: String = \"msaa_4x\""), true],
		["and every switch reads that one local",
			output.contains("__edges_e1 == \"taa\""), true],
		["the window scale emits both properties",
			output.contains("\tget_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT\n\tget_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP"), true],
		["whole pixels and the factor emit as they were asked for",
			output.contains("\tget_window().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER\n\tget_window().content_scale_factor = 2.0"), true],
		["no {uid} token survives into the emitted script", output.contains("{uid}"), false],
		["the compiled scaling sheet is valid GDScript", _parses(output), true]
	]
	var passed: bool = SUPPORT.pins("viewport_and_layers_test", rows)
	passed = _pin_lift("scaling", output, "user://viewport_scaling_roundtrip.gd",
		["RenderingScaleTheGame", "RenderingFitTheShape", "RenderingKeepPixelsSharp",
			"RenderingPixelSize"]) and passed
	return _pin_the_macro_rows_degrade(output) and passed


## THE TWO MACRO ROWS, MEASURED RATHER THAN ASSUMED. Render 3D At and Smooth Edges With each write
## several lines, and a several-line row is not something the reverse reader claims as one row - so
## a file holding those lines opens as the SINGLE-LINE rows they are made of. That is the honest
## degradation the contract asks for rather than a failure: every line still comes back as a NAMED
## row (which is why Upscale With and Set Temporal AA ship beside them), nothing is a bare method
## call, nothing is corrupted, and the byte round trip above proves the file is handed back whole.
static func _pin_the_macro_rows_degrade(source: String) -> bool:
	var reopened: EventSheetResource = SUPPORT.reopen(source)
	var lifted: PackedStringArray = PackedStringArray()
	for item: Variant in reopened.events:
		if not (item is EventRow):
			continue
		for entry: Variant in (item as EventRow).actions:
			lifted.append(str((entry as ACEAction).ace_id) if entry is ACEAction else "(verbatim)")
	return SUPPORT.pins("viewport_and_layers_test", [
		["every line of both macro rows reads back as a named row of its own", lifted,
			PackedStringArray(["RenderingSetScaling3DScale", "RenderingUpscaleWith",
				"SetLocalVarTyped", "RenderingSetScreenSpaceAA", "RenderingSetTaa",
				"RenderingSetMsaa3D", "RenderingScaleTheGame", "RenderingFitTheShape",
				"RenderingKeepPixelsSharp", "RenderingPixelSize"])]
	])


## Three layer sheets, one per host, because a CanvasLayer, a Parallax2D and a ParallaxLayer are
## three different classes and a row filed under the wrong one would compile in none of them.
static func _pin_emitted_layers(shipped: Dictionary) -> bool:
	var canvas: EventSheetResource = EventSheetResource.new()
	canvas.host_class = "CanvasLayer"
	var canvas_row: EventRow = EventRow.new()
	canvas_row.trigger_provider_id = "Core"
	canvas_row.trigger_id = "OnReady"
	canvas_row.actions.append(_action(shipped, "LayerStayFixedOnScreen", {"target": ""}, ""))
	canvas_row.actions.append(_action(shipped, "LayerDrawAbove", {"other": "$\"../World\"", "target": ""}, ""))
	canvas_row.actions.append(_action(shipped, "LayerOffset", {"by": "Vector2(0, -32)", "target": ""}, ""))
	canvas.events.append(canvas_row)
	var canvas_output: String = SUPPORT.compile_output(canvas, "user://viewport_canvas_layer.gd")

	var parallax: EventSheetResource = EventSheetResource.new()
	parallax.host_class = "Parallax2D"
	var parallax_row: EventRow = EventRow.new()
	parallax_row.trigger_provider_id = "Core"
	parallax_row.trigger_id = "OnReady"
	parallax_row.actions.append(_action(shipped, "ParallaxScrollAt", {"factor": "Vector2(0.25, 1)", "target": ""}, ""))
	parallax_row.actions.append(_action(shipped, "ParallaxRepeatEvery", {"size": "Vector2(640, 0)", "target": ""}, ""))
	parallax_row.actions.append(_action(shipped, "ParallaxDrift", {"speed": "Vector2(-12, 0)", "target": ""}, ""))
	parallax.events.append(parallax_row)
	var parallax_output: String = SUPPORT.compile_output(parallax, "user://viewport_parallax.gd")

	var older: EventSheetResource = EventSheetResource.new()
	older.host_class = "ParallaxLayer"
	var older_row: EventRow = EventRow.new()
	older_row.trigger_provider_id = "Core"
	older_row.trigger_id = "OnReady"
	older_row.actions.append(_action(shipped, "ParallaxLayerScrollAt", {"factor": "Vector2(0.25, 1)", "target": ""}, ""))
	older_row.actions.append(_action(shipped, "ParallaxLayerRepeatEvery", {"size": "Vector2(640, 0)", "target": ""}, ""))
	older.events.append(older_row)
	var older_output: String = SUPPORT.compile_output(older, "user://viewport_parallax_layer.gd")

	var rows: Array = [
		["a fixed layer emits the follow flag off", canvas_output.contains("\tfollow_viewport_enabled = false"), true],
		["Draw Above emits the other layer's own number plus one",
			canvas_output.contains("\tlayer = $\"../World\".layer + 1"), true],
		["the layer offset emits as one write", canvas_output.contains("\toffset = Vector2(0, -32)"), true],
		["the modern parallax node emits its three properties",
			parallax_output.contains("\tscroll_scale = Vector2(0.25, 1)\n\trepeat_size = Vector2(640, 0)\n\tautoscroll = Vector2(-12, 0)"), true],
		["the older node emits the same two ideas under its own spellings",
			older_output.contains("\tmotion_scale = Vector2(0.25, 1)\n\tmotion_mirroring = Vector2(640, 0)"), true],
		["all three layer sheets are valid GDScript",
			[_parses(canvas_output), _parses(parallax_output), _parses(older_output)], [true, true, true]]
	]
	var passed: bool = SUPPORT.pins("viewport_and_layers_test", rows)
	# Offset Layer is deliberately left out of the lift list: `offset = ...` is a line the shipped
	# Set Offset row (a Camera2D verb on the Camera shelf) already claims, and the vocabulary keeps
	# ONE claimant per line. The row still exists because a CanvasLayer author needs the word on the
	# Layers shelf, it still compiles to exactly the right line, and a file holding that line still
	# reads as "Set offset to ...", which is true of a layer as well as of a camera. What is pinned
	# is that state, so a later change to either row is noticed rather than discovered.
	passed = SUPPORT.pins("viewport_and_layers_test", [
		["the offset line reads back as the shipped Set Offset row it shares",
			_lifted_ids(canvas_output), PackedStringArray(["LayerStayFixedOnScreen", "LayerDrawAbove",
				"SetCameraOffset"])]
	]) and passed
	passed = _pin_lift("canvas layer", canvas_output, "user://viewport_canvas_layer_roundtrip.gd",
		["LayerStayFixedOnScreen", "LayerDrawAbove"]) and passed
	passed = _pin_lift("parallax", parallax_output, "user://viewport_parallax_roundtrip.gd",
		["ParallaxScrollAt", "ParallaxRepeatEvery", "ParallaxDrift"]) and passed
	return _pin_lift("older parallax", older_output, "user://viewport_parallax_layer_roundtrip.gd",
		["ParallaxLayerScrollAt", "ParallaxLayerRepeatEvery"]) and passed


## The lift half, for one compiled sheet: the rows named come back as themselves when the file is
## opened again, and the file re-emits byte for byte whatever the lift claimed. A row nothing claims
## stays honest GDScript, which the byte pin is what actually guarantees.
static func _pin_lift(label: String, source: String, verify_path: String, action_ids: Array) -> bool:
	var reopened: EventSheetResource = SUPPORT.reopen(source)
	var lifted: Array[String] = []
	for item: Variant in reopened.events:
		if not (item is EventRow):
			continue
		for entry: Variant in (item as EventRow).actions:
			if entry is ACEAction:
				lifted.append(str((entry as ACEAction).ace_id))
	var rows: Array = []
	for ace_id: Variant in action_ids:
		rows.append(["%s: a hand-written %s reads back as itself" % [label, ace_id], lifted.has(str(ace_id)), true])
	rows.append(["%s: the reopened sheet re-emits byte for byte" % label,
		SUPPORT.reemit(source, verify_path) == source, true])
	return SUPPORT.pins("viewport_and_layers_test", rows)


## The window rows, run for real. The emitted lines reach the window through `get_window()`, which a
## test has no tree to answer - so a Window built by hand stands in for that ONE call and every
## other character of the emitted text is the shipped one.
static func _pin_content_scale_runs(shipped: Dictionary) -> bool:
	var window: Window = Window.new()
	var script_source: String = "extends RefCounted\n\n\nfunc apply(w: Window) -> void:\n"
	for entry: Array in [["RenderingScaleTheGame", {"mode": "CONTENT_SCALE_MODE_VIEWPORT"}],
			["RenderingFitTheShape", {"aspect": "CONTENT_SCALE_ASPECT_KEEP_WIDTH"}],
			["RenderingKeepPixelsSharp", {"stretch": "CONTENT_SCALE_STRETCH_INTEGER"}],
			["RenderingPixelSize", {"factor": "3.0"}]]:
		var template: String = _template(shipped, str(entry[0]))
		for key: Variant in (entry[1] as Dictionary):
			template = template.replace("{%s}" % key, str((entry[1] as Dictionary)[key]))
		for line: String in template.replace("get_window()", "w").split("\n"):
			script_source += "\t%s\n" % line
	var script: GDScript = GDScript.new()
	script.source_code = script_source
	var loaded: int = script.reload(true)
	var applied: Array = []
	if loaded == OK:
		var runner: RefCounted = script.new()
		runner.call("apply", window)
		applied = [window.content_scale_mode, window.content_scale_aspect,
			window.content_scale_stretch, window.content_scale_factor]
	var rows: Array = [
		["the emitted window lines load", loaded, OK],
		["they land on the window as the words asked for", applied,
			[Window.CONTENT_SCALE_MODE_VIEWPORT, Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH,
				Window.CONTENT_SCALE_STRETCH_INTEGER, 3.0]]
	]
	var passed: bool = SUPPORT.pins("viewport_and_layers_test", rows)
	window.free()
	return passed


## Draw Above and Draw Below, run for real: two CanvasLayers under one parent, the emitted script on
## one of them, and the number it lands on pinned. Neither node is in a scene tree, and neither needs
## to be - `$"../World"` is get_node("../World"), which answers for a node's own siblings.
static func _pin_layer_index_runs(shipped: Dictionary) -> bool:
	var answers: Array = []
	var loads: Array = []
	for entry: Array in [["LayerDrawAbove", 8], ["LayerDrawBelow", 6]]:
		var sheet: EventSheetResource = EventSheetResource.new()
		sheet.host_class = "CanvasLayer"
		var row: EventRow = EventRow.new()
		row.trigger_provider_id = "Core"
		row.trigger_id = "OnProcess"
		row.actions.append(_action(shipped, str(entry[0]), {"other": "$\"../World\"", "target": ""}, ""))
		sheet.events.append(row)
		var output: String = SUPPORT.compile_output(sheet, "user://viewport_layer_index.gd")
		var script: GDScript = GDScript.new()
		script.source_code = output
		var loaded: int = script.reload(true)
		loads.append(loaded)
		var parent: Node = Node.new()
		var world: CanvasLayer = CanvasLayer.new()
		world.name = "World"
		world.layer = 7
		var hud: CanvasLayer = CanvasLayer.new()
		parent.add_child(world)
		parent.add_child(hud)
		if loaded == OK:
			hud.set_script(script)
			hud.call("_process", 0.0)
			answers.append(hud.layer)
		parent.free()
	return SUPPORT.pins("viewport_and_layers_test", [
		["both relative layer scripts load", loads, [OK, OK]],
		["above and below land either side of the layer they name, whatever number it is on",
			answers, [8, 6]]
	])


## The parallax rows, run for real on both nodes: the emitted script is attached and the properties
## are read back off the node, so a row writing a property the engine does not have would fail here
## rather than in somebody's level.
static func _pin_parallax_runs(shipped: Dictionary) -> bool:
	var modern: Parallax2D = Parallax2D.new()
	var modern_output: String = _one_row_script(shipped, "Parallax2D", "ParallaxScrollAt",
		{"factor": "Vector2(0.25, 1)", "target": ""}, "user://viewport_parallax_run.gd")
	var modern_loaded: int = _attach(modern, modern_output)
	var older: ParallaxLayer = ParallaxLayer.new()
	var older_output: String = _one_row_script(shipped, "ParallaxLayer", "ParallaxLayerScrollAt",
		{"factor": "Vector2(0.25, 1)", "target": ""}, "user://viewport_parallax_layer_run.gd")
	var older_loaded: int = _attach(older, older_output)
	var rows: Array = [
		["both parallax scripts load", [modern_loaded, older_loaded], [OK, OK]],
		["the same word writes the fraction on both nodes",
			[modern.scroll_scale, older.motion_scale], [Vector2(0.25, 1), Vector2(0.25, 1)]]
	]
	var passed: bool = SUPPORT.pins("viewport_and_layers_test", rows)
	modern.free()
	older.free()
	return passed


## Smooth Edges With, once per word, as the exact text it emits. A headless run has no rendering
## server to ask, so the three server calls are stripped back to the value each one would be handed
## and that value is evaluated - which is the half of the row that could be wrong.
static func _pin_smooth_edges_words(shipped: Dictionary) -> bool:
	var template: String = _template(shipped, "RenderingSmoothEdgesWith").replace("{uid}", "w")
	var lines: PackedStringArray = template.split("\n")
	# The three arguments are compiled inside a real script rather than handed to an Expression: a
	# rendering constant is a class constant, not a property of the server object, and only GDScript
	# itself resolves those. The local the row declares becomes this function's own argument, which
	# is what lets one compiled body answer for all six words.
	var source: String = "extends RefCounted\n\n\nfunc answers(__edges_w: String) -> Array:\n\treturn [%s]\n" % ", ".join(
		PackedStringArray([_argument_of(lines[1]), _argument_of(lines[2]), _argument_of(lines[3])]))
	var script: GDScript = GDScript.new()
	script.source_code = source
	var loaded: int = script.reload(true)
	var rows: Array = [["the three switches compile as the row writes them", loaded, OK]]
	if loaded != OK:
		return SUPPORT.pins("viewport_and_layers_test", rows)
	var runner: RefCounted = script.new()
	var wanted: Dictionary = {
		"\"none\"": [RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED, false, RenderingServer.VIEWPORT_MSAA_DISABLED],
		"\"fxaa\"": [RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA, false, RenderingServer.VIEWPORT_MSAA_DISABLED],
		"\"taa\"": [RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED, true, RenderingServer.VIEWPORT_MSAA_DISABLED],
		"\"msaa_2x\"": [RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED, false, RenderingServer.VIEWPORT_MSAA_2X],
		"\"msaa_4x\"": [RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED, false, RenderingServer.VIEWPORT_MSAA_4X],
		"\"msaa_8x\"": [RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED, false, RenderingServer.VIEWPORT_MSAA_8X]
	}
	for word: String in wanted:
		rows.append(["smoothing with %s sets exactly the one technique" % word,
			runner.call("answers", word.trim_prefix("\"").trim_suffix("\"")), wanted[word]])
	return SUPPORT.pins("viewport_and_layers_test", rows)


## The quiet note: whole pixels asked for beside a fraction. Pure over a corpus of made-up scripts,
## so what is pinned is the exact sentence a reader meets and the exact cases that stay silent.
static func _pin_the_quiet_note() -> bool:
	var sharp: String = "extends Node\n\n\nfunc _ready() -> void:\n\tget_window().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER\n\tget_window().content_scale_factor = 2.5\n"
	var whole: String = sharp.replace("2.5", "2.0")
	var loose: String = sharp.replace("Window.CONTENT_SCALE_STRETCH_INTEGER", "Window.CONTENT_SCALE_STRETCH_FRACTIONAL")
	var computed: String = sharp.replace("2.5", "chosen_scale")
	var found: Array[Dictionary] = EventSheetShipItDoctor.pixel_scale_findings({"res://ui.gd": sharp})
	var rows: Array = [
		["a fraction under whole pixels is one note", found.size(), 1],
		["it is a note rather than a warning", str(found[0].get("severity", "")) if found.size() > 0 else "", "info"],
		["it says which number was asked for",
			str(found[0].get("message", "")) if found.size() > 0 else "",
			"ui.gd keeps pixels sharp and then asks for a pixel size of 2.5. Whole pixels only means the window rounds that down, so the size a player gets is not the one the row asks for - use a whole number, or let the fraction through."],
		["a whole number says nothing",
			EventSheetShipItDoctor.pixel_scale_findings({"res://ui.gd": whole}).size(), 0],
		["a fraction that was never asked to be sharp says nothing",
			EventSheetShipItDoctor.pixel_scale_findings({"res://ui.gd": loose}).size(), 0],
		["a size worked out at run time is nobody's business to guess at",
			EventSheetShipItDoctor.pixel_scale_findings({"res://ui.gd": computed}).size(), 0],
		["the fraction is reported as the reader wrote it",
			EventSheetShipItDoctor.fractional_pixel_size(sharp), "2.5"]
	]
	return SUPPORT.pins("viewport_and_layers_test", rows)


## The single argument of a one-call line: everything after the viewport RID and before the call's
## own closing bracket. Exactly ONE bracket is dropped, never a run of them, because the argument
## on the last line ends in brackets of its own.
static func _argument_of(line: String) -> String:
	var opened: String = "%s, " % VIEWPORT_RID
	var at: int = line.find(opened)
	if at < 0 or not line.ends_with(")"):
		return line
	var from: int = at + opened.length()
	return line.substr(from, line.length() - from - 1)


## Every action id one compiled script reads back as, in order - "(verbatim)" for a line nothing
## claimed. What a lift pin is about when the answer is a whole list rather than a membership test.
static func _lifted_ids(source: String) -> PackedStringArray:
	var lifted: PackedStringArray = PackedStringArray()
	for item: Variant in SUPPORT.reopen(source).events:
		if not (item is EventRow):
			continue
		for entry: Variant in (item as EventRow).actions:
			lifted.append(str((entry as ACEAction).ace_id) if entry is ACEAction else "(verbatim)")
	return lifted


## One row, compiled into a whole sheet on one host - the shortest real script a property row has.
static func _one_row_script(shipped: Dictionary, host: String, ace_id: String, params: Dictionary,
		output_path: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = host
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.actions.append(_action(shipped, ace_id, params, ""))
	sheet.events.append(row)
	return SUPPORT.compile_output(sheet, output_path)


## Attaches a compiled script to a node and runs one frame of it, returning how the load went.
static func _attach(node: Node, source: String) -> int:
	var script: GDScript = GDScript.new()
	script.source_code = source
	var loaded: int = script.reload(true)
	if loaded == OK:
		node.set_script(script)
		node.call("_process", 0.0)
	return loaded


static func _template(shipped: Dictionary, ace_id: String) -> String:
	return str((shipped[ace_id] as ACEDescriptor).codegen_template) if shipped.has(ace_id) else ""


static func _param_ids(descriptor: ACEDescriptor) -> String:
	var ids: PackedStringArray = PackedStringArray()
	for parameter: ACEParam in descriptor.params:
		ids.append(str(parameter.id))
	return ",".join(ids)


## The values one dropdown offers, in order - the inserted keys, not the shown labels, because the
## key is what the emitted line carries.
static func _choice_keys(descriptor: ACEDescriptor, param_id: String) -> String:
	var keys: PackedStringArray = PackedStringArray()
	for parameter: ACEParam in descriptor.params:
		if str(parameter.id) != param_id:
			continue
		for option: Variant in parameter.options:
			keys.append(str((option as Dictionary).get("key", option)) if option is Dictionary else str(option))
	return ",".join(keys)


static func _default_of(descriptor: ACEDescriptor, param_id: String) -> String:
	for parameter: ACEParam in descriptor.params:
		if str(parameter.id) == param_id:
			return str(parameter.default_value)
	return ""


static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload(true) == OK


## An ACEAction on the SHIPPED template, baking {uid} into a per-row token exactly as the dock does
## at apply time. An empty uid leaves the registry template in charge (there is no {uid} to bake).
## A Save A Still row carrying nothing but its id - the shape a LIFTED builtin action has, with no
## baked template for the word "await" to be found in. It is the only shape the three id lists
## actually decide anything for, so it is the shape the canvas pin is asked about.
static func _still_row() -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "ViewSaveStill"
	return action


static func _action(shipped: Dictionary, ace_id: String, params: Dictionary, uid: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	if not uid.is_empty():
		action.codegen_template = _template(shipped, ace_id).replace("{uid}", uid)
	return action
