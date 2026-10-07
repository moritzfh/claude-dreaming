## Spherical gravity for little planets: inside field_radius, "down" points to
## this node's position. Where fields overlap, the planet whose surface is
## closest wins. Put one at the centre of every planetoid.
class_name GravityField
extends Node3D

## radius of the planet's surface
@export var radius := 8.0
## how far out the pull reaches (from the centre)
@export var field_radius := 18.0
@export var enabled := true

func _ready() -> void:
	add_to_group("gravity_fields")
