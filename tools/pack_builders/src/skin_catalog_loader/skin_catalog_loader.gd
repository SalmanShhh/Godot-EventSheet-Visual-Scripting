# Pack source - skin_catalog_loader. The behaviour code this pack ships, as real GDScript: highlighted,
# checked and breakpointable here, and assembled into the pack by Lib.pack_from_source.
# Every #region, and the body of every top-level func, is one piece of the sheet; everything
# else is scaffolding the pack declares for itself at build time and never reads from here.
extends Node

var host: Node = null

var catalog

func _ready() -> void:
	if catalog == null:
		return
	var vault: Node = get_node_or_null("/root/SkinVault")
	if vault != null and vault.has_method("load_catalog"):
		vault.call("load_catalog", catalog)
