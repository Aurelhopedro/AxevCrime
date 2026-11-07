extends Node3D

## AXEV CRIME — Main Scene
## Entry point for the game world. Spawns player and sets up environment.

const PlayerScene := preload("res://scenes/player.tscn")

func _ready() -> void:
	_spawn_player()

func _spawn_player() -> void:
	var spawn : Node3D = get_node_or_null("SpawnPoint")
	if spawn == null:
		push_error("SpawnPoint node not found in Main scene.")
		return

	var player : CharacterBody3D = PlayerScene.instantiate()
	add_child(player)
	player.global_position = spawn.global_position
