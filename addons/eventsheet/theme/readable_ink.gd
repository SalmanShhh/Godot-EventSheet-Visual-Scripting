# Godot EventSheets - moves a colour just far enough that its words read on the grounds they sit on.
#
# DELIBERATELY NO `class_name`: callers load it by path at the moment they need it, so the first open
# of the workspace does not compile it. One formula is used everywhere (the theme deriver's, which
# linearises the channels first), so what a test measures is what this moves to.
@tool
extends RefCounted

## The least contrast ordinary text keeps against its ground.
const TEXT_CONTRAST: float = 4.5
## How far toward black or white each step goes. Small, so the colour stops the moment it reads and
## keeps its hue (amber stays amber, a quiet grey stays quiet).
const STEP: float = 0.02
const MAX_STEPS: int = 80


## `ink` moved toward black or white (whichever the grounds ask for) until it reads at `minimum` on
## every one of `grounds`. Alpha is kept. An ink that already reads is returned as it is.
static func move(ink: Color, grounds: Array, minimum: float = TEXT_CONTRAST) -> Color:
	var opaque: Array[Color] = []
	for ground: Variant in grounds:
		if (ground as Color).a > 0.0:
			opaque.append(Color(ground as Color, 1.0))
	if opaque.is_empty():
		return ink
	var result: Color = Color(ink, 1.0)
	if _reads(result, opaque, minimum):
		return ink
	var target: Color = Color.BLACK if _worst(Color.BLACK, opaque) >= _worst(Color.WHITE, opaque) else Color.WHITE
	for step: int in MAX_STEPS:
		result = result.lerp(target, STEP)
		if _reads(result, opaque, minimum):
			break
	return Color(result, ink.a)


## The contrast of `ink` against its worst ground.
static func worst_contrast(ink: Color, grounds: Array) -> float:
	var opaque: Array[Color] = []
	for ground: Variant in grounds:
		opaque.append(Color(ground as Color, 1.0))
	return _worst(Color(ink, 1.0), opaque)


static func _reads(ink: Color, grounds: Array[Color], minimum: float) -> bool:
	return _worst(ink, grounds) >= minimum


static func _worst(ink: Color, grounds: Array[Color]) -> float:
	var worst: float = 1000.0
	for ground: Color in grounds:
		worst = minf(worst, EventSheetEditorThemeDeriver.contrast_ratio(ink, ground))
	return worst
