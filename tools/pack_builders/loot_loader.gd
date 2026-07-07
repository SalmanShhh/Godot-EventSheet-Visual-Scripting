# Pack builder - loot_loader (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Loot Table Loader: the data-driven bridge for the Loot Table pack. Attach it to a node and drop a
## Loot Table resource (.tres) onto it in the Inspector; on ready it loads that table into the LootBox
## autoload, so you author your drops in the Inspector grid instead of with a string of events. If you
## forget the resource, the node shows a warning in the Scene dock (and a required badge in the
## Inspector) - the "you forgot to attach it" safety net. It reaches the autoload dynamically, so it
## does not hard-depend on LootBox being present at edit time.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "LootTableLoader"
	sheet.addon_category = "Loot"
	sheet.addon_tags = PackedStringArray(["loot", "data"])
	var about: CommentRow = CommentRow.new()
	about.text = "Loot Table Loader: attach to a node and drop a Loot Table resource (.tres) onto it. On ready it loads the table into the LootBox autoload - data-driven drops, authored in the Inspector. The Scene dock warns until you attach a resource."
	sheet.events.append(about)
	# The required-resource slot: adds the exported var + the Inspector/Scene warning when it is empty.
	Lib.require_resource(sheet, "loot_table", "Loot Table resource", "The .tres holding this table's drops (create one from the LootTableResource class, fill its entries grid, and drop it here).")
	# On ready, hand the resource to the LootBox autoload (reached dynamically so there is no edit-time
	# dependency on the autoload being registered).
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "\n".join(PackedStringArray([
		"if loot_table == null:",
		"\treturn",
		"var box: Node = get_node_or_null(\"/root/LootBox\")",
		"if box != null and box.has_method(\"load_from_resource\"):",
		"\tbox.call(\"load_from_resource\", loot_table)"
	]))
	on_ready.actions.append(body)
	sheet.events.append(on_ready)
	return Lib.save_pack(sheet, "res://eventsheet_addons/loot_loader/loot_loader_behavior")
