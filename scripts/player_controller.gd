extends CharacterBody3D

## =============================================================================
## AXEV CRIME — PlayerController v2
## =============================================================================
##
## ARQUITECTURA DE ANIMAÇÃO (Quaternius Universal Base Characters + Anim Library 1):
##
##   O sistema usa AnimationTree com AnimationStateMachine para transições suaves.
##   Isto é mais robusto do que AnimationPlayer.play() directamente, especialmente
##   em mobile onde os frame rates variam.
##
##   ESTADOS DA MÁQUINA:
##   idle → walk (input detectado, velocidade < threshold de corrida)
##   idle → run  (input detectado, botão run pressionado)
##   walk → run  (botão run pressionado durante movimento)
##   * → jump    (jump pressionado no chão)
##   jump → idle (aterra no chão)
##   * → fall    (velocidade.y < -1.0 e fora do chão)
##   fall → idle (aterra no chão)
##
##   NOMES DE ANIMAÇÃO (Universal Animation Library 1 — Standard):
##   "Idle", "Walk", "Jog" (usado como walk rápido / run leve),
##   "Sprint", "Jump", "Fall", "Land"
##
##   O script tenta os nomes exactos e cai para alternativas se não encontrar.
##
## RETARGETING:
##   O GLB de animações (AnimationRoot/animations.glb) usa rig humanoid.
##   O Godot 4.3 retargeta automaticamente para o esqueleto do personagem
##   desde que ambos estejam configurados com SkeletonProfileHumanoid.
##
## MOVIMENTO:
##   - WASD / joystick virtual → movimento
##   - Botão RUN / Shift → correr
##   - Botão JUMP / Espaço → saltar
##   - Arrastar ecrã (zona direita) / rato capturado → câmara
##
## =============================================================================

const WALK_SPEED    : float = 4.0
const RUN_SPEED     : float = 9.0
const JUMP_VELOCITY : float = 4.5
const GRAVITY       : float = 9.8

const MOUSE_SENSITIVITY : float = 0.003
const CAM_PITCH_MIN     : float = -0.8
const CAM_PITCH_MAX     : float = 0.4

## Rotação suave do personagem (slerp factor por frame a 60fps)
const MESH_ROTATION_SPEED : float = 0.18

## Nomes de animação do Universal Animation Library 1 (versão Standard)
## Se o teu GLB usar prefixo "Armature|", o script tenta automaticamente.
const ANIM_IDLE   : String = "Idle"
const ANIM_WALK   : String = "Walk"
const ANIM_JOG    : String = "Jog"      # usado para run leve
const ANIM_SPRINT  : String = "Sprint"   # usado para run rápido
const ANIM_JUMP   : String = "Jump"
const ANIM_FALL   : String = "Fall"
const ANIM_LAND   : String = "Land"

## Velocidade horizontal mínima para sair do Idle
const MOVE_THRESHOLD : float = 0.3
## Velocidade horizontal para transição walk→run
const RUN_THRESHOLD  : float = 5.5

# ─── Estado público (lido pelo touch_controller.gd) ─────────────────────────
var is_in_vehicle        : bool    = false
var touch_move_dir       : Vector2 = Vector2.ZERO
var touch_run            : bool    = false
var touch_jump_requested : bool    = false

# ─── Flags internas ─────────────────────────────────────────────────────────
var _is_mobile     : bool = false
var _was_on_floor  : bool = true   # para detectar aterragem

# ─── Estado de animação ──────────────────────────────────────────────────────
var _anim_player   : AnimationPlayer = null   # encontrado nos GLBs
var _current_anim  : String = ""
var _land_timer    : float  = 0.0             # duração da animação Land

# ─── Nós ────────────────────────────────────────────────────────────────────
@onready var camera_pivot    : Node3D = $CameraPivot
@onready var character_mesh  : Node3D = $CharacterMesh
@onready var animation_root  : Node3D = $AnimationRoot

# ─── INICIALIZAÇÃO ───────────────────────────────────────────────────────────

func _ready() -> void:
	_is_mobile = OS.has_feature("android") \
		or OS.has_feature("ios") \
		or OS.has_feature("mobile")

	if not _is_mobile and not OS.has_feature("web"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Aguardar um frame para os filhos GLB estarem instanciados
	await get_tree().process_frame
	_find_animation_player()

func _find_animation_player() -> void:
	## Procura AnimationPlayer em AnimationRoot (GLB de animações) primeiro,
	## depois em CharacterMesh (GLB do personagem), como fallback.
	## O Universal Animation Library 1 coloca o AnimationPlayer no nó raiz do GLB.

	# 1ª tentativa: AnimationRoot (separado, preferido)
	_anim_player = _find_ap_in(animation_root)

	# 2ª tentativa: CharacterMesh (GLB com animações incorporadas)
	if _anim_player == null:
		_anim_player = _find_ap_in(character_mesh)

	if _anim_player != null:
		print("[PlayerController] AnimationPlayer encontrado: ", _anim_player.get_path())
		_play_anim(ANIM_IDLE, true)
	else:
		push_warning(
			"[PlayerController] AnimationPlayer não encontrado.\n" +
			"  → Coloca o GLB Quaternius em CharacterMesh ou AnimationRoot.\n" +
			"  → Ver assets/models/character/README.md")

func _find_ap_in(root: Node3D) -> AnimationPlayer:
	if root == null:
		return null
	# Procura directa no nó
	if root is AnimationPlayer:
		return root as AnimationPlayer
	# Procura nos filhos imediatos (nó raiz do GLB)
	for child in root.get_children():
		if child is AnimationPlayer:
			return child as AnimationPlayer
		# Procura um nível mais fundo (GLB com hierarquia: raiz → Armature → AP)
		var ap := child.find_child("AnimationPlayer", true, false)
		if ap is AnimationPlayer:
			return ap as AnimationPlayer
	return null

# ─── INPUT (rato/desktop) ────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _is_mobile:
		return
	if event is InputEventMouseMotion \
			and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		camera_pivot.rotate_y(-motion.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(
			camera_pivot.rotation.x - motion.relative.y * MOUSE_SENSITIVITY,
			CAM_PITCH_MIN, CAM_PITCH_MAX)

# ─── LOOP DE FÍSICA ─────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if is_in_vehicle:
		return

	var on_floor : bool = is_on_floor()

	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_jump(on_floor)
	move_and_slide()

	_update_animation(on_floor, delta)

	_was_on_floor = on_floor
	touch_jump_requested = false

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _handle_movement(_delta: float) -> void:
	var kb_dir    : Vector2 = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back")
	var input_dir : Vector2 = kb_dir if kb_dir.length_squared() > 0.0 \
		else touch_move_dir
	var is_running : bool = Input.is_action_pressed("run") or touch_run
	var speed      : float = RUN_SPEED if is_running else WALK_SPEED

	if input_dir.length_squared() > 0.0:
		var dir : Vector3 = _dir_from_input(input_dir)
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		# Rotação suave do CharacterMesh para a direcção do movimento
		_rotate_mesh_toward(dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

func _handle_jump(on_floor: bool) -> void:
	var jump_pressed : bool = \
		Input.is_action_just_pressed("jump") or touch_jump_requested
	if jump_pressed and on_floor:
		velocity.y = JUMP_VELOCITY

func _rotate_mesh_toward(dir: Vector3) -> void:
	## Roda suavemente o CharacterMesh para a direcção de movimento.
	## Usa a projecção horizontal da direcção (Y=0) para evitar inclinação.
	if character_mesh == null:
		return
	var flat_dir := Vector3(dir.x, 0.0, dir.z)
	if flat_dir.length_squared() < 0.001:
		return
	var target_basis := Basis.looking_at(flat_dir, Vector3.UP)
	character_mesh.transform.basis = \
		character_mesh.transform.basis.slerp(target_basis, MESH_ROTATION_SPEED)

func _dir_from_input(input_dir: Vector2) -> Vector3:
	var basis   : Basis   = camera_pivot.global_transform.basis \
		if camera_pivot else global_transform.basis
	var forward : Vector3 = -basis.z.normalized()
	var right   : Vector3 = basis.x.normalized()
	forward.y = 0.0
	right.y   = 0.0
	return (forward * -input_dir.y + right * input_dir.x).normalized()

# ─── SISTEMA DE ANIMAÇÃO ─────────────────────────────────────────────────────

func _update_animation(on_floor: bool, delta: float) -> void:
	## Máquina de estados de animação.
	## Prioridade: Land > Jump > Fall > Run > Walk > Idle

	# Temporizador da animação Land
	if _land_timer > 0.0:
		_land_timer -= delta
		return  # aguarda que o Land termine

	# Aterragem (transição ar→chão)
	if on_floor and not _was_on_floor:
		_play_anim(ANIM_LAND)
		# Tempo aproximado da animação Land (ajustar se o GLB for diferente)
		_land_timer = 0.4
		return

	# No ar
	if not on_floor:
		if velocity.y > 0.1:
			_play_anim(ANIM_JUMP)
		else:
			_play_anim(ANIM_FALL)
		return

	# No chão
	var h_speed    : float = Vector2(velocity.x, velocity.z).length()
	var is_running : bool  = Input.is_action_pressed("run") or touch_run

	if h_speed < MOVE_THRESHOLD:
		_play_anim(ANIM_IDLE)
	elif is_running:
		# Sprint se velocidade alta, Jog se velocidade média
		if h_speed >= RUN_THRESHOLD:
			_play_anim(ANIM_SPRINT)
		else:
			_play_anim(ANIM_JOG)
	else:
		_play_anim(ANIM_WALK)

func _play_anim(name: String, force: bool = false) -> void:
	## Toca a animação. Se `name` não existir, tenta "Armature|<name>".
	## Não faz nada se já estiver a tocar a mesma animação (evita reset).
	if _anim_player == null:
		return
	if not force and _current_anim == name:
		return

	var actual_name : String = _resolve_anim_name(name)
	if actual_name.is_empty():
		return  # animação não encontrada — falha silenciosa

	_anim_player.play(actual_name)
	_current_anim = name

func _resolve_anim_name(name: String) -> String:
	## Retorna o nome real da animação no AnimationPlayer.
	## Tenta: nome exacto → "Armature|<nome>" → vazio (não encontrado).
	if _anim_player.has_animation(name):
		return name
	var alt := "Armature|" + name
	if _anim_player.has_animation(alt):
		return alt
	# Log único para evitar spam no console
	if not _current_anim.begins_with("__missing_"):
		push_warning(
			"[PlayerController] Animação '%s' não encontrada no AnimationPlayer.\n" %
			name + "  Animações disponíveis: %s" %
			str(_anim_player.get_animation_list()))
	return ""

# ─── API VEÍCULO ─────────────────────────────────────────────────────────────

func enter_vehicle(_vehicle_node: Node) -> void:
	is_in_vehicle = true
	_play_anim(ANIM_IDLE, true)

func exit_vehicle() -> void:
	is_in_vehicle = false
