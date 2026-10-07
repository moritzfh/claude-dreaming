## Describes one level (one painting in the hub's gallery).
## Every level folder needs a `level.tres` of this type:
##   levels/<your_level>/level.tres
class_name LevelInfo
extends Resource

## shown in the hub when you stand in front of the painting
@export var title := "Untitled dream"
## your name / handle
@export var author := ""
## one or two sentences
@export_multiline var description := ""
## a screenshot of your level (1280x720, no UI) – the attic hangs it as an oil painting
@export var painting: Texture2D
## the scene that is started when Claude steps into the painting
@export_file("*.tscn") var scene := ""
## smaller numbers hang further right (closer to the studio)
@export var order := 100
## the folder name of your room in rooms/ (one room per person) – the
## painting hangs there. Empty: it hangs in the shared corridor.
@export var room := ""
## what Claude says in front of the painting (optional, English like the rest of the game)
@export var claude_lines: PackedStringArray = []
## The camera the painting was taken from (the numbers you passed to
## --lcam=x,y,z:lx,ly,lz). With it, stepping into the painting is seamless:
## the picture turns into the live view and the camera glides to Claude.
## Leave both at zero if you don't have one (the picture then dissolves
## straight into Claude's camera).
@export var painting_cam_pos := Vector3.ZERO
@export var painting_cam_look := Vector3.ZERO
@export var painting_cam_fov := 60.0

func has_painting_cam() -> bool:
	return not painting_cam_pos.is_equal_approx(painting_cam_look)
