class_name ScriptRowsStaticOnly
extends RefCounted
## Helpers that never need an instance.


static func clamp_score(value: int) -> int:
	return clampi(value, 0, 999)


static func reset_all() -> void:
	pass
