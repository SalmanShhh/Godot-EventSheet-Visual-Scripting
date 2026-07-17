# Pack builder - platform_info (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

const CAT := "Platform Info"


## Platform Info: Construct's Platform Info plugin, Godot-shaped - one autoload answering
## "what am I running on?" from plain event rows: OS / device / screen / touch / locale /
## GPU / processor conditions and expressions. Every call is a direct engine query (parity
## covenant - no caching layer, no state), so the pack is a bank of pure lookups.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "PlatformInfo"
	sheet.host_class = "Node"
	sheet.custom_class_name = "PlatformInfoAddon"
	sheet.class_description = "Answers \"what is this game running on?\" from event rows: which OS and device, screen size, DPI, refresh rate and safe area, touch support, the player's locale, the GPU and processor - so sheets can switch controls, scale UI, and pick quality presets per platform. Direct engine queries, no state."
	sheet.addon_category = "Platform Info"
	sheet.addon_tags = PackedStringArray(["platform", "device", "screen", "system"])
	var about: CommentRow = CommentRow.new()
	about.text = "Platform Info: register as the PlatformInfo autoload, then branch on the machine from any sheet - Is On Mobile switches to touch controls, Screen DPI scales the HUD, Safe Area Top pads under a notch, GPU Name picks a quality preset. Everything is a live engine query. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	# ── Where am I running? (the C3 is-on-platform family, via Godot feature tags) ──
	Lib.condition(sheet, "is_mobile", "Is On Mobile", CAT,
		"True on Android and iOS builds - the switch-to-touch-controls condition.",
		[], "return OS.has_feature(\"mobile\")")
	Lib.condition(sheet, "is_desktop", "Is On Desktop", CAT,
		"True on Windows, macOS, and Linux builds.",
		[], "return OS.has_feature(\"pc\")")
	Lib.condition(sheet, "is_web", "Is On Web", CAT,
		"True in browser (HTML5) exports - hide quit buttons, mind autoplay rules.",
		[], "return OS.has_feature(\"web\")")
	Lib.condition(sheet, "has_touchscreen", "Has Touchscreen", CAT,
		"True when a touchscreen is available (mobile, or a touch laptop).",
		[], "return DisplayServer.is_touchscreen_available()")
	Lib.condition(sheet, "is_portrait", "Is Portrait", CAT,
		"True while the window is taller than it is wide - branch layouts on rotation.",
		[], "var window_size: Vector2i = DisplayServer.window_get_size()\nreturn window_size.y > window_size.x")
	Lib.condition(sheet, "is_debug_build", "Is Debug Build", CAT,
		"True in editor runs and debug exports - gate cheats and dev overlays.",
		[], "return OS.is_debug_build()")
	Lib.condition(sheet, "has_feature", "Has Feature Tag", CAT,
		"True when the build has a feature tag - engine ones (\"mobile\", \"web\", \"editor\") or your own custom export tags (\"demo\", \"steam\").",
		[["feature", "String"]], "return OS.has_feature(feature)")

	# ── The machine (OS / device / engine) ──
	Lib.number(sheet, "os_name", "OS Name", CAT,
		"The operating system: \"Windows\", \"macOS\", \"Linux\", \"Android\", \"iOS\", \"Web\".",
		[], "return OS.get_name()", TYPE_STRING)
	Lib.number(sheet, "os_version", "OS Version", CAT,
		"The operating system's version string.",
		[], "return OS.get_version()", TYPE_STRING)
	Lib.number(sheet, "device_model", "Device Model", CAT,
		"The device model name (phones report their model; desktops report \"GenericDevice\").",
		[], "return OS.get_model_name()", TYPE_STRING)
	Lib.number(sheet, "locale", "Locale", CAT,
		"The player's full locale, like \"en_US\" - default your language picker to it.",
		[], "return OS.get_locale()", TYPE_STRING)
	Lib.number(sheet, "locale_language", "Locale Language", CAT,
		"Just the language part of the locale, like \"en\" or \"ja\".",
		[], "return OS.get_locale_language()", TYPE_STRING)
	Lib.number(sheet, "engine_version", "Engine Version", CAT,
		"The Godot version string, like \"4.7.stable\".",
		[], "return str(Engine.get_version_info().get(\"string\", \"\"))", TYPE_STRING)

	# ── The screen ──
	Lib.number(sheet, "screen_width", "Screen Width", CAT,
		"The current screen's width in pixels (the whole display, not the window).",
		[], "return DisplayServer.screen_get_size().x", TYPE_INT)
	Lib.number(sheet, "screen_height", "Screen Height", CAT,
		"The current screen's height in pixels.",
		[], "return DisplayServer.screen_get_size().y", TYPE_INT)
	Lib.number(sheet, "screen_dpi", "Screen DPI", CAT,
		"The screen's pixel density - scale touch buttons by it so they stay finger-sized.",
		[], "return DisplayServer.screen_get_dpi()", TYPE_INT)
	Lib.number(sheet, "screen_refresh_rate", "Screen Refresh Rate", CAT,
		"The screen's refresh rate in Hz (-1 when unknown) - cap or uncap smoothing with it.",
		[], "return DisplayServer.screen_get_refresh_rate()", TYPE_FLOAT)
	Lib.number(sheet, "screen_count", "Screen Count", CAT,
		"How many displays are connected.",
		[], "return DisplayServer.get_screen_count()", TYPE_INT)
	Lib.number(sheet, "screen_scale", "Screen Scale", CAT,
		"The display's scale factor (2.0 on hiDPI/Retina screens; 1.0 elsewhere).",
		[], "return DisplayServer.screen_get_scale()", TYPE_FLOAT)
	Lib.number(sheet, "safe_area_top", "Safe Area Top", CAT,
		"Pixels shaved off the screen's TOP by notches/status bars - pad your HUD down by it.",
		[], "return DisplayServer.get_display_safe_area().position.y", TYPE_INT)
	Lib.number(sheet, "safe_area_left", "Safe Area Left", CAT,
		"Pixels shaved off the screen's LEFT edge by cutouts.",
		[], "return DisplayServer.get_display_safe_area().position.x", TYPE_INT)
	Lib.number(sheet, "safe_area_bottom_inset", "Safe Area Bottom Inset", CAT,
		"Pixels shaved off the BOTTOM (home indicators): screen height minus the safe area's end.",
		[], "var area: Rect2i = DisplayServer.get_display_safe_area()\nreturn maxi(DisplayServer.screen_get_size().y - area.end.y, 0)", TYPE_INT)
	Lib.number(sheet, "safe_area_right_inset", "Safe Area Right Inset", CAT,
		"Pixels shaved off the RIGHT edge: screen width minus the safe area's end.",
		[], "var area: Rect2i = DisplayServer.get_display_safe_area()\nreturn maxi(DisplayServer.screen_get_size().x - area.end.x, 0)", TYPE_INT)

	# ── The hardware (GPU / CPU / memory) ──
	Lib.number(sheet, "gpu_name", "GPU Name", CAT,
		"The graphics adapter's name - match against known slow chips to pick a quality preset.",
		[], "return RenderingServer.get_video_adapter_name()", TYPE_STRING)
	Lib.number(sheet, "gpu_vendor", "GPU Vendor", CAT,
		"The graphics adapter's vendor (\"NVIDIA\", \"AMD\", \"Intel\", \"Apple\"...).",
		[], "return RenderingServer.get_video_adapter_vendor()", TYPE_STRING)
	Lib.number(sheet, "rendering_method", "Rendering Method", CAT,
		"Which renderer is live: \"forward_plus\", \"mobile\", or \"gl_compatibility\".",
		[], "return RenderingServer.get_current_rendering_method()", TYPE_STRING)
	Lib.number(sheet, "cpu_thread_count", "CPU Thread Count", CAT,
		"How many CPU threads the machine has - budget background work with it.",
		[], "return OS.get_processor_count()", TYPE_INT)
	Lib.number(sheet, "cpu_name", "CPU Name", CAT,
		"The CPU's name string.",
		[], "return OS.get_processor_name()", TYPE_STRING)
	Lib.number(sheet, "memory_physical_mb", "Physical Memory (MB)", CAT,
		"The machine's physical RAM in megabytes (0 where the OS hides it) - drop texture quality under a threshold.",
		[], "return float(OS.get_memory_info().get(\"physical\", 0)) / 1048576.0", TYPE_FLOAT)

	return Lib.save_pack(sheet, "res://eventsheet_addons/platform_info/platform_info_addon")
