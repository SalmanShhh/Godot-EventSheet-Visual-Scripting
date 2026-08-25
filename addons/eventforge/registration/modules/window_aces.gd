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

	descriptors.append(F.make_descriptor("Core", "WindowGoFullscreen", "Go Fullscreen", ACEDescriptor.ACEType.ACTION, "get_window().mode = Window.MODE_FULLSCREEN", "", [], CAT, "Set fullscreen on")
		.described("Switches the game to borderless fullscreen."))
	descriptors.append(F.make_descriptor("Core", "WindowGoWindowed", "Go Windowed", ACEDescriptor.ACEType.ACTION, "get_window().mode = Window.MODE_WINDOWED", "", [], CAT, "Set fullscreen off")
		.described("Switches the game back to a normal window."))
	descriptors.append(F.make_descriptor("Core", "WindowGoExclusive", "Go Exclusive Fullscreen", ACEDescriptor.ACEType.ACTION, "get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN", "", [], CAT, "Set fullscreen on (exclusive)")
		.described("Switches to exclusive fullscreen (the mode that takes over the whole display)."))
	descriptors.append(F.make_descriptor("Core", "WindowToggleFullscreen", "Toggle Fullscreen", ACEDescriptor.ACEType.ACTION, "get_window().mode = Window.MODE_WINDOWED if get_window().mode != Window.MODE_WINDOWED else Window.MODE_FULLSCREEN", "", [], CAT, "Toggle fullscreen")
		.described("Flips between fullscreen and windowed - handy on an Alt+Enter shortcut.").featured())
	descriptors.append(F.make_descriptor("Core", "WindowSetSize", "Set Window Size", ACEDescriptor.ACEType.ACTION, "get_window().size = Vector2i({width}, {height})", "", [F.make_param("width", "int", "1280", "Width", "Window width in pixels.", "expression"), F.make_param("height", "int", "720", "Height", "Window height in pixels.", "expression")], CAT, "Set size to {width} × {height}")
		.described("Resizes the game window to an exact pixel size."))
	descriptors.append(F.make_descriptor("Core", "WindowSetPosition", "Set Window Position", ACEDescriptor.ACEType.ACTION, "get_window().position = Vector2i({x}, {y})", "", [F.make_param("x", "int", "0", "X", "Left edge in screen pixels.", "expression"), F.make_param("y", "int", "0", "Y", "Top edge in screen pixels.", "expression")], CAT, "Set position to {x}, {y}")
		.described("Moves the game window to a position on the screen."))
	descriptors.append(F.make_descriptor("Core", "WindowCenter", "Center Window", ACEDescriptor.ACEType.ACTION, "get_window().move_to_center()", "", [], CAT, "Center on screen")
		.described("Centers the game window on the screen."))
	descriptors.append(F.make_descriptor("Core", "WindowSetVSync", "Set VSync Enabled", ACEDescriptor.ACEType.ACTION, "DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if {enabled} else DisplayServer.VSYNC_DISABLED)", "", [F.make_param("enabled", "bool", "true", "Enabled", "On removes screen tearing; off can raise the frame rate.", "expression")], CAT, "Set vsync to {enabled}")
		.described("Turns vertical sync on or off - a common options-menu toggle."))
	descriptors.append(F.make_descriptor("Core", "WindowSetMaxFps", "Set Max FPS", ACEDescriptor.ACEType.ACTION, "Engine.max_fps = {fps}", "", [F.make_param("fps", "int", "60", "Max FPS", "Frame-rate cap (0 = uncapped).", "expression")], CAT, "Set max FPS to {fps}")
		.described("Caps the frame rate (0 means uncapped)."))
	descriptors.append(F.make_descriptor("Core", "WindowSetAlwaysOnTop", "Set Always On Top", ACEDescriptor.ACEType.ACTION, "get_window().always_on_top = {enabled}", "", [F.make_param("enabled", "bool", "true", "Enabled", "Keep the window above other windows.", "expression")], CAT, "Set always on top to {enabled}")
		.described("Keeps the game window above every other window."))
	descriptors.append(F.make_descriptor("Core", "WindowMinimize", "Minimize Window", ACEDescriptor.ACEType.ACTION, "get_window().mode = Window.MODE_MINIMIZED", "", [], CAT, "Minimize")
		.described("Minimizes the game window to the taskbar."))
	descriptors.append(F.make_descriptor("Core", "WindowMaximize", "Maximize Window", ACEDescriptor.ACEType.ACTION, "get_window().mode = Window.MODE_MAXIMIZED", "", [], CAT, "Maximize")
		.described("Maximizes the game window."))

	# ── The render and screenshot half of the same family ──────
	# Each of these writes EXACTLY the plain Godot line the sheet reads back as its own words, so a
	# picked row and a hand-written one are the same bytes and the same sentence.
	descriptors.append(F.make_descriptor("Core", "WindowSetAntiAliasing", "Set Anti-aliasing", ACEDescriptor.ACEType.ACTION, "get_viewport().msaa_2d = {level}", "", [F.make_param("level", "String", "Viewport.MSAA_DISABLED", "Level", "How many samples smooth the edges. Off is fastest; 4x is the usual choice.", "", [{"key": "Viewport.MSAA_DISABLED", "label": "off"}, {"key": "Viewport.MSAA_2X", "label": "2×"}, {"key": "Viewport.MSAA_4X", "label": "4×"}, {"key": "Viewport.MSAA_8X", "label": "8×"}])], CAT, "Set anti-aliasing to [b]{level}[/b]")
		.described("Smooths jagged edges in what this viewport draws. Higher costs more to render, so an options screen usually offers it as a choice."))
	descriptors.append(F.make_descriptor("Core", "WindowSaveImageAs", "Save Image As", ACEDescriptor.ACEType.ACTION, "{image}.save_png({path})", "", [F.make_param("image", "String", "get_viewport().get_texture().get_image()", "Image", "The picture to write - a Screenshot expression, or a variable holding one.", "expression"), F.make_param("path", "String", "\"user://shot.png\"", "File", "Where to write the PNG (user:// is the writable folder).", "expression")], CAT, "Save image [b]{image}[/b] as [b]{path}[/b]")
		.described("Writes a picture to a PNG file. Pair it with Screenshot to save what the player is looking at."))
	descriptors.append(F.make_descriptor("Core", "WindowScreenshot", "Screenshot", ACEDescriptor.ACEType.EXPRESSION, "get_viewport().get_texture().get_image()", "", [], CAT, "a screenshot")
		.described("A picture of what is on screen right now. Put it in a variable, then Save Image As.").featured())
	descriptors.append(F.make_descriptor("Core", "WindowViewportImage", "Rendered As An Image", ACEDescriptor.ACEType.EXPRESSION, "{viewport}.get_texture()", "", [F.make_param("viewport", "String", "get_viewport()", "Viewport", "The viewport to photograph - $SubViewport for an off-screen one.", "expression")], CAT, "[b]{viewport}[/b] rendered as an image")
		.described("What a viewport is currently drawing, as a picture you can show on a sprite or save."))

	descriptors.append(F.make_descriptor("Core", "WindowIsFullscreen", "Is Fullscreen", ACEDescriptor.ACEType.CONDITION, "(get_window().mode == Window.MODE_FULLSCREEN or get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)", "", [], CAT, "Is fullscreen")
		.described("True while the game is in either fullscreen mode."))

	descriptors.append(F.make_descriptor("Core", "WindowMaxFps", "Max FPS", ACEDescriptor.ACEType.EXPRESSION, "Engine.max_fps", "", [], CAT, "max FPS")
		.described("The current frame-rate cap (0 means uncapped)."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Control the game window - fullscreen or windowed, size and position, vsync, and the frame-rate cap."}
