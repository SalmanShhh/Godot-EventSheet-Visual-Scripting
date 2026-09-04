@tool
class_name EventSheetModTemplateTool
extends RefCounted

# Export Mod Template: the starter folder a game hands its modders, written to disk.
#
# A game that supports mods has to answer one question before anybody can make one - what does a mod
# look like? Every project answers it in a README nobody can find, so this writes the answer as the
# thing itself: a folder with a filled-in manifest in it, a content folder, and a page saying what
# the two tiers mean. A modder copies it, renames it, and has a mod.
#
# It touches no editor at all, which is why it is a file of static functions with a dialog in front
# of it: the words it writes are pinned by a test rather than only ever read off a screenshot.
#
# WHAT IT WILL NOT DO. It writes nothing over an existing file, because the folder it is pointed at
# may already be somebody's mod. A folder that already holds a manifest comes back as a problem with
# that sentence in it, and nothing is written at all.

## The pack that carries the resource spelling of a manifest. A project that has not installed it
## still gets the JSON spelling, and the receipt says why the other one is missing rather than
## writing a .tres of nothing.
const MANIFEST_SCRIPT := "res://eventsheet_addons/mod_manifest_resource/mod_manifest.gd"

## The subfolder the template suggests for a mod's data assets. It is a suggestion, not a rule: the
## Mods pack's "every mod's <name> folder" expression takes whatever word a game uses.
const DEFAULT_CONTENT_FOLDER := "items"


## Writes the template and hands back a receipt: `folder`, the `written` paths in the order they
## were written, and `problem` (empty when there is none). Nothing is written when there is a
## problem, so a half-made template is never left behind.
static func export_template(folder: String, declared: Dictionary, content_folder: String = DEFAULT_CONTENT_FOLDER,
		also_resource: bool = true) -> Dictionary:
	var receipt: Dictionary = {"folder": folder, "written": PackedStringArray(), "problem": ""}
	if folder.strip_edges().is_empty():
		receipt["problem"] = "Give the template a folder to be written into."
		return receipt
	for taken: String in ["mod.json", "mod.tres", "mod.res"]:
		if FileAccess.file_exists(folder.path_join(taken)):
			receipt["problem"] = "%s already holds a %s, so nothing was written - a folder that is already a mod is somebody's work." % [folder, taken]
			return receipt
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		receipt["problem"] = "Could not make the folder %s." % folder
		return receipt
	var written: PackedStringArray = PackedStringArray()
	if not _write(folder.path_join("mod.json"), manifest_json(declared)):
		receipt["problem"] = "Could not write the manifest into %s." % folder
		return receipt
	written.append(folder.path_join("mod.json"))
	if not _write(folder.path_join("README.txt"), readme_text(declared, content_folder)):
		receipt["problem"] = "Could not write the README into %s." % folder
		return receipt
	written.append(folder.path_join("README.txt"))
	if not content_folder.strip_edges().is_empty():
		DirAccess.make_dir_recursive_absolute(folder.path_join(content_folder.strip_edges()))
	if also_resource:
		var saved: String = _save_manifest_resource(folder, declared)
		if saved.is_empty():
			receipt["problem"] = "The mod.json was written. The mod.tres was not: this project has no ModManifest, which the Mods pack ships."
		else:
			written.append(saved)
	receipt["written"] = written
	return receipt


## The five fields as the JSON a modder outside Godot edits. Written here rather than through the
## ModManifest class so a project that has not installed the pack still gets a correct manifest.
static func manifest_json(declared: Dictionary) -> String:
	return JSON.stringify({
		"name": str(declared.get("name", "")),
		"version": str(declared.get("version", "1.0")),
		"author": str(declared.get("author", "")),
		"replaces": str(declared.get("replaces", "")),
		"scripts": bool(declared.get("scripts", false)),
	}, "\t") + "\n"


## The page beside the manifest: what the folder is, what each field means, and - said plainly, once,
## where a modder will read it - what the two tiers cost the player whose machine runs the mod.
static func readme_text(declared: Dictionary, content_folder: String = DEFAULT_CONTENT_FOLDER) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s" % str(declared.get("name", "A mod")))
	lines.append("")
	lines.append("This folder is a mod. Copy it, rename it, edit mod.json, and put it in the game's")
	lines.append("mods folder. The game loads every mod it finds there, in its own load order.")
	lines.append("")
	lines.append("mod.json says what this mod is:")
	lines.append("")
	lines.append("  name      what the game's mod list calls it. Blank means the folder's own name.")
	lines.append("  version   your own version, in your own spelling.")
	lines.append("  author    the credit line beside the name.")
	lines.append("  replaces  what this mod replaces, in your words. Nothing reads it: it is the")
	lines.append("            sentence a player reads before switching two mods on together.")
	lines.append("  scripts   true when the mod carries code. See below.")
	lines.append("")
	if not content_folder.strip_edges().is_empty():
		lines.append("Put content in %s/. The game reads a mod's folders the same way it reads its own." % content_folder.strip_edges())
		lines.append("")
	lines.append("TWO KINDS OF MOD")
	lines.append("")
	lines.append("A DATA mod carries resources, scenes, textures and sounds, and no code. The game")
	lines.append("checks that for itself: it reads what is actually in the mod, and refuses one that")
	lines.append("carries a script even if mod.json says it does not.")
	lines.append("")
	lines.append("A SCRIPT mod carries code, and loads only where the game has asked for it. Code in a")
	lines.append("mod runs with everything the game itself can reach: the player's files, their")
	lines.append("network, their machine. Godot has no sandbox to put it in, so nobody here is")
	lines.append("promising one. Say so on the page you publish the mod from, and the player can")
	lines.append("decide whether to trust you.")
	return "\n".join(lines) + "\n"


## The receipt as one sentence, the way the status bar says it. Pure and static, so the words are a
## test's business rather than a screenshot's.
static func receipt_words(receipt: Dictionary) -> String:
	var problem: String = str(receipt.get("problem", ""))
	var written: PackedStringArray = receipt.get("written", PackedStringArray())
	if not problem.is_empty() and written.is_empty():
		return problem
	var words: String = "Wrote a mod template into %s (%s)." % [str(receipt.get("folder", "")),
		", ".join(_file_names(written))]
	if not problem.is_empty():
		words += " %s" % problem
	return words


## Saves the resource spelling of the manifest beside the JSON one, or "" when this project has no
## ModManifest to save.
static func _save_manifest_resource(folder: String, declared: Dictionary) -> String:
	if not ResourceLoader.exists(MANIFEST_SCRIPT):
		return ""
	var manifest_script: Script = load(MANIFEST_SCRIPT)
	if manifest_script == null:
		return ""
	var manifest: Resource = manifest_script.new()
	manifest.set("mod_name", str(declared.get("name", "")))
	manifest.set("version", str(declared.get("version", "1.0")))
	manifest.set("author", str(declared.get("author", "")))
	manifest.set("replaces", str(declared.get("replaces", "")))
	manifest.set("scripts", bool(declared.get("scripts", false)))
	var path: String = folder.path_join("mod.tres")
	if ResourceSaver.save(manifest, path) != OK:
		return ""
	return path


static func _file_names(paths: PackedStringArray) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for path: String in paths:
		names.append(path.get_file())
	return names


static func _write(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true
