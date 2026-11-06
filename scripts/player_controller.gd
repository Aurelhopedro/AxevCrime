extends CharacterBody3D

## AXEV CRIME — PlayerController
## Handles on-foot movement and prepares hooks for vehicle mode.

const WALK_SPEED    : float = 5.0
const RUN_SPEED     : float = 10.0
const JUMP_VELOCITY : float = 4.5
const GRAVITY       : float = 9.8

var is_in_vehicle   : bool  = false

@onready var camera_pivot : Node3D   = $CameraPivot
@onready var mesh          : Node3D   = $Mesh

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if is_in_vehicle:
		return  # vehicle logic handled separately

	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_jump()
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _handle_movement(delta: float) -> void:
	var direction := _get_input_direction()
	var speed     := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _get_input_direction() -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis     := camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
	var forward   := -basis.z.normalized()
	var right     := basis.x.normalized()
	forward.y = 0.0
	right.y   = 0.0
	return (forward * -input_dir.y + right * input_dir.x).normalized()

## Called when player enters a vehicle trigger zone.
func enter_vehicle(_vehicle_node: Node) -> void:
	is_in_vehicle = true

## Called when player exits a vehicle.
func exit_vehicle() -> void:
	is_in_vehicle = false
