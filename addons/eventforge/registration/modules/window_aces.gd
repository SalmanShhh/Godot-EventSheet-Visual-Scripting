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

	descriptors.append(F.make_descriptor("Core", "WindowGoFullscreen", "Go Fullscreen", ACEDescriptor.ACEType.ACTION, "get_window().mode = Window.MODE_FULLSCREEN", "", [], CAT, "go fullscreen")
		.described("Switches the game to borderless fullscreen."))
	descriptors.append(F.make_descriptor("Core", "WindowGoWindowed", "Go Windowed", ACEDescriptor.ACEType.ACTION, "get_window().mode = Window.MODE_WINDOWED", "", [], CAT, "go windowed")
		.described("Switches the game back to a normal window."))
	descriptors.append(F.make_descriptor("Core", "WindowGoExclusive", "Go Exclusive Fullscreen", ACEDescriptor.ACEType.ACTION, "get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN", "", [], CAT, "go exclusive fullscreen")
		.described("Switches to exclusive fullscreen (the mode that takes over the whole display)."))
	descriptors.append(F.make_descriptor("Core", "WindowToggleFullscreen", "Toggle Fullscreen", ACEDescriptor.ACEType.ACTION, "get_window().mode = Window.MODE_WINDOWED if get_window().mode != Window.MODE_WINDOWED else Window.MODE_FULLSCREEN", "", [], CAT, "toggle fullscreen")
		.described("Flips between fullscreen and windowed - handy on an Alt+Enter shortcut.").featured())
	descriptors.append(F.make_descriptor("Core", "WindowSetSize", "Set Window Size", ACEDescriptor.ACEType.ACTION, "get_window().size = Vector2i({width}, {height})", "", [F.make_param("width", "int", "1280", "Width", "Window width in pixels.", "expression"), F.make_param("height", "int", "720", "Height", "Window height in pixels.", "expression")], CAT, "set window size {width} x {height}")
		.described("Resizes the game window to an exact pixel size."))
	descriptors.append(F.make_descriptor("Core", "WindowSetPosition", "Set Window Position", ACEDescriptor.ACEType.ACTION, "get_window().position = Vector2i({x}, {y})", "", [F.make_param("x", "int", "0", "X", "Left edge in screen pixels.", "expression"), F.make_param("y", "int", "0", "Y", "Top edge in screen pixels.", "expression")], CAT, "move window to {x}, {y}")
		.described("Moves the game window to a position on the screen."))
	descriptors.append(F.make_descriptor("Core", "WindowCenter", "Center Window", ACEDescriptor.ACEType.ACTION, "get_window().move_to_center()", "", [], CAT, "center window")
		.described("Centers the game window on the screen."))
	descriptors.append(F.make_descriptor("Core", "WindowSetVSync", "Set VSync Enabled", ACEDescriptor.ACEType.ACTION, "DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if {enabled} else DisplayServer.VSYNC_DISABLED)", "", [F.make_param("enabled", "bool", "true", "Enabled", "On removes screen tearing; off can raise the frame rate.", "expression")], CAT, "set vsync {enabled}")
		.described("Turns vertical sync on or off - a common options-menu toggle."))
	descriptors.append(F.make_descriptor("Core", "WindowSetMaxFps", "Set Max FPS", ACEDescriptor.ACEType.ACTION, "Engine.max_fps = {fps}", "", [F.make_param("fps", "int", "60", "Max FPS", "Frame-rate cap (0 = uncapped).", "expression")], CAT, "set max fps {fps}")
		.described("Caps the frame rate (0 means uncapped)."))
	descriptors.append(F.make_descriptor("Core", "WindowSetAlwaysOnTop", "Set Always On Top", ACEDescriptor.ACEType.ACTION, "get_window().always_on_top = {enabled}", "", [F.make_param("enabled", "bool", "true", "Enabled", "Keep the window above other windows.", "expression")], CAT, "set always on top {enabled}")
		.described("Keeps the game window above every other window."))
	descriptors.append(F.make_descriptor("Core", "WindowMinimize", "Minimize Window", ACEDescriptor.ACEType.ACTION, "get_window().mode = Window.MODE_MINIMIZED", "", [], CAT, "minimize window")
		.described("Minimizes the game window to the taskbar."))
	descriptors.append(F.make_descriptor("Core", "WindowMaximize", "Maximize Window", ACEDescriptor.ACEType.ACTION, "get_window().mode = Window.MODE_MAXIMIZED", "", [], CAT, "maximize window")
		.described("Maximizes the game window."))

	descriptors.append(F.make_descriptor("Core", "WindowIsFullscreen", "Is Fullscreen", ACEDescriptor.ACEType.CONDITION, "(get_window().mode == Window.MODE_FULLSCREEN or get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN)", "", [], CAT, "window is fullscreen")
		.described("True while the game is in either fullscreen mode."))

	descriptors.append(F.make_descriptor("Core", "WindowMaxFps", "Max FPS", ACEDescriptor.ACEType.EXPRESSION, "Engine.max_fps", "", [], CAT, "max fps")
		.described("The current frame-rate cap (0 means uncapped)."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Control the game window - fullscreen or windowed, size and position, vsync, and the frame-rate cap."}
