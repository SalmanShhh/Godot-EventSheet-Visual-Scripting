# EventForge - export the whole Manual as a folder of static HTML (dev tool).
#
#   godot --headless --path . --script tools/export_docs_site.gd
#   godot --headless --path . --script tools/export_docs_site.gd -- --out=res://site --locale=fr
#
# THE LAW THIS TOOL EXISTS UNDER: the same bundle in produces the same bytes out. Export twice and
# hash the two folders; they are identical. Nothing here writes a timestamp, a machine name or a
# path out of anybody's home directory, and every walk it makes is sorted. tests/doc_site_test.gd is
# where that promise is kept honest.
#
# The work is not done here - it is EventSheetDocSiteExport, the same code the Housekeeping dialog
# and the command line call, because three exporters would produce three sites. This file is the
# convenience wrapper you run while editing the exporter.
#
# FIGURES: a fence the editor draws as rows becomes a picture, cached by the hash of the fence body,
# and a figure with no picture yet is exported as the code it is a picture of. Drawing needs a
# window, so it is a separate non-headless pass: tools/render_docs_figures.gd. Run that once, then
# this again, and the code cards become pictures.
@tool
extends SceneTree


func _init() -> void:
	var options: Dictionary = {}
	var out_dir: String = "res://eventsheet_docs/site"
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		var body: String = argument.substr(2)
		var separator: int = body.find("=")
		var key: String = body if separator < 0 else body.substr(0, separator)
		var value: String = "" if separator < 0 else body.substr(separator + 1)
		match key:
			"out":
				out_dir = value
			"locale":
				options["locale"] = value
			"engine":
				options["engine"] = true
	var report: Dictionary = EventSheetDocSiteExport.export_site(out_dir, options)
	if not str(report.get("error", "")).is_empty():
		print("site: %s" % str(report["error"]))
		quit(1)
		return
	print("site: pages=%d figures=%d undrawn=%d files=%d -> %s" % [
		int(report.get("pages", 0)), int(report.get("figures", 0)), int(report.get("undrawn", 0)),
		(report.get("files", PackedStringArray()) as PackedStringArray).size(), out_dir])
	if int(report.get("undrawn", 0)) > 0:
		print("site: run tools/render_docs_figures.gd NON-headless to draw the rest, then export again.")
	quit(0)
