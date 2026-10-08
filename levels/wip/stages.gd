## The five stages of "Work in Progress", left to right – each one a bit
## less finished than the one before. Every stage is 24 cells wide; cell
## (c, r) is the 1 m square from x = 24 * stage + c, y = r.
##
## Map legend (rows are written top down, the last row is r = 0):
##   #  ground                     .  air
##   S  where Claude stops (the stage's start and respawn point)
##   t  tree   b  bush   f  flowers   n  sign   d  T-pose dummy   E  ERROR
##   A–D  a wireframe object (one box over all its cells, no collision yet)
##   I  an invisible wall (collision, but nothing to see)
##   G  the goal star
extends RefCounted

const W := 24
const N := 5

## inventory: how many pieces the player may place in the stage
const STAGES := [
	{
		"look": "painted",
		"inv": {"block": 2},
		"steps": "grass",
		"map": [
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"..S.n.t..b....f.t...bf..",
			"##########..############",
			"##########..############",
			"##########..############",
		],
	},
	{
		"look": "missing",
		"inv": {"ramp": 3, "block": 2},
		"steps": "stone",
		"map": [
			"........................",
			"........................",
			"........................",
			"........................",
			"........t...............",
			"..S...#####.........t.b.",
			"###########....#########",
			"###########E...#########",
			"########################",
		],
	},
	{
		"look": "proto",
		"inv": {"ramp": 2, "block": 2, "spring": 1},
		"steps": "stone",
		"map": [
			"........................",
			"........................",
			"........................",
			"..........t.............",
			".......#######......t...",
			"..S.d..#######..########",
			"##############..########",
			"##############..########",
			"##############..########",
		],
	},
	{
		"look": "wire",
		"inv": {"col_add": 2, "col_del": 1},
		"steps": "stone",
		"map": [
			"........................",
			"........................",
			"......CCCC..............",
			".............I..........",
			".............I.....D....",
			"..S..........I.....D..t.",
			"#####AAAAAABBBBBB#######",
			"#####AAAAAABBBBBB#######",
			"#####AAAAAABBBBBB#######",
		],
	},
	{
		"look": "sketch",
		"inv": {},
		"steps": "wood",
		"map": [
			"........................",
			"........................",
			"........................",
			"........................",
			"........................",
			"..S.....................",
			"####....................",
			"####.................G..",
			"####...............#####",
		],
	},
]

## what Claude says when she arrives in a stage (and the hint for the player)
const INTRO := [
	[],
	[["Uh-oh. Someone forgot the textures.", 2.0], ["Pink and black. A classic.", 1.8]],
	[["Grey boxes. This is where levels are born.", 2.2], ["\"placeholder_final_v2_FINAL\" … very reassuring.", 2.4]],
	[["Now it's only wires …", 1.8], ["I don't think those have collision yet.", 2.2]],
	[],
]

const HINTS := [
	"",
	"New: ramps.  Q / mouse wheel / 1–4: switch tools.\nClaude turns around at walls by herself.",
	"New: the spring – it throws Claude high into the air.\nThere is more than one solution.",
	"Click a wireframe: add collision.\nWhile paused you can see all collisions – even invisible ones.",
	"",
]

## "You're absolutely right!" – what Claude says after a fall
const FALL_LINES := [
	"You're absolutely right! I should not have walked there.",
	"You're absolutely right! That was a hole.",
	"You're absolutely right! Let me try that again.",
	"You're absolutely right! Gravity works here.",
	"You're absolutely right! Holes are bad. Noted.",
	"You're absolutely right! I'll look before I walk. Somehow.",
]
