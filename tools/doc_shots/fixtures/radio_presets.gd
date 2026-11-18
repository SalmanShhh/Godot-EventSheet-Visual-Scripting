extends Node


class Radio:
	signal tuned(to: float)
	var band: int = 0

	class Preset:
		pass


var radio: Radio = Radio.new()
