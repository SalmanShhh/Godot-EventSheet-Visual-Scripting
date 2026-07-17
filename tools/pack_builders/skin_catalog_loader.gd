# Pack builder - skin_catalog_loader (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Skin Catalog Loader: the data-driven bridge for the SkinVault pack. Attach it to a node and drop a
## Skin Catalog resource (.tres) onto it in the Inspector; on ready it loads that whole catalog (rarities
## + skins) into the SkinVault autoload, so you author your cosmetics in the Inspector grids instead of
## with events. If you forget the resource, the Inspector flags the required slot with a warning. It
## reaches the autoload dynamically, so it does not hard-depend on SkinVault being present at edit time.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "SkinCatalogLoader"
	sheet.class_description = "The data-driven bridge for the SkinVault pack: attach to a node, drop a Skin Catalog resource (.tres) onto it in the Inspector, and on ready it loads the whole catalog (rarities and skins) into the SkinVault autoload. The Inspector flags the required slot with a warning until a resource is attached."
	sheet.addon_category = "SkinVault"
	sheet.addon_tags = PackedStringArray(["cosmetics", "data"])
	var about: CommentRow = CommentRow.new()
	about.text = "Skin Catalog Loader: attach to a node and drop a Skin Catalog resource (.tres) onto it. On ready it registers the whole catalog into the SkinVault autoload - data-driven cosmetics, authored in the Inspector. The Inspector warns until you attach a resource."
	sheet.events.append(about)
	Lib.require_resource(sheet, "catalog", "Skin Catalog resource", "The .tres holding this game's rarities and skins (create one from the SkinCatalogResource class, fill its grids, and drop it here).")
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "\n".join(PackedStringArray([
		"if catalog == null:",
		"\treturn",
		"var vault: Node = get_node_or_null(\"/root/SkinVault\")",
		"if vault != null and vault.has_method(\"load_catalog\"):",
		"\tvault.call(\"load_catalog\", catalog)"
	]))
	on_ready.actions.append(body)
	sheet.events.append(on_ready)
	return Lib.save_pack(sheet, "res://eventsheet_addons/skin_catalog_loader/skin_catalog_loader_behavior")
