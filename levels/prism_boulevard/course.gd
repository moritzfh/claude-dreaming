## Prism Boulevard – the course layout (see track.gd for the commands).
## yaw + = left · pitch + = up · bank + = right side up (banked for a left turn)
extends RefCounted

static func commands() -> Array:
	return [
		{"name": "start", "len": 120, "w": 18, "bits": [[0.55, -4, 4], [0.55, 4, 4]]},
		# --- cloud dive: a fast descending S through the clouds
		{"name": "dive1", "len": 95, "yaw": -55, "pitch": -9, "bank": -14, "pads": [[0.55, 2.5]]},
		{"name": "dive2", "len": 115, "yaw": 80, "bank": 16, "bits": [[0.35, -3, 5]]},
		{"name": "dive3", "len": 70, "yaw": -25, "pitch": 9, "bank": 0, "pads": [[0.7, -3]]},
		# --- star hills: two crests, each a little jump (E in the air = trick)
		{"name": "hill1", "len": 34, "pitch": 9},
		{"name": "hill2", "len": 30, "pitch": -18, "kick": {"at": 0.5, "power": 10.0}},
		{"name": "hill3", "len": 30, "pitch": 18},
		{"name": "hill4", "len": 30, "pitch": -18, "kick": {"at": 0.5, "power": 11.0}, "bits": [[0.9, 0, 3]]},
		{"name": "hill5", "len": 34, "pitch": 9},
		{"name": "pre_spiral", "len": 40},
		# --- the planet spiral: three quarters around a little planet, climbing,
		# and out over the hills on a bridge
		{"name": "spiral_in", "len": 40, "yaw": 30, "pitch": 5, "bank": 14, "w": 20},
		{"name": "spiral", "len": 250, "yaw": 210, "bank": 24, "ease": 35,
			"pads": [[0.3, 4.0], [0.66, 4.0]], "bits": [[0.45, -5, 6], [0.82, 3, 5]]},
		{"name": "spiral_out", "len": 40, "yaw": 30, "pitch": -5, "bank": 0, "w": 18},
		# --- corkscrew: one full barrel roll through floating crystals
		{"name": "screw_in", "len": 45},
		{"name": "corkscrew", "len": 160, "bank": 360, "ease": 0, "w": 16, "bits": [[0.25, 0, 4], [0.7, 0, 4]]},
		{"name": "screw_out", "len": 35, "w": 18},
		# --- warp gate → hyperspace
		{"name": "warp_in", "len": 45, "pads": [[0.6, 0.0]]},
		{"name": "hyper1", "len": 110, "yaw": -25, "pitch": -4, "hyper": true, "ease": 40},
		{"name": "hyper2", "len": 110, "yaw": 25, "pitch": 4, "hyper": true, "ease": 40},
		{"name": "warp_out", "len": 30},
		# --- the starlight river: a wide, wavy sweep to the right
		{"name": "river1", "len": 160, "yaw": -110, "bank": -10, "w": 24, "surf": "river",
			"bits": [[0.3, -6, 5], [0.7, 6, 5]]},
		{"name": "river2", "len": 70, "yaw": 20, "bank": 4, "surf": "river", "pads": [[0.6, 0]]},
		{"name": "river_out", "len": 40, "bank": 0, "w": 18},
		# --- the glider jump: off the ramp, through the star rings, land below
		{"name": "ramp", "len": 60, "pitch": 16, "pads": [[0.6, 0]], "kick": {"at": 1.0, "power": 9.0, "glide": true}},
		{"name": "glide", "len": 175, "pitch": -32, "surf": "gap", "rails": "none",
			"rings": [[0.18, 0, 6.5], [0.4, 4, 10.0], [0.62, -3, 11.0], [0.84, 0, 7.5]]},
		{"name": "landing", "len": 55, "pitch": 16, "w": 22},
		# --- the loop
		{"name": "loop_in", "len": 60, "w": 16, "pads": [[0.7, 0]]},
		{"name": "loop", "len": 150, "pitch": 360, "yaw_local": true, "shift": 22, "ease": 30},
		{"name": "loop_out", "len": 50, "w": 18},
		# --- comet run: a banked right-hander and a long, wavy run home
		{"name": "turn_sw", "len": 120, "yaw": -90, "bank": -14},
		{"name": "comet1", "len": 140, "yaw": 30, "pitch": 5, "bank": 8, "pads": [[0.5, 0]]},
		{"name": "comet2", "len": 150, "yaw": -30, "bank": -8, "bits": [[0.5, 0, 6]]},
		{"name": "comet3", "len": 110, "pitch": -5, "bank": 0},
		{"name": "final_turn", "len": 115, "yaw": -90, "bank": -14, "pads": [[0.8, -3]]},
		{"name": "home", "len": 30, "bank": 0},
	]
