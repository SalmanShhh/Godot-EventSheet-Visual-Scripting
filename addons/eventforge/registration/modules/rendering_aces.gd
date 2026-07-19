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
	descriptors.append(F.make_descriptor("Core", "RenderingSetClearColor", "Set Clear Color", ACEDescriptor.ACEType.ACTION, "RenderingServer.set_default_clear_color({color})", "", [F.make_param("color", "Color", "Color.BLACK", "Color", "The background color rendered where nothing else draws.", "")], CAT, "set clear color {color}")
		.described("Sets the default background color of the whole game - the color you see where nothing is drawn."))
	descriptors.append(F.make_descriptor("Core", "RenderingSetGlobalShaderParam", "Set Global Shader Parameter", ACEDescriptor.ACEType.ACTION, "RenderingServer.global_shader_parameter_set({name}, {value})", "", [F.make_param("name", "String", "\"wind_strength\"", "Parameter", "A global uniform declared in Project Settings > Shader Globals.", "expression"), F.make_param("value", "String", "1.0", "Value", "The value to feed every shader reading this global.", "expression")], CAT, "set global shader parameter {name} to {value}")
		.described("Drives a global shader uniform (Project Settings > Shader Globals) - every material reading it updates at once, the code-free way to animate weather, day-night tint, or a world-wide effect.").featured())
	descriptors.append(F.make_descriptor("Core", "RenderingSetMsaa2D", "Set MSAA (2D)", ACEDescriptor.ACEType.ACTION, "RenderingServer.viewport_set_msaa_2d(%s, {level})" % VP, "", [F.make_param("level", "String", "RenderingServer.VIEWPORT_MSAA_DISABLED", "Level", "Antialiasing samples for 2D rendering.", "", ["RenderingServer.VIEWPORT_MSAA_DISABLED", "RenderingServer.VIEWPORT_MSAA_2X", "RenderingServer.VIEWPORT_MSAA_4X", "RenderingServer.VIEWPORT_MSAA_8X"])], CAT, "set 2D MSAA to {level}")
		.described("Sets multisample antialiasing for 2D rendering on the current viewport - a standard graphics-options switch."))
	descriptors.append(F.make_descriptor("Core", "RenderingSetMsaa3D", "Set MSAA (3D)", ACEDescriptor.ACEType.ACTION, "RenderingServer.viewport_set_msaa_3d(%s, {level})" % VP, "", [F.make_param("level", "String", "RenderingServer.VIEWPORT_MSAA_4X", "Level", "Antialiasing samples for 3D rendering.", "", ["RenderingServer.VIEWPORT_MSAA_DISABLED", "RenderingServer.VIEWPORT_MSAA_2X", "RenderingServer.VIEWPORT_MSAA_4X", "RenderingServer.VIEWPORT_MSAA_8X"])], CAT, "set 3D MSAA to {level}")
		.described("Sets multisample antialiasing for 3D rendering on the current viewport - a standard graphics-options switch."))
	descriptors.append(F.make_descriptor("Core", "RenderingSetScreenSpaceAA", "Set Screen-Space AA", ACEDescriptor.ACEType.ACTION, "RenderingServer.viewport_set_screen_space_aa(%s, {mode})" % VP, "", [F.make_param("mode", "String", "RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA", "Mode", "Screen-space antialiasing mode.", "", ["RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED", "RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA"])], CAT, "set screen-space AA to {mode}")
		.described("Turns FXAA on or off for the current viewport - cheaper than MSAA, softer result."))
	descriptors.append(F.make_descriptor("Core", "RenderingSetScaling3DScale", "Set 3D Resolution Scale", ACEDescriptor.ACEType.ACTION, "RenderingServer.viewport_set_scaling_3d_scale(%s, {scale})" % VP, "", [F.make_param("scale", "float", "1.0", "Scale", "0.5 = render 3D at half resolution (faster), 1.0 = full.", "expression")], CAT, "set 3D resolution scale to {scale}")
		.described("Renders the 3D scene at a fraction of the window resolution and upscales - the classic performance slider.").featured())
	descriptors.append(F.make_descriptor("Core", "RenderingSetDebugDraw", "Set Debug Draw Mode", ACEDescriptor.ACEType.ACTION, "RenderingServer.viewport_set_debug_draw(%s, {mode})" % VP, "", [F.make_param("mode", "String", "RenderingServer.VIEWPORT_DEBUG_DRAW_WIREFRAME", "Mode", "How the viewport visualizes the scene.", "", ["RenderingServer.VIEWPORT_DEBUG_DRAW_DISABLED", "RenderingServer.VIEWPORT_DEBUG_DRAW_WIREFRAME", "RenderingServer.VIEWPORT_DEBUG_DRAW_OVERDRAW", "RenderingServer.VIEWPORT_DEBUG_DRAW_UNSHADED"])], CAT, "set debug draw to {mode}")
		.described("Switches the viewport to a diagnostic view - wireframe, overdraw heat, or unshaded - and back. Great on a debug hotkey."))
	descriptors.append(F.make_descriptor("Core", "RenderingSetOcclusionCulling", "Set Occlusion Culling", ACEDescriptor.ACEType.ACTION, "RenderingServer.viewport_set_use_occlusion_culling(%s, {enabled})" % VP, "", [F.make_param("enabled", "bool", "true", "Enabled", "Skip rendering objects hidden behind occluders (needs occlusion culling enabled in Project Settings and baked occluders).", "expression")], CAT, "set occlusion culling {enabled}")
		.described("Toggles occlusion culling on the current viewport - big scenes skip drawing what walls already hide."))
	descriptors.append(F.make_descriptor("Core", "RenderingSetDebanding", "Set Debanding", ACEDescriptor.ACEType.ACTION, "RenderingServer.viewport_set_use_debanding(%s, {enabled})" % VP, "", [F.make_param("enabled", "bool", "true", "Enabled", "Dither away gradient banding in dark scenes.", "expression")], CAT, "set debanding {enabled}")
		.described("Toggles debanding - removes the visible stripes in smooth dark gradients for a tiny cost."))

	# ── Conditions ──
	descriptors.append(F.make_descriptor("Core", "RenderingUsesModernRenderer", "Uses Modern Renderer", ACEDescriptor.ACEType.CONDITION, "RenderingServer.get_rendering_device() != null", "", [], CAT, "uses the modern renderer")
		.described("True on the Forward+ / Mobile renderers, false on Compatibility (old GPUs, web) - gate fancy effects on it."))

	# ── Expressions (the perf-HUD numbers) ──
	descriptors.append(F.make_descriptor("Core", "RenderingDrawCallsInFrame", "Draw Calls (frame)", ACEDescriptor.ACEType.EXPRESSION, "RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)", "", [], CAT, "draw calls this frame")
		.described("How many draw calls the last frame issued - the first number to watch when rendering gets slow."))
	descriptors.append(F.make_descriptor("Core", "RenderingObjectsInFrame", "Objects Drawn (frame)", ACEDescriptor.ACEType.EXPRESSION, "RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)", "", [], CAT, "objects drawn this frame")
		.described("How many objects the last frame rendered after culling."))
	descriptors.append(F.make_descriptor("Core", "RenderingPrimitivesInFrame", "Primitives Drawn (frame)", ACEDescriptor.ACEType.EXPRESSION, "RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)", "", [], CAT, "primitives drawn this frame")
		.described("How many triangles/points/lines the last frame rendered."))
	descriptors.append(F.make_descriptor("Core", "RenderingVideoMemoryUsed", "Video Memory Used", ACEDescriptor.ACEType.EXPRESSION, "RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)", "", [], CAT, "video memory used")
		.described("Video memory in use, in bytes (textures + buffers)."))
	descriptors.append(F.make_descriptor("Core", "RenderingGetGlobalShaderParam", "Global Shader Parameter", ACEDescriptor.ACEType.EXPRESSION, "RenderingServer.global_shader_parameter_get({name})", "", [F.make_param("name", "String", "\"wind_strength\"", "Parameter", "A global uniform declared in Project Settings > Shader Globals.", "expression")], CAT, "global shader parameter {name}")
		.described("Reads a global shader uniform's current value."))
	descriptors.append(F.make_descriptor("Core", "RenderingGetClearColor", "Clear Color", ACEDescriptor.ACEType.EXPRESSION, "RenderingServer.get_default_clear_color()", "", [], CAT, "clear color")
		.described("The current default background color."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Control the renderer - clear color, global shader parameters, antialiasing and resolution scale, debug draw modes, and the frame statistics a performance HUD reads."}
