## @ace_tags(loot, data)
## @ace_category("Loot")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/loot_loader/icon.svg")
class_name LootTableLoader
extends Node
## The data-driven bridge for the Loot Table pack: attach it to a node, drop a LootTableResource (.tres) onto its slot in the Inspector, and on ready it loads that table into the LootBox autoload. The Scene dock warns until a resource is attached, so you cannot forget it.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("LootTableLoader behavior requires a Node parent.")

# @inspector_required
## Loot Table resource. The .tres holding this table's drops (create one from the LootTableResource class, fill its entries grid, and drop it here).
@export var loot_table: Resource = null

func _ready() -> void:
	if loot_table == null:
		return
	var box: Node = get_node_or_null("/root/LootBox")
	if box != null and box.has_method("load_from_resource"):
		box.call("load_from_resource", loot_table)

# Loot Table Loader: attach to a node and drop a Loot Table resource (.tres) onto it. On ready it loads the table into the LootBox autoload - data-driven drops, authored in the Inspector. The Scene dock warns until you attach a resource.
