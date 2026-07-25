## Test fixture: a RefCounted provider with NO class_name, so its provider id falls back to the file
## name. That id is interpolated into a GDScript identifier (`__eventsheet_provider_<id>.member`), so the
## fallback must pascal-case rather than capitalize - "Nameless Provider Fixture" would emit an identifier
## with spaces. Pinned by expose_all_properties_test.
@tool
extends RefCounted

@export var high_score: int = 0
