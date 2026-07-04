## Test fixture: a RefCounted utility provider with an exported property. Property
## writes must compile through the compiler-declared owned instance (there is no
## scene node to target) - pinned by expose_all_properties_test.
@tool
class_name UtilityProviderFixture
extends RefCounted

@export var streak: int = 0
