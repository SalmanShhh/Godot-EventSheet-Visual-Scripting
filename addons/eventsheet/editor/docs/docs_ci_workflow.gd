# Godot EventSheets - the CI job for the documentation chores, written out as a plain file.
#
# THE FILE IS THEIRS. This writes one YAML file into the project's own .github/workflows folder and
# then has nothing more to do with it: no service, no account, no token, no callback, nothing that
# stops working when this plugin is uninstalled. A reader can open it, read every line, change it,
# or delete it, and the only thing they lose is the file. That is the whole design.
#
# It is SHOWN BEFORE IT IS WRITTEN, because a plugin that quietly adds a file to somebody's
# repository - one that runs on every push, in their name, on their minutes - has done something
# they did not ask for. The dialog puts the exact bytes on screen first.
#
# It is PINNED TO THE ENGINE THIS PROJECT IS OPEN IN. A docs job that silently followed the latest
# Godot would go red one morning for a reason that has nothing to do with the documentation, and the
# person reading the failure has no way to know that. The version is written into the file where it
# can be seen and edited.
#
# The job runs exactly what a person would run: docs-check to gate, docs-export to produce the site,
# and it uploads the site as the run's artifact. It publishes nothing.
@tool
class_name EventSheetDocsCiWorkflow
extends RefCounted

## Where the file goes. The conventional location, because a workflow anywhere else is not a
## workflow - it is a file GitHub ignores.
const WORKFLOW_PATH := "res://.github/workflows/eventsheets-docs.yml"

## The workflow's own name, which is what a reader sees in the checks list beside a pull request.
const WORKFLOW_NAME := "Doctor - Docs"

## Where the engine is downloaded from. The project's own release, from the engine's own releases -
## no third-party action, nothing this plugin hosts, nothing that can be swapped under the reader.
const DOWNLOAD_ROOT := "https://github.com/godotengine/godot/releases/download"


## The engine version the workflow pins, as the releases page spells it ("4.7-stable"). Derived from
## the running engine so the file says what this project is actually built with.
static func version_tag(info: Dictionary = Engine.get_version_info()) -> String:
	var major: int = int(info.get("major", 0))
	var minor: int = int(info.get("minor", 0))
	var patch: int = int(info.get("patch", 0))
	var status: String = str(info.get("status", "stable"))
	var number: String = "%d.%d" % [major, minor] if patch == 0 else "%d.%d.%d" % [major, minor, patch]
	return "%s-%s" % [number, status]


## The zip the workflow downloads for that version.
static func binary_name(tag: String) -> String:
	return "Godot_v%s_linux.x86_64" % tag


## The whole file, byte for byte. Pure over the version tag, so the suite pins every line of it
## without depending on which engine ran the test.
static func workflow_text(tag: String) -> String:
	var binary: String = binary_name(tag)
	var lines: PackedStringArray = PackedStringArray([
		"# %s - the documentation chores, run on every push." % WORKFLOW_NAME,
		"#",
		"# This file is yours. It was written by the EventSheets Housekeeping dialog and is not",
		"# read, updated or needed by the plugin afterwards - edit it, move it or delete it freely.",
		"#",
		"# It runs the same two commands a person runs by hand, and publishes nothing: the exported",
		"# site is attached to the run as an artifact, where somebody has to go and fetch it.",
		"name: %s" % WORKFLOW_NAME,
		"",
		"on:",
		"  push:",
		"  pull_request:",
		"",
		"jobs:",
		"  docs:",
		"    runs-on: ubuntu-latest",
		"    steps:",
		"      - uses: actions/checkout@v4",
		"",
		"      # Pinned to the Godot this project is open in. Change it here when you upgrade.",
		"      - name: Get Godot %s" % tag,
		"        run: |",
		"          curl -sSLo godot.zip %s/%s/%s.zip" % [DOWNLOAD_ROOT, tag, binary],
		"          unzip -q godot.zip",
		"          chmod +x %s" % binary,
		"",
		"      - name: Import the project",
		"        run: ./%s --headless --path . --import" % binary,
		"",
		"      - name: Check the documentation",
		"        run: ./%s --headless --path . --script addons/eventsheet/cli.gd -- docs-check" % binary,
		"",
		"      - name: Export the site",
		"        run: ./%s --headless --path . --script addons/eventsheet/cli.gd -- docs-export --out=eventsheet_docs/site" % binary,
		"",
		"      - uses: actions/upload-artifact@v4",
		"        with:",
		"          name: eventsheets-docs-site",
		"          path: eventsheet_docs/site",
		"",
	])
	return "\n".join(lines)


## Writes the file, making the folders it needs. Answers whether it landed - the caller says where.
static func write(text: String, path: String = WORKFLOW_PATH) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	return true


## Whether this project already carries the file, so the dialog offers to REPLACE rather than to
## write - the difference matters when somebody has edited theirs.
static func exists(path: String = WORKFLOW_PATH) -> bool:
	return FileAccess.file_exists(path)
