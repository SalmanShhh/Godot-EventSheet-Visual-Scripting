# EventForge - the ONE reader of `.gdshader` uniform lines.
#
# A shader file already declares everything a sheet needs to know about the dials it exposes: what
# each one is called, what type it is, what range it wants, what it starts at, and - when the author
# wrote one - what it is for. Today a row asks for that name as a free typed string, which Godot
# accepts silently: `set_shader_parameter(&"disolve", 1.0)` is not an error, it simply never does
# anything. So the file is read instead of retyped, and every row that names a dial names one the
# shader really declares.
#
# ONE READER. The picked vocabulary, the lift's guard and the health checks all ask here, so a
# project can never be told two different things about the same file.
#
# WHAT IS PARSED, and what is not. A uniform declaration written on one line:
#
#     // How much of the sprite has burned away.
#     uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
#
# gives back the name, the type, the hints as the author wrote them, the default text, and the `//`
# comment block directly above it as the description. A declaration SPLIT ACROSS LINES is left alone
# rather than guessed at: nothing here may claim a dial it cannot name exactly, because a wrong name
# is the very failure this exists to prevent.
#
# CACHED BY path|mtime|size, exactly like the ACE definition cache, and for the same reason: the
# picker asks per keystroke and the lift asks per line, while a shader file changes when somebody
# saves it. Two saves inside one second would share an mtime, so the byte length rides along.
#
# PURE + STATIC: a path in, plain Dictionaries out. No dock, no canvas, no editor.
@tool
class_name EventForgeShaderUniforms
extends RefCounted

## The extension a shader file has. Asked before a path is opened, so a `.tres` handed here by
## mistake reads as "no dials" rather than as a parse of whatever it happened to contain.
const SHADER_EXTENSION: String = "gdshader"

## The hint that says a colour uniform is a COLOUR rather than four numbers - the one Godot's own
## Inspector reads to decide between a swatch and four spinboxes.
const HINT_COLOR: String = "source_color"

## The hint that carries a slider's ends: `hint_range(from, to)` with an optional step.
const HINT_RANGE: String = "hint_range"

## The type prefix every texture uniform shares - `sampler2D`, `sampler2DArray`, `samplerCube`.
## A dial of one of these is a FILE rather than a number, which is what decides the field it edits in.
const SAMPLER_PREFIX: String = "sampler"

## The two words a uniform may be qualified with. A `global uniform` is declared in Project Settings
## and written through RenderingServer rather than through any one material; an `instance uniform`
## is per-node. Kept because a row about one is not a row about the other.
const SCOPE_GLOBAL: String = "global"
const SCOPE_INSTANCE: String = "instance"

## The comment marker a description is written with. Godot's shader language takes C-style comments,
## and the block directly above a uniform is where an author already writes what it is for.
const COMMENT_MARKER: String = "//"

## `path|mtime|size` -> the uniforms of that file. Session-lifetime and shared by every asker, so a
## shader read for the picker is not read again for the lift a keystroke later.
static var _cache: Dictionary = {}

## The declaration matcher, compiled once. Everything after the name is optional, because
## `uniform float speed;` is a complete declaration and the commonest one people write.
static var _declaration: RegEx = null


## Every dial one shader declares, in the order the file writes them. Each entry is
##   {"name", "type", "hints", "default", "about", "scope", "range", "is_color", "sampler"}
## with `hints` the author's own hint text split into its parts, `default` the text after the `=`
## ("" when the file gives none), `about` the `//` block directly above the line, `range` a
## {"from", "to", "step"} for a `hint_range` and {} otherwise, and the last two the two questions
## that decide how a dial is edited. A path that is not a readable `.gdshader` has none.
static func for_shader(shader_path: String) -> Array[Dictionary]:
	var path: String = shader_path.strip_edges()
	if path.is_empty() or path.get_extension().to_lower() != SHADER_EXTENSION:
		return [] as Array[Dictionary]
	var key: String = _cache_key(path)
	if _cache.has(key):
		return _cache[key]
	var parsed: Array[Dictionary] = parse(FileAccess.get_file_as_string(path))
	_cache[key] = parsed
	return parsed


## The dial names one shader declares. The question the picker and the lift's guard ask most, so it
## is one call rather than a walk at every call site.
static func names_of(shader_path: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for uniform: Dictionary in for_shader(shader_path):
		names.append(str(uniform["name"]))
	return names


## One dial by name, or {} when the shader does not declare it. THE question behind every check
## here: a row naming a dial that is not in this list is a row that silently does nothing.
static func find(shader_path: String, dial_name: String) -> Dictionary:
	var wanted: String = dial_name.strip_edges()
	for uniform: Dictionary in for_shader(shader_path):
		if str(uniform["name"]) == wanted:
			return uniform
	return {}


## True when a shader declares this dial - `find` asked as the yes-or-no it usually is.
static func declares(shader_path: String, dial_name: String) -> bool:
	return not find(shader_path, dial_name).is_empty()


## Drops the cache. The editor calls this when the filesystem changes; tests call it between
## fixtures, for the same reason every other by-file reader here exposes one.
static func clear_cache() -> void:
	_cache.clear()


## The uniforms of shader SOURCE TEXT, for a caller that already holds it (and for the tests, which
## have no file to point at). The file entry point above is this with a cache in front of it.
static func parse(source: String) -> Array[Dictionary]:
	var uniforms: Array[Dictionary] = []
	if source.is_empty():
		return uniforms
	if _declaration == null:
		_declaration = RegEx.create_from_string(
			"^(?:(?<scope>global|instance)[ \\t]+)?uniform[ \\t]+(?<type>[A-Za-z_][A-Za-z0-9_]*)"
			+ "[ \\t]+(?<name>[A-Za-z_][A-Za-z0-9_]*)[ \\t]*(?:\\[[^\\]]*\\])?"
			+ "[ \\t]*(?::[ \\t]*(?<hints>[^=;]+?))?[ \\t]*(?:=[ \\t]*(?<default>[^;]+?))?[ \\t]*;")
	var about: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = source.split("\n")
	for index: int in range(lines.size()):
		var line: String = lines[index].strip_edges()
		if line.begins_with(COMMENT_MARKER):
			about.append(line.substr(COMMENT_MARKER.length()).strip_edges())
			continue
		var hit: RegExMatch = _declaration.search(line)
		if hit == null:
			# Only a BLANK line keeps a description alive: a note written two statements above a
			# uniform is about the statement it sits over, not about the dial further down.
			if not line.is_empty():
				about.clear()
			continue
		uniforms.append(_entry(hit, " ".join(about), index + 1))
		about.clear()
	return uniforms


## One matched declaration as the entry a caller reads. The hint text is kept as the author wrote
## it AND split into the two questions a field asks - is this a colour, and does it have ends - so
## nothing downstream has to parse hints a second time.
static func _entry(hit: RegExMatch, about: String, line_number: int) -> Dictionary:
	var type_text: String = hit.get_string("type")
	var hints: PackedStringArray = split_hints(hit.get_string("hints"))
	return {
		"name": hit.get_string("name"),
		"type": type_text,
		"hints": hints,
		"default": hit.get_string("default").strip_edges(),
		"about": about,
		"scope": hit.get_string("scope"),
		"range": range_of(hints),
		"is_color": hints.has(HINT_COLOR),
		"sampler": type_text.begins_with(SAMPLER_PREFIX),
		"line": line_number
	}


## The hint list one declaration carries, split on the commas BETWEEN hints and not on the ones
## inside a hint's own arguments: `hint_range(0.0, 1.0), filter_nearest` is two hints, and splitting
## it naively is three of which two are nonsense.
static func split_hints(hint_text: String) -> PackedStringArray:
	var hints: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var current: String = ""
	for glyph: String in hint_text:
		if glyph == "(":
			depth += 1
		elif glyph == ")":
			depth = maxi(depth - 1, 0)
		if glyph == "," and depth == 0:
			hints.append(current.strip_edges())
			current = ""
			continue
		current += glyph
	if not current.strip_edges().is_empty():
		hints.append(current.strip_edges())
	return hints


## A `hint_range`'s ends as {"from", "to", "step"}, or {} when the dial has no range. The step is
## zero when the shader gives none, which is what Godot itself means by "continuous".
static func range_of(hints: PackedStringArray) -> Dictionary:
	for hint: String in hints:
		if not hint.begins_with(HINT_RANGE + "("):
			continue
		var inside: PackedStringArray = hint.substr(HINT_RANGE.length() + 1).trim_suffix(")").split(",")
		if inside.size() < 2:
			return {}
		return {
			"from": inside[0].strip_edges().to_float(),
			"to": inside[1].strip_edges().to_float(),
			"step": inside[2].strip_edges().to_float() if inside.size() > 2 else 0.0
		}
	return {}


## One dial said in a line - what the picker shows beside its name and what a description falls back
## to when the shader's author wrote none. The type first, because that is what decides whether the
## reader can put their number in it, then the range and the starting value if the file gives them.
static func reading(uniform: Dictionary) -> String:
	var words: PackedStringArray = PackedStringArray([str(uniform.get("type", ""))])
	var ends: Dictionary = uniform.get("range", {})
	if not ends.is_empty():
		words.append("%s..%s" % [_number(float(ends["from"])), _number(float(ends["to"]))])
	var starting: String = str(uniform.get("default", ""))
	if not starting.is_empty():
		words.append("= %s" % starting)
	return " ".join(words)


## A range end as short as it is true: `1` rather than `1.0` for a whole number, so an int dial's
## ends do not read as floats the shader never wrote.
static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, float(int(value))) else str(value)


## The cache identity of one shader file: its path, its saved mtime and its byte length. mtime alone
## has seconds resolution, so two saves inside one second would otherwise serve the older parse.
static func _cache_key(path: String) -> String:
	var length: int = 0
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file != null:
		length = file.get_length()
		file.close()
	return "%s|%d|%d" % [path, FileAccess.get_modified_time(path), length]
