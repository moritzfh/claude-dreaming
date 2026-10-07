## Describes one friend's room in the attic: rooms/<id>/room.tres
## (one room per person – all of your dreams hang in it).
class_name RoomInfo
extends Resource

## your name / handle (shown on the guestbook)
@export var owner := ""
## the room's name, e.g. "Rustys Sternwarte"
@export var title := ""
## the room as pixel art, exactly 216 px high (any width, 240–480 is good)
@export var background: Texture2D
## smaller numbers are closer to Claude's studio
@export var order := 100
## top-left corner of each gold frame (56 x 35) in room pixels; your levels
## (LevelInfo.room = this folder's name) hang there in their order, free
## slots show an empty frame
@export var painting_slots := PackedVector2Array()
## optional: a script that extends DreamRoom – things that move, glow or can
## be used with E
@export_file("*.gd") var room_script := ""
## the light on Claude while she's in this room (white = unchanged)
@export var tint := Color(1, 1, 1)
