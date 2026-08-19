# EventForge module - the things AROUND an object: picking, layers and Z order, text, the browser.
#
# Every row here is the AUTHORING half of a reading: the template writes exactly the GDScript the
# reading recognises, so a row dropped from the picker and the same shape typed by hand are the same
# bytes and read as the same sentence either way.
#
#  - PICKING says WHICH instances the rows below are about: nearest, farthest, random, by
#    comparison, top, bottom, by UID. Each writes the name it filled, because a pick that nothing can
#    refer to afterwards is a pick nobody can use. They are actions rather than conditions for one
#    honest reason: a condition compiles to a single boolean expression, and there is nowhere in one
#    for the `var` that holds what was picked.
#  - LAYERS AND Z ORDER: a CanvasLayer IS a layer and `z_index` IS the drawing order within one, so
#    Move to layer is a reparent and Move to top of layer is `move_to_front()`.
#  - TEXT: the drawn styling of a label - size, colour, alignment, wrap, the font itself - which
#    Godot spreads over theme overrides and a LabelSettings resource.
#  - BROWSER AND PLATFORM: opening a link, the clipboard, fullscreen, an alert, and what the game is
#    running on. The platform questions are worded exactly as the shipped Platform Info pack words
#    them, so the two never disagree.
#
# Every template is plain GDScript over native calls: no plugin runtime, no helper library.
# ace_ids and codegen_templates are a compatibility covenant: frozen once shipped (deprecate, never rename).
@tool
class_name EventForgeAroundObjectsACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
const CAT_PICKING := "Nodes: Picking"
const CAT_LAYERS := "Layers"
const CAT_TEXT := "Text"
const CAT_BROWSER := "Browser"
const CAT_PLATFORM := "Platform"

## The list a pick walks. A group is how a Godot project spells "every instance of this kind", which
## is why it is the default: the pick rows read as a family the moment the group names one.
const LIST_DEFAULT := "get_tree().get_nodes_in_group(\"enemy\")"

## The platforms `OS.get_name()` answers with, so the condition is a choice rather than a typed
## string nobody can spell twice the same way.
const PLATFORM_NAMES: Array = [
	{"key": "\"Windows\"", "label": "Windows"}, {"key": "\"macOS\"", "label": "macOS"},
	{"key": "\"Linux\"", "label": "Linux"}, {"key": "\"Android\"", "label": "Android"},
	{"key": "\"iOS\"", "label": "iOS"}, {"key": "\"Web\"", "label": "Web"}
]


## The name a pick fills. Always a plain identifier, because the rows below it refer to it by name.
static func _picked_name_param() -> ACEParam:
	return F.make_param("name", "String", "picked", "Name it",
		"The name the picked instance is known by from here on. The rows below use it.")


## The list a pick walks.
static func _list_param() -> ACEParam:
	return F.make_param("list", "String", LIST_DEFAULT, "From",
		"The instances to pick from - usually a group, which is how a project spells \"every one of this kind\".",
		"expression")


static func get_descriptors() -> Array[ACEDescriptor]:
	var d: Array[ACEDescriptor] = []
	_picking(d)
	_layers(d)
	_text(d)
	_browser(d)
	return d


## Which instances the rows below are about.
static func _picking(d: Array[ACEDescriptor]) -> void:
	d.append(F.make_descriptor("Core", "PickNearest", "Pick Nearest", ACEDescriptor.ACEType.ACTION,
		"var {name} = null\nvar __best_{uid} = INF\nfor __each_{uid} in {list}:\n\tvar __gap_{uid} = {from}.distance_to(__each_{uid}.global_position)\n\tif __gap_{uid} < __best_{uid}:\n\t\t__best_{uid} = __gap_{uid}\n\t\t{name} = __each_{uid}",
		"", [_picked_name_param(), _list_param(),
			F.make_param("from", "String", "global_position", "Nearest to",
				"The position distances are measured from.", "expression")],
		CAT_PICKING, "pick nearest of [i]{list}[/i] to {from} -> [b]{name}[/b]", "Node2D")
		.described("Walks the instances and keeps the one closest to a position - the shape a turret, a homing shot and a \"talk to whoever is in front of me\" row are all built from. Fills the name you give it, so the rows below can act on the one it found. Nothing is picked when the list is empty, so check the name exists before using it."))

	d.append(F.make_descriptor("Core", "PickFarthest", "Pick Farthest", ACEDescriptor.ACEType.ACTION,
		"var {name} = null\nvar __best_{uid} = -INF\nfor __each_{uid} in {list}:\n\tvar __gap_{uid} = {from}.distance_to(__each_{uid}.global_position)\n\tif __gap_{uid} > __best_{uid}:\n\t\t__best_{uid} = __gap_{uid}\n\t\t{name} = __each_{uid}",
		"", [_picked_name_param(), _list_param(),
			F.make_param("from", "String", "global_position", "Farthest from",
				"The position distances are measured from.", "expression")],
		CAT_PICKING, "pick farthest of [i]{list}[/i] from {from} -> [b]{name}[/b]", "Node2D")
		.described("The other end of Pick Nearest: keeps the instance furthest from a position. Useful for spawning away from the player, retreating, and picking the loneliest of a crowd."))

	d.append(F.make_descriptor("Core", "PickRandomInstance", "Pick A Random One", ACEDescriptor.ACEType.ACTION,
		"var {name} = {list}.pick_random()", "", [_picked_name_param(), _list_param()],
		CAT_PICKING, "pick a random one of [i]{list}[/i] -> [b]{name}[/b]")
		.described("One instance at random out of the list, named so the rows below can act on it. An empty list has nothing to pick, so check the name exists first."))

	d.append(F.make_descriptor("Core", "PickWhere", "Pick Where", ACEDescriptor.ACEType.ACTION,
		"var {name} = {list}.filter(func({item}): return {test})", "",
		[_picked_name_param(), _list_param(),
			F.make_param("item", "String", "one", "Call each one",
				"The name each instance goes by inside the test."),
			F.make_param("test", "String", "one.visible", "Keep it when",
				"The question asked of each instance. Only the ones it holds for are kept.", "expression")],
		CAT_PICKING, "pick every one of [i]{list}[/i] where {test} -> [b]{name}[/b]")
		.described("Keeps every instance the test holds for - the \"pick by comparison\" of an event sheet. The result is a list, so the rows below run over what it holds rather than over one instance."))

	d.append(F.make_descriptor("Core", "PickTop", "Pick Top", ACEDescriptor.ACEType.ACTION,
		"var {name} = {list}.back()", "", [_picked_name_param(), _list_param()],
		CAT_PICKING, "pick the top one of [i]{list}[/i] -> [b]{name}[/b]")
		.described("The LAST instance in the list - the newest one when the list is in the order things were made, and the one drawn over the others in a scene's own order."))

	d.append(F.make_descriptor("Core", "PickBottom", "Pick Bottom", ACEDescriptor.ACEType.ACTION,
		"var {name} = {list}.front()", "", [_picked_name_param(), _list_param()],
		CAT_PICKING, "pick the bottom one of [i]{list}[/i] -> [b]{name}[/b]")
		.described("The FIRST instance in the list - the oldest one when the list is in the order things were made."))

	d.append(F.make_descriptor("Core", "PickByUid", "Pick By UID", ACEDescriptor.ACEType.ACTION,
		"var {name} = instance_from_id({uid_value})", "",
		[_picked_name_param(),
			F.make_param("uid_value", "String", "0", "UID",
				"The unique id an instance was remembered by. Get one with Object.get_instance_id().", "expression")],
		CAT_PICKING, "pick the one with UID {uid_value} -> [b]{name}[/b]")
		.described("Finds one instance again from the unique id it was remembered by - the way to store \"which one\" in a variable, a save file or a table. Nothing is found when that instance is gone, so check the name exists before using it."))


## Where an object sits in the drawing order.
static func _layers(d: Array[ACEDescriptor]) -> void:
	d.append(F.make_descriptor("Core", "SetZOrder", "Set Z Order", ACEDescriptor.ACEType.ACTION,
		"z_index = {order}", "",
		[F.make_param("order", "String", "0", "Z order",
			"Higher draws in front. Objects on a later layer always draw over an earlier one, whatever their Z order.", "expression")],
		CAT_LAYERS, "set Z order to [b]{order}[/b]", "CanvasItem")
		.described("Where this object draws among the others on its layer: a higher number draws in front. Layers come first - a HUD layer above the world draws over everything in it no matter what the Z orders say."))

	d.append(F.make_descriptor("Core", "SetZOrderAbsolute", "Set Z Order Absolute", ACEDescriptor.ACEType.ACTION,
		"z_as_relative = false", "", [], CAT_LAYERS, "set Z order absolute", "CanvasItem")
		.described("Makes the Z order count from the layer rather than from this object's parent, so a child no longer inherits where its parent sits."))

	d.append(F.make_descriptor("Core", "SetZOrderRelative", "Set Z Order Relative", ACEDescriptor.ACEType.ACTION,
		"z_as_relative = true", "", [], CAT_LAYERS, "set Z order relative to the layer", "CanvasItem")
		.described("Makes the Z order count from this object's parent - Godot's default, and what you want for a sprite that should move up and down the order with whatever holds it."))

	d.append(F.make_descriptor("Core", "MoveToTopOfLayer", "Move To Top Of Layer", ACEDescriptor.ACEType.ACTION,
		"move_to_front()", "", [], CAT_LAYERS, "move to top of layer", "CanvasItem")
		.described("Draws this object over every sibling on its layer, without touching any Z order. The card you just picked up, the window you just clicked."))

	# Godot gives a canvas item `move_to_front()` and no opposite, so the other end is spelled the way
	# the engine spells it: first among the parent's children is first drawn, i.e. furthest back.
	d.append(F.make_descriptor("Core", "MoveToBottomOfLayer", "Move To Bottom Of Layer", ACEDescriptor.ACEType.ACTION,
		"get_parent().move_child(self, 0)", "", [], CAT_LAYERS, "move to bottom of layer", "Node")
		.described("Draws this object behind every sibling on its layer - the card you just put down."))

	d.append(F.make_descriptor("Core", "MoveToLayer", "Move To Layer", ACEDescriptor.ACEType.ACTION,
		"reparent({layer})", "",
		[F.make_param("layer", "String", "$\"../FX\"", "Layer",
			"The node this object moves under. In a 2D scene that node IS the layer it draws on.", "expression")],
		CAT_LAYERS, "move to layer [b]{layer}[/b]", "Node")
		.described("Moves this object onto another layer, keeping where it is on screen. A CanvasLayer is the layer proper (it has its own order and its own visibility); a plain node used to group things works the same way for drawing order."))

	d.append(F.make_descriptor("Core", "SetLayerOrder", "Set Layer Order", ACEDescriptor.ACEType.ACTION,
		"layer = {order}", "",
		[F.make_param("order", "String", "1", "Layer order",
			"Higher draws in front of every lower layer, whatever the objects on them say.", "expression")],
		CAT_LAYERS, "set layer order to [b]{order}[/b]", "CanvasLayer")
		.described("Where this whole layer sits among the others: a HUD on a higher layer draws over the world however the world's objects are ordered among themselves."))

	# Showing and hiding a layer is the shipped Set Visible / Set Invisible row - a CanvasLayer's
	# `visible` is the same property every other object has. A second row writing the same line would
	# take the lift away from the first one and make every hidden SPRITE read as a hidden layer.


## How drawn text is styled.
static func _text(d: Array[ACEDescriptor]) -> void:
	d.append(F.make_descriptor("Core", "SetFontSize", "Set Font Size", ACEDescriptor.ACEType.ACTION,
		"add_theme_font_size_override(\"font_size\", {size})", "",
		[F.make_param("size", "String", "16", "Size", "The font size in pixels.", "expression")],
		CAT_TEXT, "set font size to [b]{size}[/b]", "Control")
		.described("Sets the size this control draws its text at, over whatever its theme says. Applies to this control only, so a heading and its body can differ without a theme of their own."))

	d.append(F.make_descriptor("Core", "SetFontColour", "Set Font Colour", ACEDescriptor.ACEType.ACTION,
		"add_theme_color_override(\"font_color\", {colour})", "",
		[F.make_param("colour", "String", "Color(1, 1, 1, 1)", "Colour", "The colour the text draws in.", "color")],
		CAT_TEXT, "set font colour to [b]{colour}[/b]", "Control")
		.described("Sets the colour this control draws its text in, over whatever its theme says - the red of a damage number, the grey of a disabled option."))

	d.append(F.make_descriptor("Core", "SetOutlineColour", "Set Outline Colour", ACEDescriptor.ACEType.ACTION,
		"add_theme_color_override(\"font_outline_color\", {colour})", "",
		[F.make_param("colour", "String", "Color(0, 0, 0, 1)", "Colour", "The colour the outline draws in.", "color")],
		CAT_TEXT, "set outline colour to [b]{colour}[/b]", "Control")
		.described("Sets the colour of the outline around the text. An outline only shows once its SIZE is set too, in the control's theme or its label settings."))

	d.append(F.make_descriptor("Core", "SetFontFile", "Set Font", ACEDescriptor.ACEType.ACTION,
		"add_theme_font_override(\"font\", {font})", "",
		[F.make_param("font", "String", "ThemeDB.fallback_font", "Font",
			"The font file this control draws with.", "expression")],
		CAT_TEXT, "set font to [b]{font}[/b]", "Control")
		.described("Gives this one control its own font, over whatever its theme says. Drag a .ttf or .otf from the FileSystem to fill it in."))

	# Alignment has no row of its own yet, on purpose: a row would carry the engine constant as its
	# value, and a lifted line would then read `set horizontal alignment to HORIZONTAL_ALIGNMENT_
	# CENTER` where the reading says `Set horizontal alignment to centre`. The reading is the promise;
	# a row that makes it worse is not parity. Set Property reaches the same property meanwhile.

	d.append(F.make_descriptor("Core", "SetWordWrapOn", "Set Word Wrap On", ACEDescriptor.ACEType.ACTION,
		"autowrap_mode = TextServer.AUTOWRAP_WORD", "", [],
		CAT_TEXT, "set word wrap on", "Label")
		.described("Wraps long text onto the next line at word boundaries instead of running off the edge. The box has to have a width for wrapping to have anything to wrap to."))

	d.append(F.make_descriptor("Core", "SetWordWrapOff", "Set Word Wrap Off", ACEDescriptor.ACEType.ACTION,
		"autowrap_mode = TextServer.AUTOWRAP_OFF", "", [],
		CAT_TEXT, "set word wrap off", "Label")
		.described("Keeps the text on one line, however long it gets."))

	d.append(F.make_descriptor("Core", "TranslatedText", "Translated", ACEDescriptor.ACEType.EXPRESSION,
		"tr({key})", "",
		[F.make_param("key", "String", "\"HELLO\"", "Key",
			"The translation key. The game's own language decides what it shows.", "expression")],
		CAT_TEXT, "translated {key}")
		.described("The text a translation key stands for in the game's current language, falling back to the key itself when nothing translates it."))


## Opening a link, the clipboard, fullscreen, and what the game is running on.
static func _browser(d: Array[ACEDescriptor]) -> void:
	d.append(F.make_descriptor("Core", "GoToUrl", "Go To URL", ACEDescriptor.ACEType.ACTION,
		"OS.shell_open({url})", "",
		[F.make_param("url", "String", "\"https://example.com\"", "URL",
			"The address to open. Opens in the player's own browser - in a web build, in a new tab.", "expression")],
		CAT_BROWSER, "go to URL [b]{url}[/b]")
		.described("Opens a web address outside the game: a store page, a wiki, a bug form. It leaves the game running, so say where the player is going before you send them there."))

	# Copying to the clipboard already ships as Core/SetClipboard; it wears the Browser words now
	# rather than a second row writing the same line under a second name.
	d.append(F.make_descriptor("Core", "RequestFullscreen", "Request Fullscreen", ACEDescriptor.ACEType.ACTION,
		"DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)", "", [],
		CAT_BROWSER, "request fullscreen")
		.described("Takes the game fullscreen. In a web build a browser only grants this from a real click, which is why it belongs under a button's own event rather than under a timer."))

	d.append(F.make_descriptor("Core", "LeaveFullscreen", "Leave Fullscreen", ACEDescriptor.ACEType.ACTION,
		"DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)", "", [],
		CAT_BROWSER, "leave fullscreen")
		.described("Puts the game back in a window."))

	d.append(F.make_descriptor("Core", "BrowserAlert", "Alert", ACEDescriptor.ACEType.ACTION,
		"OS.alert({message})", "",
		[F.make_param("message", "String", "\"\"", "Message", "What the box says.", "expression")],
		CAT_BROWSER, "alert [b]{message}[/b]")
		.described("Shows a plain system message box and waits for the player to dismiss it. It stops everything while it is up, so it is for the one thing that must be read - not for anything the game itself can say."))

	d.append(F.make_descriptor("Core", "VibrateHandheld", "Vibrate", ACEDescriptor.ACEType.ACTION,
		"Input.vibrate_handheld({milliseconds})", "",
		[F.make_param("milliseconds", "String", "100", "For (ms)",
			"How long the buzz lasts, in milliseconds.", "expression")],
		CAT_BROWSER, "vibrate for [b]{milliseconds}[/b] ms")
		.described("Buzzes a phone or tablet. Does nothing on a desktop, so it is safe to leave in a build that runs on both."))

	d.append(F.make_descriptor("Core", "IsPlatform", "Is Platform", ACEDescriptor.ACEType.CONDITION,
		"OS.get_name() == {platform}", "",
		[F.make_param("platform", "String", "\"Android\"", "Platform",
			"Which system the game is running on.", "", PLATFORM_NAMES)],
		CAT_PLATFORM, "is [b]{platform}[/b]")
		.described("True on one named system. For a question about a whole family - every phone, every browser - Is On Mobile and Is On Web are the sturdier ones, because they cover systems added later."))

	d.append(F.make_descriptor("Core", "IsOnWebPlatform", "Is On Web", ACEDescriptor.ACEType.CONDITION,
		"OS.has_feature(\"web\")", "", [], CAT_PLATFORM, "is on web")
		.described("True in a browser build. Hide the quit button, mind that sound and fullscreen need a real click first."))

	d.append(F.make_descriptor("Core", "IsOnMobilePlatform", "Is On Mobile", ACEDescriptor.ACEType.CONDITION,
		"OS.has_feature(\"mobile\")", "", [], CAT_PLATFORM, "is on mobile")
		.described("True on Android and iOS builds - the switch-to-touch-controls question."))

	d.append(F.make_descriptor("Core", "IsOnDesktopPlatform", "Is On Desktop", ACEDescriptor.ACEType.CONDITION,
		"OS.has_feature(\"pc\")", "", [], CAT_PLATFORM, "is on desktop")
		.described("True on Windows, macOS and Linux builds."))
