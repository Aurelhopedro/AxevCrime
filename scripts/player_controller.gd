extends CharacterBody3D

## AXEV CRIME — PlayerController
## Handles on-foot movement, keyboard/mouse and touch input hooks.

const WALK_SPEED    : float = 5.0
const RUN_SPEED     : float = 10.0
const JUMP_VELOCITY : float = 4.5
const GRAVITY       : float = 9.8

const MOUSE_SENSITIVITY : float = 0.003
const CAM_PITCH_MIN     : float = -1.0   # radians
const CAM_PITCH_MAX     : float = 0.5    # radians

var is_in_vehicle : bool = false

## Set by TouchController each frame; Vector2 normalised [-1,1].
var touch_move_dir  : Vector2 = Vector2.ZERO
## Set by TouchController; true while run button held.
var touch_run       : bool    = false
## Set by TouchController; true for one frame when jump button pressed.
var touch_jump_requested : bool = false

@onready var camera_pivot : Node3D = $CameraPivot

func _ready() -> void:
	# Capture mouse only on desktop — not on web or mobile
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion \
			and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		var current_pitch := camera_pivot.rotation.x
		var new_pitch := clamp(
			current_pitch - event.relative.y * MOUSE_SENSITIVITY,
			CAM_PITCH_MIN, CAM_PITCH_MAX)
		camera_pivot.rotation.x = new_pitch

func _physics_process(delta: float) -> void:
	if is_in_vehicle:
		return

	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_jump()
	move_and_slide()

	# Reset one-shot touch flag after consuming it
	touch_jump_requested = false

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _handle_movement(delta: float) -> void:
	var direction := _get_input_direction()
	var is_running := Input.is_action_pressed("run") or touch_run
	var speed      := RUN_SPEED if is_running else WALK_SPEED

	if direction.length_squared() > 0.0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

func _handle_jump() -> void:
	var jump_pressed := Input.is_action_just_pressed("jump") or touch_jump_requested
	if jump_pressed and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _get_input_direction() -> Vector3:
	# Keyboard input
	var kb_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Combine keyboard and touch — touch only active when no keyboard input
	var input_dir : Vector2
	if kb_dir.length_squared() > 0.0:
		input_dir = kb_dir
	else:
		input_dir = touch_move_dir

	if input_dir.length_squared() == 0.0:
		return Vector3.ZERO

	var basis   := camera_pivot.global_transform.basis if camera_pivot else global_transform.basis
	var forward := -basis.z.normalized()
	var right   := basis.x.normalized()
	forward.y = 0.0
	right.y   = 0.0
	return (forward * -input_dir.y + right * input_dir.x).normalized()

## Called when player enters a vehicle trigger zone.
func enter_vehicle(_vehicle_node: Node) -> void:
	is_in_vehicle = true

## Called when player exits a vehicle.
func exit_vehicle() -> void:
	is_in_vehicle = false
