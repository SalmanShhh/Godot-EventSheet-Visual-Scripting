# EventForge module - Rendering vocabulary (the RenderingServer from events).
#
# The rendering controls a game's options menu and debug tooling reach for: the clear color,
# global shader parameters (the code-free way to drive weather / damage-flash / day-night
# uniforms across every material at once), MSAA and FXAA quality switches, 3D resolution
# scale, debug draw modes (wireframe / overdraw / unshaded), occlusion culling and debanding
# toggles, plus the frame statistics (draw calls, objects, primitives, video memory) a perf
# HUD needs. Everything compiles to plain RenderingServer calls with zero plugin references,
# honouring the parity covenant. Viewport-scoped calls target the CURRENT viewport's RID, the
# case game events want. (GPU adapter name/vendor live in the Platform Info pack already.)
@tool
class_name EventForgeRenderingACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Rendering"

## Every viewport-scoped call targets the current viewport - one shared prefix keeps the
## emitted calls identical everywhere.
const VP := "get_viewport().get_viewport_rid()"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Actions ──
	descriptors.append(F.act("RenderingSetClearColor", "Set Clear Color", "RenderingServer.set_default_clear_color({color})", CAT, "set clear color {color}", "Sets the default background color of the whole game - the color you see where nothing is drawn.").param_typed("Color", "color", "Color.BLACK", "Color", "The background color rendered where nothing else draws."))
	descriptors.append(F.act("RenderingSetGlobalShaderParam", "Set Global Shader Parameter", "RenderingServer.global_shader_parameter_set({name}, {value})", CAT, "set global shader parameter {name} to {value}", "Drives a global shader uniform (Project Settings > Shader Globals) - every material reading it updates at once, the code-free way to animate weather, day-night tint, or a world-wide effect.").param("name", "\"wind_strength\"", "Parameter", "A global uniform declared in Project Settings > Shader Globals.", "expression").param("value", "1.0", "Value", "The value to feed every shader reading this global.", "expression").featured())
	descriptors.append(F.act("RenderingSetMsaa2D", "Set MSAA (2D)", "RenderingServer.viewport_set_msaa_2d(%s, {level})" % VP, CAT, "set 2D MSAA to {level}", "Sets multisample antialiasing for 2D rendering on the current viewport - a standard graphics-options switch.").param_choice("level", "RenderingServer.VIEWPORT_MSAA_DISABLED", "Level", "Antialiasing samples for 2D rendering.", ["RenderingServer.VIEWPORT_MSAA_DISABLED", "RenderingServer.VIEWPORT_MSAA_2X", "RenderingServer.VIEWPORT_MSAA_4X", "RenderingServer.VIEWPORT_MSAA_8X"]))
	descriptors.append(F.act("RenderingSetMsaa3D", "Set MSAA (3D)", "RenderingServer.viewport_set_msaa_3d(%s, {level})" % VP, CAT, "set 3D MSAA to {level}", "Sets multisample antialiasing for 3D rendering on the current viewport - a standard graphics-options switch.").param_choice("level", "RenderingServer.VIEWPORT_MSAA_4X", "Level", "Antialiasing samples for 3D rendering.", ["RenderingServer.VIEWPORT_MSAA_DISABLED", "RenderingServer.VIEWPORT_MSAA_2X", "RenderingServer.VIEWPORT_MSAA_4X", "RenderingServer.VIEWPORT_MSAA_8X"]))
	descriptors.append(F.act("RenderingSetScreenSpaceAA", "Set Screen-Space AA", "RenderingServer.viewport_set_screen_space_aa(%s, {mode})" % VP, CAT, "set screen-space AA to {mode}", "Turns FXAA on or off for the current viewport - cheaper than MSAA, softer result.").param_choice("mode", "RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA", "Mode", "Screen-space antialiasing mode.", ["RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED", "RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA"]))
	descriptors.append(F.act("RenderingUpscaleWith", "Upscale With", "RenderingServer.viewport_set_scaling_3d_mode(%s, {method})" % VP, CAT, "upscale 3D with {method}", "How a 3D scene rendered smaller than the window is stretched back up. Plain is the cheapest and the softest; the sharpening upscalers cost a little more and give most of the detail back, which is why a resolution slider is worth having at all.").param_choice("method", "RenderingServer.VIEWPORT_SCALING_3D_MODE_BILINEAR", "Upscale with", "How the smaller picture is stretched back up.", [{"key": "RenderingServer.VIEWPORT_SCALING_3D_MODE_BILINEAR", "label": "Bilinear - plain and cheapest"}, {"key": "RenderingServer.VIEWPORT_SCALING_3D_MODE_FSR", "label": "FSR - sharper, still cheap"}, {"key": "RenderingServer.VIEWPORT_SCALING_3D_MODE_FSR2", "label": "FSR 2 - sharpest, costs the most"}]))
	descriptors.append(F.act("RenderingSetTaa", "Set Temporal AA", "RenderingServer.viewport_set_use_taa(%s, {enabled})" % VP, CAT, "set temporal AA {enabled}", "Turns temporal antialiasing on or off for the current viewport - it borrows detail from the frames before this one, which is sharper than FXAA on a still image and can shimmer while the camera moves.").param_typed("bool", "enabled", "true", "Enabled", "Smooth edges by reusing what the last frames drew.", "expression"))
	descriptors.append(F.act("RenderingSetScaling3DScale", "Set 3D Resolution Scale", "RenderingServer.viewport_set_scaling_3d_scale(%s, {scale})" % VP, CAT, "set 3D resolution scale to {scale}", "Renders the 3D scene at a fraction of the window resolution and upscales - the classic performance slider.").param_typed("float", "scale", "1.0", "Scale", "0.5 = render 3D at half resolution (faster), 1.0 = full.", "expression").featured())
	descriptors.append(F.act("RenderingSetDebugDraw", "Set Debug Draw Mode", "RenderingServer.viewport_set_debug_draw(%s, {mode})" % VP, CAT, "set debug draw to {mode}", "Switches the viewport to a diagnostic view - wireframe, overdraw heat, or unshaded - and back. Great on a debug hotkey.").param_choice("mode", "RenderingServer.VIEWPORT_DEBUG_DRAW_WIREFRAME", "Mode", "How the viewport visualizes the scene.", ["RenderingServer.VIEWPORT_DEBUG_DRAW_DISABLED", "RenderingServer.VIEWPORT_DEBUG_DRAW_WIREFRAME", "RenderingServer.VIEWPORT_DEBUG_DRAW_OVERDRAW", "RenderingServer.VIEWPORT_DEBUG_DRAW_UNSHADED"]))
	descriptors.append(F.act("RenderingSetOcclusionCulling", "Set Occlusion Culling", "RenderingServer.viewport_set_use_occlusion_culling(%s, {enabled})" % VP, CAT, "set occlusion culling {enabled}", "Toggles occlusion culling on the current viewport - big scenes skip drawing what walls already hide.").param_typed("bool", "enabled", "true", "Enabled", "Skip rendering objects hidden behind occluders (needs occlusion culling enabled in Project Settings and baked occluders).", "expression"))
	descriptors.append(F.act("RenderingSetDebanding", "Set Debanding", "RenderingServer.viewport_set_use_debanding(%s, {enabled})" % VP, CAT, "set debanding {enabled}", "Toggles debanding - removes the visible stripes in smooth dark gradients for a tiny cost.").param_typed("bool", "enabled", "true", "Enabled", "Dither away gradient banding in dark scenes.", "expression"))

	# ── Scaling and edges, as one word each ──
	#
	# Godot spreads three of these questions over several switches: antialiasing is a screen-space
	# mode, a temporal flag and a sample count; how the game fills the window is a scale mode and an
	# aspect. A player asks ONE question ("what smooths the edges?", "how does this fit my screen?"),
	# so each row here is that one question and writes every switch the answer touches. The frozen
	# per-technique rows above stay exactly as they are - they are still the right rows for a graphics
	# menu that offers the switches separately.
	#
	# Smooth Edges With keeps the chosen word in a local of its own rather than repeating it four
	# times, because that is what makes the emitted lines readable: one decision, named once, applied
	# to each switch in turn. The local is uid-suffixed so two of these rows in one function cannot
	# collide.
	descriptors.append(F.act("RenderingRender3DAt", "Render 3D At", "RenderingServer.viewport_set_scaling_3d_scale(%s, {percent} / 100.0)\nRenderingServer.viewport_set_scaling_3d_mode(%s, {method})" % [VP, VP], CAT, "render 3D at {percent}% with {method}", "Renders the 3D scene at a percentage of the window and upscales it back, choosing HOW it is upscaled. The performance slider a 3D game ships with: 70% with a sharpening upscaler often looks better than 70% plain and costs the same. 2D drawing and the interface are untouched - they stay at full resolution.").param_typed("float", "percent", "100.0", "Percent", "How much of the window the 3D scene is rendered at. 100 is full resolution; 70 renders about half the pixels.", "expression").param_choice("method", "RenderingServer.VIEWPORT_SCALING_3D_MODE_BILINEAR", "Upscale with", "How the smaller picture is stretched back up.", [{"key": "RenderingServer.VIEWPORT_SCALING_3D_MODE_BILINEAR", "label": "Bilinear - plain and cheapest"}, {"key": "RenderingServer.VIEWPORT_SCALING_3D_MODE_FSR", "label": "FSR - sharper, still cheap"}, {"key": "RenderingServer.VIEWPORT_SCALING_3D_MODE_FSR2", "label": "FSR 2 - sharpest, costs the most"}]).featured())

	descriptors.append(F.act("RenderingSmoothEdgesWith", "Smooth Edges With", "var __edges_{uid}: String = {how}\nRenderingServer.viewport_set_screen_space_aa(%s, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA if __edges_{uid} == \"fxaa\" else RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED)\nRenderingServer.viewport_set_use_taa(%s, __edges_{uid} == \"taa\")\nRenderingServer.viewport_set_msaa_3d(%s, RenderingServer.VIEWPORT_MSAA_8X if __edges_{uid} == \"msaa_8x\" else (RenderingServer.VIEWPORT_MSAA_4X if __edges_{uid} == \"msaa_4x\" else (RenderingServer.VIEWPORT_MSAA_2X if __edges_{uid} == \"msaa_2x\" else RenderingServer.VIEWPORT_MSAA_DISABLED)))" % [VP, VP, VP], CAT, "smooth edges with {how}", "The one antialiasing switch a graphics menu needs: pick a technique and every other one is turned off, so a player cannot end up paying for two at once. FXAA is cheap and slightly soft, temporal is sharper and can shimmer while the camera moves, and the sample counts are the expensive, cleanest option on a 3D scene.").param_choice("how", "\"fxaa\"", "Smooth with", "The one technique in force. Everything else is switched off.", [{"key": "\"none\"", "label": "Nothing - hard edges, cheapest"}, {"key": "\"fxaa\"", "label": "FXAA - cheap, a little soft"}, {"key": "\"taa\"", "label": "Temporal - sharp, can shimmer"}, {"key": "\"msaa_2x\"", "label": "2 samples"}, {"key": "\"msaa_4x\"", "label": "4 samples"}, {"key": "\"msaa_8x\"", "label": "8 samples - cleanest, dearest"}]).featured())

	descriptors.append(F.act("RenderingScaleTheGame", "Scale The Game", "get_window().content_scale_mode = Window.{mode}", CAT, "scale the game to {mode}", "What happens to a game drawn for one size when the window is another. Fitting the layout keeps text and interface crisp and stretches the placement; stretching the picture blows the whole rendered frame up, which is what a pixel-art game wants; free leaves everything where it was drawn and simply shows more or less of the world.").param_choice("mode", "CONTENT_SCALE_MODE_CANVAS_ITEMS", "Scale", "What gets stretched when the window is not the size the game was drawn for.", [{"key": "CONTENT_SCALE_MODE_CANVAS_ITEMS", "label": "Fit - scale the layout, keep text crisp"}, {"key": "CONTENT_SCALE_MODE_VIEWPORT", "label": "Stretch - scale the whole picture"}, {"key": "CONTENT_SCALE_MODE_DISABLED", "label": "Free - no scaling, show more or less"}]).featured())

	descriptors.append(F.act("RenderingFitTheShape", "Fit The Shape", "get_window().content_scale_aspect = Window.{aspect}", CAT, "fit a different shape by {aspect}", "What happens when the window is a different SHAPE from the game - a widescreen monitor for a game drawn square, a phone held the other way up. Keeping the shape puts bars at the edges and never distorts anything; filling the window stretches the picture out of shape; the three showing-more answers give the extra space to the world instead.").param_choice("aspect", "CONTENT_SCALE_ASPECT_KEEP", "When the shape differs", "What the extra space becomes when the window is a different shape from the game.", [{"key": "CONTENT_SCALE_ASPECT_KEEP", "label": "Keep the shape, bars at the edges"}, {"key": "CONTENT_SCALE_ASPECT_IGNORE", "label": "Fill the window, shape and all"}, {"key": "CONTENT_SCALE_ASPECT_KEEP_WIDTH", "label": "Keep the width, show more height"}, {"key": "CONTENT_SCALE_ASPECT_KEEP_HEIGHT", "label": "Keep the height, show more width"}, {"key": "CONTENT_SCALE_ASPECT_EXPAND", "label": "Expand - show more either way"}]))

	descriptors.append(F.act("RenderingKeepPixelsSharp", "Keep Pixels Sharp", "get_window().content_scale_stretch = Window.{stretch}", CAT, "keep pixels sharp: {stretch}", "Whether the game may only be scaled by a whole number. A pixel-art game scaled by 2.5 draws some source pixels twice and some three times, which is the shimmering, uneven look nobody can name and everybody sees; whole numbers only means bars at the edges instead. Anything that is not pixel art wants the fraction.").param_choice("stretch", "CONTENT_SCALE_STRETCH_FRACTIONAL", "Whole pixels", "Whether the scale is rounded down to a whole number.", [{"key": "CONTENT_SCALE_STRETCH_INTEGER", "label": "Yes - whole numbers only"}, {"key": "CONTENT_SCALE_STRETCH_FRACTIONAL", "label": "No - any fraction"}]))

	descriptors.append(F.act("RenderingPixelSize", "Pixel Size", "get_window().content_scale_factor = {factor}", CAT, "set pixel size to {factor}", "How big one drawn pixel is on the screen, on top of everything else. 2 draws the game twice the size, which is the accessibility answer for a small interface and the zoom answer for a pixel-art game on a big monitor. Whole numbers only when pixels are being kept sharp.").param_typed("float", "factor", "1.0", "Factor", "1 is the size the game was drawn at. 2 is twice as big.", "expression"))

	# ── Draw order, in the words a 2D scene uses ──
	#
	# Three mechanisms, all numbers, none of them readable in a row: z_index says who covers whom,
	# visibility_layer says which camera sees a thing at all, and "is it on screen" is a node rather
	# than a property. The three rows below are the daily case of each; the plain numeric rows above
	# and the Inspector stay for everything else.
	#
	# Both actions carry their OWN `{target.}` slot rather than taking the automatic "On node" one:
	# the retarget pass refuses to prefix a line whose right-hand side reads the assigned member back
	# (`z_index = {other}.z_index + 1` does), and refusing is right in general - it is only safe here
	# because the member being read belongs to the OTHER node, which the row names separately.
	descriptors.append(F.act("RenderingDrawInFrontOf", "Draw In Front Of", "{target.}z_index = {other}.z_index + 1", CAT, "draw in front of {other}", "Puts this node one step in front of another in the drawing order, whatever that other node's order happens to be. Relative on purpose: move the pair around and they keep their order, where two hand-set numbers drift apart.", "CanvasItem").param("other", "self", "In front of", "The node to draw over - this one takes its drawing order plus one.", "scene_node").param_built(_on_node_param()).featured())
	descriptors.append(F.act("RenderingShowOnlyTo", "Show Only To", "{target.}visibility_layer = {layers}", CAT, "show only to {layers}", "Limits which cameras draw this node: a camera only draws what its cull mask and the node's visibility layer share. The layer names are the project's own (Project Settings > Layer Names > 2D Render), which is how a minimap marker gets seen by the minimap and by nothing else.", "CanvasItem").param("layers", "1", "Visible to", "The visibility layers that may see this node, by their project names.", "render_layer_2d").param_built(_on_node_param()))
	descriptors.append(F.cond("RenderingIsOnScreen", "Is On Screen", "__on_screen_{uid}({node})", CAT, "is on screen", "True while the node is inside what a camera is showing. It works through the engine's own VisibleOnScreenNotifier2D, and adds one to the node the first time the row is asked if the node has none - a plain child you can see in the scene, move, resize and keep.").param("node", "self", "Node", "The node to ask about.", "scene_node").stateful("var __on_screen_watch_{uid}: VisibleOnScreenNotifier2D = null\n\nfunc __on_screen_{uid}(who: Node) -> bool:\n\tif not is_instance_valid(__on_screen_watch_{uid}):\n\t\t__on_screen_watch_{uid} = who.get_node_or_null(^\"VisibleOnScreenNotifier2D\") as VisibleOnScreenNotifier2D\n\tif __on_screen_watch_{uid} == null:\n\t\t__on_screen_watch_{uid} = VisibleOnScreenNotifier2D.new()\n\t\t__on_screen_watch_{uid}.name = \"VisibleOnScreenNotifier2D\"\n\t\twho.add_child(__on_screen_watch_{uid})\n\treturn __on_screen_watch_{uid}.is_on_screen()"))

	# ── Conditions ──
	descriptors.append(F.cond("RenderingUsesModernRenderer", "Uses Modern Renderer", "RenderingServer.get_rendering_device() != null", CAT, "uses the modern renderer", "True on the Forward+ / Mobile renderers, false on Compatibility (old GPUs, web) - gate fancy effects on it."))
	# WHICH of the three, beside the question above that can only tell two of them apart. A game
	# offering reflections, indirect light, global illumination or volumetric fog has to know it is on
	# Forward+ and not merely "modern", because Mobile answers yes to the row above and draws none of
	# them. Frozen row untouched; this is a new id beside it.
	descriptors.append(F.cond("RenderingRendererIs", "Renderer Is", "%s == {method}" % EventForgeEnvironmentWords.RENDERING_METHOD_CALL, CAT, "renderer is {method}", "True when the game is running on the renderer named - Godot's own three. Forward+ is the only one that draws screen-space reflections, indirect light, global illumination and volumetric fog, so this is the question a graphics menu asks before it offers them.").param_choice("method", "\"forward_plus\"", "Renderer", "Which renderer to ask about.", EventForgeEnvironmentWords.RENDERING_METHODS))

	# ── Expressions (the perf-HUD numbers) ──
	descriptors.append(F.expr("RenderingDrawCallsInFrame", "Draw Calls (frame)", "RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)", CAT, "draw calls this frame", "How many draw calls the last frame issued - the first number to watch when rendering gets slow."))
	descriptors.append(F.expr("RenderingObjectsInFrame", "Objects Drawn (frame)", "RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)", CAT, "objects drawn this frame", "How many objects the last frame rendered after culling."))
	descriptors.append(F.expr("RenderingPrimitivesInFrame", "Primitives Drawn (frame)", "RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)", CAT, "primitives drawn this frame", "How many triangles/points/lines the last frame rendered."))
	descriptors.append(F.expr("RenderingVideoMemoryUsed", "Video Memory Used", "RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)", CAT, "video memory used", "Video memory in use, in bytes (textures + buffers)."))
	descriptors.append(F.expr("RenderingGetGlobalShaderParam", "Global Shader Parameter", "RenderingServer.global_shader_parameter_get({name})", CAT, "global shader parameter {name}", "Reads a global shader uniform's current value.").param("name", "\"wind_strength\"", "Parameter", "A global uniform declared in Project Settings > Shader Globals.", "expression"))
	descriptors.append(F.expr("RenderingGetClearColor", "Clear Color", "RenderingServer.get_default_clear_color()", CAT, "clear color", "The current default background color."))

	return descriptors


## The "On node" parameter in the shape the automatic retarget pass gives every other node-scoped
## row, for the two rows that have to spell their own `{target.}` slot. Same id, same words, so a
## reader meets one field rather than two that look alike.
static func _on_node_param() -> ACEParam:
	return F.make_param("target", "String", "", "On node", "Act on another node instead of this one. Leave blank for this node, pick a node, or address one without a tree path - e.g. get_tree().get_first_node_in_group(\"player\").", "expression")


static func section_descriptions() -> Dictionary:
	return {CAT: "Control the renderer - clear color, global shader parameters, antialiasing and resolution scale, debug draw modes, and the frame statistics a performance HUD reads."}
