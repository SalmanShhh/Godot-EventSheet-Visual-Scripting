@tool
class_name Batch12VocabularyModuleFixture
extends RefCounted


static func register(registry: Variant) -> void:
	registry.add_condition("Core/IsPinned", {"name": "Is Pinned", "category": "Pin", "codegen_template": "{target.}is_pinned()", "params": [{"id": "target", "type": "Node"}]})
	registry.add_action("Core/PinTo", {"name": "Pin To", "category": "Pin", "codegen_template": "{target.}pin_to({anchor})", "params": [{"id": "anchor", "type": "Node"}]})


static func walk(depth: int) -> void:
	if depth > 3:
		return
	walk(depth + 1)
