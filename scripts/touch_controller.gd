extends CanvasLayer

## AXEV CRIME — TouchController
## Manages virtual joystick, camera drag zone and action buttons.
## Writes directly to PlayerController's touch input variables —
## physics logic stays exclusively in player_controller.gd.

# ── Configuration ────────────────────────────────────────────────
const JOYSTICK_RADIUS   : float = 80.0   # px — maximum stick travel
const JOYSTICK_DEADZONE : float = 10.0   # px — ignore micro-movements
const CAM_SENSITIVITY_H : float = 0.004  # radians per pixel, horizontal
const CAM_SENSITIVITY_V : float = 0.003  # radians per pixel, vertical
const CAM_PITCH_MIN     : float = -1.0   # radians
const CAM_PITCH_MAX     : float = 0.5    # radians

# ── References set in _ready ──────────────────────────────────────
var _player    : CharacterBody3D = null
var _cam_pivot : Node3D          = null

# ── UI nodes ─────────────────────────────────────────────────────
@onready var _joystick_base  : Control = $JoystickBase
@onready var _joystick_thumb : Control = $JoystickBase/Thumb
@onready var _cam_zone       : Control = $CameraZone
@onready var _btn_jump       : Button  = $Buttons/BtnJump
@onready var _btn_run        : Button  = $Buttons/BtnRun
@onready var _btn_interact   : Button  = $Buttons/BtnInteract

# ── Touch state ───────────────────────────────────────────────────
var _joy_touch_index : int     = -1
var _cam_touch_index : int     = -1
var _joy_origin      : Vector2 = Vector2.ZERO
var _cam_last_pos    : Vector2 = Vector2.ZERO

func _ready() -> void:
	# Player is grandparent: CanvasLayer → Player (CharacterBody3D)
	var parent := get_parent()
	if parent is CharacterBody3D:
		_player    = parent as CharacterBody3D
		_cam_pivot = _player.get_node_or_null("CameraPivot")

	_btn_jump.button_down.connect(_on_jump_pressed)
	_btn_jump.button_up.connect(_on_jump_released)
	_btn_run.button_down.connect(_on_run_pressed)
	_btn_run.button_up.connect(_on_run_released)
	_btn_interact.pressed.connect(_on_interact_pressed)

	_joystick_base.gui_input.connect(_on_joy_gui_input)
	_cam_zone.gui_input.connect(_on_cam_gui_input)

# ── Button callbacks ──────────────────────────────────────────────

func _on_jump_pressed() -> void:
	if _player:
		_player.touch_jump_requested = true

func _on_jump_released() -> void:
	pass  # one-shot reset handled in player_controller._physics_process

func _on_run_pressed() -> void:
	if _player:
		_player.touch_run = true

func _on_run_released() -> void:
	if _player:
		_player.touch_run = false

func _on_interact_pressed() -> void:
	print("[TouchController] Interact: not yet available.")

# ── Joystick ─────────────────────────────────────────────────────

func _on_joy_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _joy_touch_index == -1:
			_joy_touch_index = event.index
			# Reposition base so its centre is under the finger
			var base_half := _joystick_base.size * 0.5
			_joy_origin = event.position
			_joystick_base.set_position(_joy_origin - base_half)
		elif not event.pressed and event.index == _joy_touch_index:
			_joy_touch_index = -1
			_joy_origin      = Vector2.ZERO
			# Return thumb to base centre
			_joystick_thumb.set_position(
				_joystick_base.size * 0.5 - _joystick_thumb.size * 0.5)
			if _player:
				_player.touch_move_dir = Vector2.ZERO

	elif event is InputEventScreenDrag and event.index == _joy_touch_index:
		var delta := event.position - _joy_origin
		if delta.length() < JOYSTICK_DEADZONE:
			delta = Vector2.ZERO

		var clamped := delta.limit_length(JOYSTICK_RADIUS)
		_joystick_thumb.set_position(
			_joystick_base.size * 0.5 + clamped - _joystick_thumb.size * 0.5)

		if _player:
			_player.touch_move_dir = \
				clamped / JOYSTICK_RADIUS if clamped.length() > 0.0 else Vector2.ZERO

# ── Camera zone ───────────────────────────────────────────────────

func _on_cam_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _cam_touch_index == -1:
			_cam_touch_index = event.index
			_cam_last_pos    = event.position
		elif not event.pressed and event.index == _cam_touch_index:
			_cam_touch_index = -1

	elif event is InputEventScreenDrag and event.index == _cam_touch_index:
		if _cam_pivot == null:
			return
		var delta := event.position - _cam_last_pos
		_cam_last_pos = event.position

		_cam_pivot.rotate_y(-delta.x * CAM_SENSITIVITY_H)
		var new_pitch := clamp(
			_cam_pivot.rotation.x - delta.y * CAM_SENSITIVITY_V,
			CAM_PITCH_MIN, CAM_PITCH_MAX)
		_cam_pivot.rotation.x = new_pitch
