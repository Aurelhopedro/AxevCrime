extends CharacterBody3D

## AXEV CRIME — PlayerController
## Handles on-foot movement, keyboard/mouse and touch input hooks.

const WALK_SPEED    : float = 5.0
const RUN_SPEED     : float = 10.0
const JUMP_VELOCITY : float = 4.5
const GRAVITY       : float = 9.8

const MOUSE_SENSITIVITY : float = 0.003
const CAM_PITCH_MIN     : float = -1.0
const CAM_PITCH_MAX     : float = 0.5

var is_in_vehicle        : bool    = false
var touch_move_dir       : Vector2 = Vector2.ZERO
var touch_run            : bool    = false
var touch_jump_requested : bool    = false

@onready var camera_pivot : Node3D = $CameraPivot

func _ready() -> void:
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion \
			and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var motion : InputEventMouseMotion = event as InputEventMouseMotion
		camera_pivot.rotate_y(-motion.relative.x * MOUSE_SENSITIVITY)
		var new_pitch : float = clamp(
			camera_pivot.rotation.x - motion.relative.y * MOUSE_SENSITIVITY,
			CAM_PITCH_MIN, CAM_PITCH_MAX)
		camera_pivot.rotation.x = new_pitch

func _physics_process(delta: float) -> void:
	if is_in_vehicle:
		return

	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_jump()
	move_and_slide()

	touch_jump_requested = false

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _handle_movement(_delta: float) -> void:
	var kb_dir : Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_dir : Vector2 = kb_dir if kb_dir.length_squared() > 0.0 else touch_move_dir
	var is_running : bool = Input.is_action_pressed("run") or touch_run
	var speed : float = RUN_SPEED if is_running else WALK_SPEED

	if input_dir.length_squared() > 0.0:
		var direction : Vector3 = _dir_from_input(input_dir)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

func _handle_jump() -> void:
	var jump_pressed : bool = Input.is_action_just_pressed("jump") or touch_jump_requested
	if jump_pressed and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _dir_from_input(input_dir: Vector2) -> Vector3:
	var basis   : Basis   = camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
	var forward : Vector3 = -basis.z.normalized()
	var right   : Vector3 = basis.x.normalized()
	forward.y = 0.0
	right.y   = 0.0
	return (forward * -input_dir.y + right * input_dir.x).normalized()

func enter_vehicle(_vehicle_node: Node) -> void:
	is_in_vehicle = true

func exit_vehicle() -> void:
	is_in_vehicle = false
