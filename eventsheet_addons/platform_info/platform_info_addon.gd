## @ace_tags(platform, device, screen, system)
## @ace_category("Platform Info")
@icon("res://eventsheet_addons/platform_info/icon.svg")
class_name PlatformInfoAddon
extends Node
## Answers "what is this game running on?" from event rows: which OS and device, screen size, DPI, refresh rate and safe area, touch support, the player's locale, the GPU and processor - so sheets can switch controls, scale UI, and pick quality presets per platform. Direct engine queries, no state.

## @ace_condition
## @ace_featured
## @ace_name("Is On Mobile")
## @ace_category("Platform Info")
## @ace_description("True on Android and iOS builds - the switch-to-touch-controls condition.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.is_mobile()")
func is_mobile() -> bool:
	return OS.has_feature("mobile")

## @ace_condition
## @ace_name("Is On Desktop")
## @ace_category("Platform Info")
## @ace_description("True on Windows, macOS, and Linux builds.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.is_desktop()")
func is_desktop() -> bool:
	return OS.has_feature("pc")

## @ace_condition
## @ace_name("Is On Web")
## @ace_category("Platform Info")
## @ace_description("True in browser (HTML5) exports - hide quit buttons, mind autoplay rules.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.is_web()")
func is_web() -> bool:
	return OS.has_feature("web")

## @ace_condition
## @ace_name("Has Touchscreen")
## @ace_category("Platform Info")
## @ace_description("True when a touchscreen is available (mobile, or a touch laptop).")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.has_touchscreen()")
func has_touchscreen() -> bool:
	return DisplayServer.is_touchscreen_available()

## @ace_condition
## @ace_name("Is Portrait")
## @ace_category("Platform Info")
## @ace_description("True while the window is taller than it is wide - branch layouts on rotation.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.is_portrait()")
func is_portrait() -> bool:
	var window_size: Vector2i = DisplayServer.window_get_size()
	return window_size.y > window_size.x

## @ace_condition
## @ace_name("Is Debug Build")
## @ace_category("Platform Info")
## @ace_description("True in editor runs and debug exports - gate cheats and dev overlays.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.is_debug_build()")
func is_debug_build() -> bool:
	return OS.is_debug_build()

## @ace_condition
## @ace_name("Has Feature Tag")
## @ace_category("Platform Info")
## @ace_description("True when the build has a feature tag - engine ones ("mobile", "web", "editor") or your own custom export tags ("demo", "steam").")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.has_feature({feature})")
func has_feature(feature: String) -> bool:
	return OS.has_feature(feature)

## @ace_expression
## @ace_featured
## @ace_name("OS Name")
## @ace_category("Platform Info")
## @ace_description("The operating system: "Windows", "macOS", "Linux", "Android", "iOS", "Web".")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.os_name()")
func os_name() -> String:
	return OS.get_name()

## @ace_expression
## @ace_name("OS Version")
## @ace_category("Platform Info")
## @ace_description("The operating system's version string.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.os_version()")
func os_version() -> String:
	return OS.get_version()

## @ace_expression
## @ace_name("Device Model")
## @ace_category("Platform Info")
## @ace_description("The device model name (phones report their model; desktops report "GenericDevice").")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.device_model()")
func device_model() -> String:
	return OS.get_model_name()

## @ace_expression
## @ace_name("Locale")
## @ace_category("Platform Info")
## @ace_description("The player's full locale, like "en_US" - default your language picker to it.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.locale()")
func locale() -> String:
	return OS.get_locale()

## @ace_expression
## @ace_name("Locale Language")
## @ace_category("Platform Info")
## @ace_description("Just the language part of the locale, like "en" or "ja".")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.locale_language()")
func locale_language() -> String:
	return OS.get_locale_language()

## @ace_expression
## @ace_name("Engine Version")
## @ace_category("Platform Info")
## @ace_description("The Godot version string, like "4.7.stable".")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.engine_version()")
func engine_version() -> String:
	return str(Engine.get_version_info().get("string", ""))

## @ace_expression
## @ace_name("Screen Width")
## @ace_category("Platform Info")
## @ace_description("The current screen's width in pixels (the whole display, not the window).")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.screen_width()")
func screen_width() -> int:
	return DisplayServer.screen_get_size().x

## @ace_expression
## @ace_name("Screen Height")
## @ace_category("Platform Info")
## @ace_description("The current screen's height in pixels.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.screen_height()")
func screen_height() -> int:
	return DisplayServer.screen_get_size().y

## @ace_expression
## @ace_featured
## @ace_name("Screen DPI")
## @ace_category("Platform Info")
## @ace_description("The screen's pixel density - scale touch buttons by it so they stay finger-sized.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.screen_dpi()")
func screen_dpi() -> int:
	return DisplayServer.screen_get_dpi()

## @ace_expression
## @ace_name("Screen Refresh Rate")
## @ace_category("Platform Info")
## @ace_description("The screen's refresh rate in Hz (-1 when unknown) - cap or uncap smoothing with it.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.screen_refresh_rate()")
func screen_refresh_rate() -> float:
	return DisplayServer.screen_get_refresh_rate()

## @ace_expression
## @ace_name("Screen Count")
## @ace_category("Platform Info")
## @ace_description("How many displays are connected.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.screen_count()")
func screen_count() -> int:
	return DisplayServer.get_screen_count()

## @ace_expression
## @ace_name("Screen Scale")
## @ace_category("Platform Info")
## @ace_description("The display's scale factor (2.0 on hiDPI/Retina screens; 1.0 elsewhere).")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.screen_scale()")
func screen_scale() -> float:
	return DisplayServer.screen_get_scale()

## @ace_expression
## @ace_name("Safe Area Top")
## @ace_category("Platform Info")
## @ace_description("Pixels shaved off the screen's TOP by notches/status bars - pad your HUD down by it.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.safe_area_top()")
func safe_area_top() -> int:
	return DisplayServer.get_display_safe_area().position.y

## @ace_expression
## @ace_name("Safe Area Left")
## @ace_category("Platform Info")
## @ace_description("Pixels shaved off the screen's LEFT edge by cutouts.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.safe_area_left()")
func safe_area_left() -> int:
	return DisplayServer.get_display_safe_area().position.x

## @ace_expression
## @ace_name("Safe Area Bottom Inset")
## @ace_category("Platform Info")
## @ace_description("Pixels shaved off the BOTTOM (home indicators): screen height minus the safe area's end.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.safe_area_bottom_inset()")
func safe_area_bottom_inset() -> int:
	var area: Rect2i = DisplayServer.get_display_safe_area()
	return maxi(DisplayServer.screen_get_size().y - area.end.y, 0)

## @ace_expression
## @ace_name("Safe Area Right Inset")
## @ace_category("Platform Info")
## @ace_description("Pixels shaved off the RIGHT edge: screen width minus the safe area's end.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.safe_area_right_inset()")
func safe_area_right_inset() -> int:
	var area: Rect2i = DisplayServer.get_display_safe_area()
	return maxi(DisplayServer.screen_get_size().x - area.end.x, 0)

## @ace_expression
## @ace_name("GPU Name")
## @ace_category("Platform Info")
## @ace_description("The graphics adapter's name - match against known slow chips to pick a quality preset.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.gpu_name()")
func gpu_name() -> String:
	return RenderingServer.get_video_adapter_name()

## @ace_expression
## @ace_name("GPU Vendor")
## @ace_category("Platform Info")
## @ace_description("The graphics adapter's vendor ("NVIDIA", "AMD", "Intel", "Apple"...).")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.gpu_vendor()")
func gpu_vendor() -> String:
	return RenderingServer.get_video_adapter_vendor()

## @ace_expression
## @ace_name("Rendering Method")
## @ace_category("Platform Info")
## @ace_description("Which renderer is live: "forward_plus", "mobile", or "gl_compatibility".")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.rendering_method()")
func rendering_method() -> String:
	return RenderingServer.get_current_rendering_method()

## @ace_expression
## @ace_name("CPU Thread Count")
## @ace_category("Platform Info")
## @ace_description("How many CPU threads the machine has - budget background work with it.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.cpu_thread_count()")
func cpu_thread_count() -> int:
	return OS.get_processor_count()

## @ace_expression
## @ace_name("CPU Name")
## @ace_category("Platform Info")
## @ace_description("The CPU's name string.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.cpu_name()")
func cpu_name() -> String:
	return OS.get_processor_name()

## @ace_expression
## @ace_name("Physical Memory (MB)")
## @ace_category("Platform Info")
## @ace_description("The machine's physical RAM in megabytes (0 where the OS hides it) - drop texture quality under a threshold.")
## @ace_icon("res://eventsheet_addons/platform_info/icon.svg")
## @ace_codegen_template("PlatformInfo.memory_physical_mb()")
func memory_physical_mb() -> float:
	return float(OS.get_memory_info().get("physical", 0)) / 1048576.0

# Platform Info: register as the PlatformInfo autoload, then branch on the machine from any sheet - Is On Mobile switches to touch controls, Screen DPI scales the HUD, Safe Area Top pads under a notch, GPU Name picks a quality preset. Everything is a live engine query. This pack is an event sheet - extend it by editing it.
