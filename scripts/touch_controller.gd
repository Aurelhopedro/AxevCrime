extends CanvasLayer

## AXEV CRIME — TouchController
## Manages virtual joystick, camera drag zone and action buttons.
## Writes directly to PlayerController's touch input variables —
## physics logic stays exclusively in player_controller.gd.
##
## ARQUITECTURA DE INPUT:
## - Joystick usa _input() GLOBAL para garantir que o arrasto funciona
##   mesmo quando o dedo sai da área do JoystickBase.
## - CameraZone usa gui_input (suficiente — a zona ocupa metade do ecrã
##   e o dedo raramente sai da área durante rotação normal).
## - Botões usam os sinais button_down/button_up do Button (correcto).
##
## COORDENADAS:
## - CanvasLayer com layer=10: filhos Control posicionados em coordenadas
##   de viewport (píxeis de ecrã), coincidentes com touch.position.
## - _joystick_base.position é coordenada local dentro do CanvasLayer,
##   que para um filho directo equivale à coordenada de viewport.
## - _joy_origin é o centro da base em coordenadas de viewport.
## - drag.position e touch.position estão em coordenadas de viewport.
##   O delta entre eles é portanto directo, sem conversão adicional.
##
## MULTITOUCH:
## - _joy_touch_index e _cam_touch_index são índices de dedo independentes.
## - Joystick e câmara podem funcionar simultaneamente com dois dedos.

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

# Índice do dedo atribuído a cada zona (-1 = nenhum)
var _joy_touch_index : int     = -1
var _cam_touch_index : int     = -1

# Centro da base do joystick em coordenadas de viewport (atribuído no toque inicial)
var _joy_origin      : Vector2 = Vector2.ZERO

# Posição original do JoystickBase para repor após soltar o dedo
var _joy_base_origin : Vector2 = Vector2.ZERO

# Rect de activação do joystick em coordenadas de viewport (calculado em _ready)
# O toque inicial é aceite se cair dentro desta área.
var _joy_activate_rect : Rect2 = Rect2()

func _ready() -> void:
	var parent : Node = get_parent()
	if parent is CharacterBody3D:
		_player    = parent as CharacterBody3D
		_cam_pivot = _player.get_node_or_null("CameraPivot") as Node3D
	else:
		push_warning("[TouchController] Parent não é CharacterBody3D: %s" % str(parent))

	# Aguardar um frame para o layout estar completo antes de guardar posição e tamanho
	await get_tree().process_frame

	_joy_base_origin   = _joystick_base.position
	_joy_activate_rect = Rect2(_joystick_base.global_position, _joystick_base.size)

	# Ligar botões
	_btn_jump.button_down.connect(_on_jump_pressed)
	_btn_jump.button_up.connect(_on_jump_released)
	_btn_run.button_down.connect(_on_run_pressed)
	_btn_run.button_up.connect(_on_run_released)
	_btn_interact.pressed.connect(_on_interact_pressed)

	# CameraZone usa gui_input — zona estática grande, dedo raramente sai
	_cam_zone.gui_input.connect(_on_cam_gui_input)

	# Joystick NÃO usa gui_input — usa _input() global (ver abaixo)
	# Razão: gui_input deixa de receber drag quando o dedo sai da área do Control.

# ── INPUT GLOBAL — JOYSTICK ─────────────────────────────────────────
# Processar todos os eventos de toque aqui para o joystick,
# filtrando por posição inicial e por índice de dedo.

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch

		if touch.pressed:
			# Aceitar este toque para o joystick se:
			# 1. Nenhum dedo está já atribuído ao joystick
			# 2. A posição inicial está dentro da área de activação
			# 3. O dedo não está já atribuído à câmara (evitar conflito)
			if _joy_touch_index == -1 \
					and touch.index != _cam_touch_index \
					and _joy_activate_rect.has_point(touch.position):
				_joy_touch_index = touch.index
				# Recentrar a base na posição do toque
				# position é coordenada local no CanvasLayer = coordenada de viewport
				_joystick_base.position = touch.position - _joystick_base.size * 0.5
				# Guardar o centro da base como origem do joystick
				_joy_origin = touch.position
				get_viewport().set_input_as_handled()

		else:
			# Soltar o dedo atribuído ao joystick
			if touch.index == _joy_touch_index:
				_joy_touch_index = -1
				_joystick_base.position = _joy_base_origin
				_reset_thumb()
				if _player:
					_player.touch_move_dir = Vector2.ZERO
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _joy_touch_index:
			return

		var delta   : Vector2 = drag.position - _joy_origin
		if delta.length() < JOYSTICK_DEADZONE:
			delta = Vector2.ZERO
		var clamped : Vector2 = delta.limit_length(JOYSTICK_RADIUS)

		# Actualizar posição visual do thumb
		# A posição do thumb é relativa ao JoystickBase (coordenadas locais do pai)
		_joystick_thumb.position = \
			_joystick_base.size * 0.5 + clamped - _joystick_thumb.size * 0.5

		if _player:
			_player.touch_move_dir = \
				clamped / JOYSTICK_RADIUS if clamped.length() > 0.0 else Vector2.ZERO

		get_viewport().set_input_as_handled()

func _reset_thumb() -> void:
	_joystick_thumb.position = \
		_joystick_base.size * 0.5 - _joystick_thumb.size * 0.5

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

# ── CÂMARA — gui_input da CameraZone ────────────────────────────────

func _on_cam_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _cam_touch_index == -1 \
				and touch.index != _joy_touch_index:
			_cam_touch_index = touch.index
		elif not touch.pressed and touch.index == _cam_touch_index:
			_cam_touch_index = -1

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _cam_touch_index:
			return
		if _cam_pivot == null:
			if _player:
				_cam_pivot = _player.get_node_or_null("CameraPivot") as Node3D
			return
		# drag.relative já contém o delta desde o último evento —
		# fiável em Android sem saltos no primeiro frame.
		_cam_pivot.rotate_y(-drag.relative.x * CAM_SENSITIVITY_H)
		var new_pitch : float = clamp(
			_cam_pivot.rotation.x - drag.relative.y * CAM_SENSITIVITY_V,
			CAM_PITCH_MIN, CAM_PITCH_MAX)
		_cam_pivot.rotation.x = new_pitch
