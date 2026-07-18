## @ace_tags(cosmetics, data)
## @ace_category("SkinVault")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/skin_catalog_loader/icon.svg")
class_name SkinCatalogLoader
extends Node
## The data-driven bridge for the SkinVault pack: attach to a node, drop a Skin Catalog resource (.tres) onto it in the Inspector, and on ready it loads the whole catalog (rarities and skins) into the SkinVault autoload. The Inspector flags the required slot with a warning until a resource is attached.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("SkinCatalogLoader behavior requires a Node parent.")

# @inspector_required
## Skin Catalog resource. The .tres holding this game's rarities and skins (create one from the SkinCatalogResource class, fill its grids, and drop it here).
@export var catalog: Resource = null

func _ready() -> void:
	if catalog == null:
		return
	var vault: Node = get_node_or_null("/root/SkinVault")
	if vault != null and vault.has_method("load_catalog"):
		vault.call("load_catalog", catalog)

# Skin Catalog Loader: attach to a node and drop a Skin Catalog resource (.tres) onto it. On ready it registers the whole catalog into the SkinVault autoload - data-driven cosmetics, authored in the Inspector. The Inspector warns until you attach a resource.
