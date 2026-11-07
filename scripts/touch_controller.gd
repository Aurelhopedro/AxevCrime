extends CanvasLayer

## AXEV CRIME — TouchController
## Manages virtual joystick, camera drag zone and action buttons.
## Writes directly to PlayerController's touch input variables —
## physics logic stays exclusively in player_controller.gd.
##
## CORRECÇÕES APLICADAS:
## - Referência ao player obtida via get_parent() após instanciação correcta
## - Joystick reposicionado com coordenadas locais do CanvasLayer
## - mouse_filter corrigido para STOP em JoystickBase e CameraZone
## - Câmara usa drag.relative para evitar saltos no primeiro toque
## - _cam_pivot obtido de forma robusta após _ready()

const JOYSTICK_RADIUS   : float = 80.0
const JOYSTICK_DEADZONE : float = 10.0
const CAM_SENSITIVITY_H : float = 0.004
const CAM_SENSITIVITY_V : float = 0.003
const CAM_PITCH_MIN     : float = -1.0
const CAM_PITCH_MAX     : float = 0.5

var _player    : CharacterBody3D = null
var _cam_pivot : Node3D          = null

@onready var _joystick_base  : Control = $JoystickBase
@onready var _joystick_thumb : Control = $JoystickBase/Thumb
@onready var _cam_zone       : Control = $CameraZone
@onready var _btn_jump       : Button  = $Buttons/BtnJump
@onready var _btn_run        : Button  = $Buttons/BtnRun
@onready var _btn_interact   : Button  = $Buttons/BtnInteract

var _joy_touch_index : int     = -1
var _cam_touch_index : int     = -1
var _joy_origin      : Vector2 = Vector2.ZERO
# _joy_base_origin guarda a posição original do JoystickBase para repor após soltar
var _joy_base_origin : Vector2 = Vector2.ZERO

func _ready() -> void:
	# Obter referência ao player (parent do CanvasLayer quando instanciado em player.tscn)
	var parent : Node = get_parent()
	if parent is CharacterBody3D:
		_player    = parent as CharacterBody3D
		_cam_pivot = _player.get_node_or_null("CameraPivot") as Node3D
	else:
		push_warning("[TouchController] Parent não é CharacterBody3D: %s" % str(parent))

	# Guardar posição original do joystick para repor ao soltar
	_joy_base_origin = _joystick_base.position

	# Ligar botões
	_btn_jump.button_down.connect(_on_jump_pressed)
	_btn_jump.button_up.connect(_on_jump_released)
	_btn_run.button_down.connect(_on_run_pressed)
	_btn_run.button_up.connect(_on_run_released)
	_btn_interact.pressed.connect(_on_interact_pressed)

	# Ligar joystick e zona de câmara
	_joystick_base.gui_input.connect(_on_joy_gui_input)
	_cam_zone.gui_input.connect(_on_cam_gui_input)

# ── BOTÕES ──────────────────────────────────────────────────────────

func _on_jump_pressed() -> void:
	if _player:
		_player.touch_jump_requested = true

func _on_jump_released() -> void:
	pass

func _on_run_pressed() -> void:
	if _player:
		_player.touch_run = true

func _on_run_released() -> void:
	if _player:
		_player.touch_run = false

func _on_interact_pressed() -> void:
	print("[TouchController] Interact: not yet available.")

# ── JOYSTICK ────────────────────────────────────────────────────────

func _on_joy_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch

		if touch.pressed and _joy_touch_index == -1:
			_joy_touch_index = touch.index
			# Converter posição global do toque para coordenadas locais do CanvasLayer
			# O CanvasLayer não tem transform de viewport aplicado, por isso usamos
			# a posição do toque directamente relativa ao JoystickBase.
			_joy_origin = _joystick_base.get_local_mouse_position() \
				if touch.index == 0 else _joy_to_local(touch.position)
			# Recentrar a base do joystick na posição do toque
			_joystick_base.position = touch.position - _joystick_base.size * 0.5
			# A origem é o centro da base, não a posição do toque
			_joy_origin = _joystick_base.position + _joystick_base.size * 0.5

		elif not touch.pressed and touch.index == _joy_touch_index:
			_joy_touch_index = -1
			# Repor base na posição original
			_joystick_base.position = _joy_base_origin
			# Repor thumb ao centro
			_reset_thumb()
			if _player:
				_player.touch_move_dir = Vector2.ZERO

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _joy_touch_index:
			return
		var delta   : Vector2 = drag.position - _joy_origin
		if delta.length() < JOYSTICK_DEADZONE:
			delta = Vector2.ZERO
		var clamped : Vector2 = delta.limit_length(JOYSTICK_RADIUS)
		_joystick_thumb.position = \
			_joystick_base.size * 0.5 + clamped - _joystick_thumb.size * 0.5
		if _player:
			_player.touch_move_dir = \
				clamped / JOYSTICK_RADIUS if clamped.length() > 0.0 else Vector2.ZERO

func _reset_thumb() -> void:
	_joystick_thumb.position = \
		_joystick_base.size * 0.5 - _joystick_thumb.size * 0.5

# Converte coordenadas globais de ecrã para coordenadas locais dentro do JoystickBase
func _joy_to_local(screen_pos: Vector2) -> Vector2:
	return screen_pos - _joystick_base.global_position

# ── CÂMARA ──────────────────────────────────────────────────────────

func _on_cam_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _cam_touch_index == -1:
			_cam_touch_index = touch.index
		elif not touch.pressed and touch.index == _cam_touch_index:
			_cam_touch_index = -1

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _cam_touch_index:
			return
		if _cam_pivot == null:
			# Tentar obter novamente (segurança para instanciação tardia)
			if _player:
				_cam_pivot = _player.get_node_or_null("CameraPivot") as Node3D
			return

		# Usar drag.relative para evitar salto no primeiro frame do toque
		_cam_pivot.rotate_y(-drag.relative.x * CAM_SENSITIVITY_H)
		var new_pitch : float = clamp(
			_cam_pivot.rotation.x - drag.relative.y * CAM_SENSITIVITY_V,
			CAM_PITCH_MIN, CAM_PITCH_MAX)
		_cam_pivot.rotation.x = new_pitch
