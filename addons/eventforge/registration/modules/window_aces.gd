# EventForge module - Game Window vocabulary (control the OS window from events).
#
# The window controls a game reaches for: fullscreen / windowed / borderless, size and position,
# center, vsync, the frame-rate cap, always-on-top, minimize / maximize. They compile to the exact
# plain Godot you would hand-write (get_window().mode = ..., DisplayServer, Engine.max_fps) with zero
# plugin references, honouring the parity covenant. (Set Window Title, Window Size, and Screen Size
# already live in the core vocabulary, so they are not repeated here.) Grouped under "Game Window".
@tool
class_name EventForgeWindowACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Game Window"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.act("WindowGoFullscreen", "Go Fullscreen", "get_window().mode = Window.MODE_FULLSCREEN", CAT, "Set fullscreen on", "Switches the game to borderless fullscreen."))
	descriptors.append(F.act("WindowGoWindowed", "Go Windowed", "get_window().mode = Window.MODE_WINDOWED", CAT, "Set fullscreen off", "Switches the game back to a normal window."))
	descriptors.append(F.act("WindowGoExclusive", "Go Exclusive Fullscreen", "get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN", CAT, "Set fullscreen on (exclusive)", "Switches to exclusive fullscreen (the mode that takes over the whole display)."))
	descriptors.append(F.act("WindowToggleFullscreen", "Toggle Fullscreen", "get_window().mode = Window.MODE_WINDOWED if get_window().mode != Window.MODE_WINDOWED else Window.MODE_FULLSCREEN", CAT, "Toggle fullscreen", "Flips between fullscreen and windowed - handy on an Alt+Enter shortcut.").featured())
	descriptors.append(F.act("WindowSetSize", "Set Window Size", "get_window().size = Vector2i({width}, {height})", CAT, "Set size to {width} × {height}", "Resizes the game window to an exact pixel size.").param_typed("int", "width", "1280", "Width", "Window width in pixels.", "expression").param_typed("int", "height", "720", "Height", "Window height in pixels.", "expression"))
	descriptors.append(F.act("WindowSetPosition", "Set Window Position", "get_window().position = Vector2i({x}, {y})", CAT, "Set position to {x}, {y}", "Moves the game window to a position on the screen.").param_typed("int", "x", "0", "X", "Left edge in screen pixels.", "expression").param_typed("int", "y", "0", "Y", "Top edge in screen pixels.", "expression"))
	descriptors.append(F.act("WindowCenter", "Center Window", "get_window().move_to_center()", CAT, "Center on screen", "Centers the game window on the screen."))
	descriptors.append(F.act("WindowSetVSync", "Set VSync Enabled", "DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if {enabled} else DisplayServer.VSYNC_DISABLED)", CAT, "Set vsync to {enabled}", "Turns vertical sync on or off - a common options-menu toggle.").param_typed("bool", "enabled", "true", "Enabled", "On removes screen tearing; off can raise the frame rate.", "expression"))
	descriptors.append(F.act("WindowSetMaxFps", "Set Max FPS", "Engine.max_fps = {fps}", CAT, "Set max FPS to {fps}", "Caps the frame rate (0 means uncapped).").param_typed("int", "fps", "60", "Max FPS", "Frame-rate cap (0 = uncapped).", "expression"))
	descriptors.append(F.act("WindowSetAlwaysOnTop", "Set Always On Top", "get_window().always_on_top = {enabled}", CAT, "Set always on top to {enabled}", "Keeps the game window above every other window.").param_typed("bool", "enabled", "true", "Enabled", "Keep the window above other windows.", "expression"))
	descriptors.append(F.act("WindowMinimize", "Minimize Window", "get_window().mode = Window.MODE_MINIMIZED", CAT, "Minimize", "Minimizes the game window to the taskbar."))
	descriptors.append(F.act("WindowMaximize", "Maximize Window", "get_window().mode = Window.MODE_MAXIMIZED", CAT, "Maximize", "Maximizes the game window."))

	# ── The render and screenshot half of the same family ──────
	# Each of these writes EXACTLY the plain Godot line the sheet reads back as its own words, so a
	# picked row and a hand-written one are the same bytes and the same sentence.
	descriptors.append(F.act("WindowSetAntiAliasing", "Set Anti-aliasing", "get_viewport().msaa_2d = {level}", CAT, "Set anti-aliasing to [b]{level}[/b]", "Smooths jagged edges in what this viewport draws. Higher costs more to render, so an options screen usually offers it as a choice.").param_choice("level", "Viewport.MSAA_DISABLED", "Level", "How many samples smooth the edges. Off is fastest; 4x is the usual choice.", [{"key": "Viewport.MSAA_DISABLED", "label": "off"}, {"key": "Viewport.MSAA_2X", "label": "2×"}, {"key": "Viewport.MSAA_4X", "label": "4×"}, {"key": "Viewport.MSAA_8X", "label": "8×"}]))
	descriptors.append(F.act("WindowSaveImageAs", "Save Image As", "{image}.save_png({path})", CAT, "Save image [b]{image}[/b] as [b]{path}[/b]", "Writes a picture to a PNG file. Pair it with Screenshot to save what the player is looking at.").param("image", "get_viewport().get_texture().get_image()", "Image", "The picture to write - a Screenshot expression, or a variable holding one.", "expression").param("path", "\"user://shot.png\"", "File", "Where to write the PNG (user:// is the writable folder).", "expression"))
	descriptors.append(F.expr("WindowScreenshot", "Screenshot", "get_viewport().get_texture().get_image()", CAT, "a screenshot", "A picture of what is on screen right now. Put it in a variable, then Save Image As.").featured())
	descriptors.append(F.expr("WindowViewportImage", "Rendered As An Image", "{viewport}.get_texture()", CAT, "[b]{viewport}[/b] rendered as an image", "What a viewport is currently drawing, as a picture you can show on a sprite or save.").param("viewport", "get_viewport()", "Viewport", "The viewport to photograph - $SubViewport for an off-screen one.", "expression"))

	descriptors.append(F.cond("WindowIsFullscreen", "Is Fullscreen", "(get_window().mode == Window.MODE_FULLSCREEN or get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)", CAT, "Is fullscreen", "True while the game is in either fullscreen mode."))

	descriptors.append(F.expr("WindowMaxFps", "Max FPS", "Engine.max_fps", CAT, "max FPS", "The current frame-rate cap (0 means uncapped)."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Control the game window - fullscreen or windowed, size and position, vsync, and the frame-rate cap."}
