# Godot EventSheets - the links that open this project's issue forms in the reader's browser.
#
# THE ONE ADDRESS: the repository every link in the plugin starts from. The sheet editor's Report an Issue,
# the Welcome window, the Manual's foot and the Manual's "ask for a page" row all build their address here,
# and the public API's repository constant reads it too, so there is exactly one place to change.
#
# WHAT TRAVELS: only what the caller passes in, as values of named form fields. For the bug form that is
# the plugin version, the Godot version and the platform, and nothing else - no project name, no paths, no
# user name, nothing from a sheet. A link only OPENS a page: the reader sees every field in their browser
# and presses the button themselves, so nothing is ever submitted from here.
#
# THE FORMS are the YAML files under .github/ISSUE_TEMPLATE. The names below and the field ids are a
# contract with those files (a test reads both): a link that names a field the form does not have fills
# nothing, and a renamed form file opens the plain chooser instead of the form.
#
# DELIBERATELY NO `class_name`: reach it with a const preload.
@tool
extends RefCounted

const REPO_URL: String = "https://github.com/SalmanShhh/Godot-EventSheet-Visual-Scripting"
const NEW_ISSUE_URL: String = REPO_URL + "/issues/new"

## The form files, by the name GitHub's `template` query value takes.
const BUG_FORM: String = "bug_report.yml"
const FEATURE_FORM: String = "feature_request.yml"
const DOCS_FORM: String = "documentation.yml"

## The field ids a link fills. Each must exist in the form it is sent to.
const BUG_FIELD_PLUGIN_VERSION: String = "plugin_version"
const BUG_FIELD_GODOT_VERSION: String = "godot_version"
const BUG_FIELD_PLATFORM: String = "platform"
const DOCS_FIELD_PAGE: String = "page"

## What opens an address. Empty means the operating system's own browser hand-off; a test sets it to read
## what would have been opened. The ONE place the plugin hands an issue address to the system.
static var opener: Callable = Callable()


## An address for one form: `template` first, then `title` when given, then each field in the order
## passed, every value URI-encoded. Pure, so a test pins the exact text that travels.
static func form_url(form_file: String, fields: Array = [], title: String = "") -> String:
	var parts: PackedStringArray = PackedStringArray(["template=%s" % form_file.uri_encode()])
	if not title.strip_edges().is_empty():
		parts.append("title=%s" % title.strip_edges().uri_encode())
	for field: Variant in fields:
		var pair: Array = field as Array
		if str(pair[1]).strip_edges().is_empty():
			continue
		parts.append("%s=%s" % [str(pair[0]).uri_encode(), str(pair[1]).strip_edges().uri_encode()])
	return "%s?%s" % [NEW_ISSUE_URL, "&".join(parts)]


## The bug form with the three environment facts filled in. Exactly these three.
static func bug_url(plugin_version: String, godot_version: String, platform: String) -> String:
	return form_url(BUG_FORM, [
		[BUG_FIELD_PLUGIN_VERSION, plugin_version],
		[BUG_FIELD_GODOT_VERSION, godot_version],
		[BUG_FIELD_PLATFORM, platform]])


## The documentation form with a page named: in the title and in the page field.
static func docs_url(page_name: String, title: String = "") -> String:
	var named: String = page_name.strip_edges()
	return form_url(DOCS_FORM, [[DOCS_FIELD_PAGE, named]], title if not title.is_empty() else "Manual: %s" % named)


## True for an address this file built: one of the repository's new-issue forms.
static func is_report_address(url: String) -> bool:
	return url.begins_with(NEW_ISSUE_URL + "?")


## The status line for a link the Manual opened in the browser: a report form is called that, any other
## address by its file name.
static func opened_line(url: String) -> String:
	if is_report_address(url):
		return EventSheetL10n.translate("Opened the issue form in your browser. Nothing is sent until you press Submit there.")
	return EventSheetL10n.translate("Opened %s in your browser.") % url.get_file()


## Hands an address to the system's browser (or to `opener` when a test set one).
static func open(url: String) -> void:
	if opener.is_valid():
		opener.call(url)
	else:
		OS.shell_open(url)
