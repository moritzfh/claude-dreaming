## The smallest possible room script: one glow, one thing to look at.
## (Optional – delete room_script from room.tres if your room needs none.)
extends DreamRoom

var _glow: Sprite2D

func build() -> void:
	_glow = add_glow(Vector2(128, 60), 22, Color(1.0, 0.85, 0.5, 0.35))
	add_object("wall", Vector2(60, 170), "Wand", ["A fresh room.", "What will I put here?"])

func _process(delta: float) -> void:
	t += delta
	_glow.modulate.a = 0.3 + 0.08 * sin(t * 2.0)
