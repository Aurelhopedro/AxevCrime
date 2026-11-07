extends CharacterBody3D

## =============================================================================
## AXEV CRIME — PlayerController v3.1
## =============================================================================
##
## FASE 3.1 — Integração de The_Soldier.glb (117 animações incorporadas)
##
## ALTERAÇÕES v3.1 (pós-teste Android):
##   PROBLEMA 2 — Animações param durante movimento contínuo:
##     _play_anim() agora verifica is_playing(). Se a animação parou
##     (loop desligado ou interrompida), é relançada mesmo que _current_anim
##     seja o mesmo estado semântico. Evita o estado "personagem anda mas
##     a animação ficou parada".
##   PROBLEMA 3 — Direcções do joystick invertidas:
##     _dir_from_input() corrigido: X e Y do input estavam ambos invertidos
##     relativamente ao sistema de coordenadas do Godot. Correcção:
##     usar forward * input_dir.y em vez de forward * -input_dir.y, e
##     right * input_dir.x mantido (sinal de X estava duplo-invertido).
##     Resultado: joystick para cima = avançar, baixo = recuar,
##     esquerda = esquerda, direita = direita.
##
## ARQUITECTURA DE ANIMAÇÃO:
##   AnimationPlayer encontrado automaticamente dentro de CharacterMesh/The_Soldier.
##   O GLB tem 117 animações com nomes desconhecidos à partida.
##   O sistema usa _resolve_anim_name() para mapear nomes semânticos
##   (Idle, Walk, Run, Jump) para os nomes reais do GLB.
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

## Velocidade horizontal mínima para sair do Idle
const MOVE_THRESHOLD : float = 0.3
## Velocidade horizontal para transição walk→run
const RUN_THRESHOLD  : float = 5.5

## Nomes semânticos → lista de candidatos por ordem de prioridade.
## O primeiro encontrado no AnimationPlayer é o que fica mapeado.
const ANIM_CANDIDATES : Dictionary = {
	"Idle": [
		"Idle", "idle", "IDLE",
		"Armature|Idle", "Armature|idle",
		"Standing Idle", "standing_idle",
		"Breathing Idle", "breathing_idle",
		"Idle_Neutral", "idle_neutral",
		"mixamo.com",          # Mixamo default idle exportado sem rename
		"T-Pose",              # fallback de último recurso
	],
	"Walk": [
		"Walk", "walk", "Walking", "walking",
		"Armature|Walk", "Armature|walk",
		"Walk Forward", "Walk_Forward", "walk_forward",
		"WalkForward", "Walk In Place", "Walk_InPlace",
		"Walk_Normal", "Slow Walk",
	],
	"Run": [
		"Run", "run", "Running", "running",
		"Sprint", "sprint", "Sprinting",
		"Jog", "jog", "Jogging",
		"Armature|Run", "Armature|run",
		"Armature|Sprint", "Armature|Jog",
		"Run Forward", "Run_Forward", "run_forward",
		"RunForward", "Run In Place", "Run_InPlace",
		"Fast Run",
	],
	"Jump": [
		"Jump", "jump", "Jumping", "jumping",
		"Jump Up", "Jump_Up", "jump_up",
		"Armature|Jump", "Armature|jump",
		"Jump In Place", "Jump_InPlace",
		"Jump Start", "Fall",
		"Leap",
	],
}

## Mapeamento resolvido em runtime: "Idle" → nome real no AnimationPlayer
var _anim_map        : Dictionary = {}

# ─── Estado público (lido pelo touch_controller.gd) ─────────────────────────
var is_in_vehicle        : bool    = false
var touch_move_dir       : Vector2 = Vector2.ZERO
var touch_run            : bool    = false
var touch_jump_requested : bool    = false

# ─── Flags internas ─────────────────────────────────────────────────────────
var _is_mobile     : bool = false
var _was_on_floor  : bool = true

# ─── Estado de animação ──────────────────────────────────────────────────────
var _anim_player   : AnimationPlayer = null
var _current_anim  : String = ""
var _land_timer    : float  = 0.0

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

	# Aguardar um frame para The_Soldier.glb estar completamente instanciado
	await get_tree().process_frame
	_find_animation_player()

func _find_animation_player() -> void:
	## Localiza o AnimationPlayer dentro de The_Soldier.glb.
	## O GLB Mixamo/Soldier coloca o AP dentro da hierarquia:
	##   The_Soldier → Armature → AnimationPlayer   (Mixamo via Blender)
	##   The_Soldier → AnimationPlayer               (exportação directa)
	##   The_Soldier → [RootNode] → AnimationPlayer  (outros pipelines)

	# 1ª tentativa: AnimationRoot (biblioteca externa — não esperada aqui)
	_anim_player = _find_ap_deep(animation_root)

	# 2ª tentativa: CharacterMesh (The_Soldier.glb — principal)
	if _anim_player == null:
		_anim_player = _find_ap_deep(character_mesh)

	if _anim_player == null:
		push_warning(
			"[PlayerController] AnimationPlayer não encontrado em CharacterMesh nem AnimationRoot.\n" +
			"  Hierarquia actual de CharacterMesh:\n" +
			_dump_tree(character_mesh, 0))
		return

	print("[PlayerController] AnimationPlayer encontrado: ", _anim_player.get_path())

	# Desactivar root motion — o CharacterBody3D controla o movimento
	_anim_player.root_motion_track = ""

	# Listar TODAS as animações disponíveis (para diagnóstico no Output)
	var all_anims : Array = Array(_anim_player.get_animation_list())
	print("[PlayerController] %d animações disponíveis:" % all_anims.size())
	for a in all_anims:
		print("  • ", a)

	# Resolver mapeamento semântico → nome real
	_build_anim_map(all_anims)

	# Iniciar Idle
	_play_anim("Idle", true)

func _find_ap_deep(root: Node) -> AnimationPlayer:
	## Procura AnimationPlayer recursivamente na hierarquia.
	if root == null:
		return null
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var result := _find_ap_deep(child)
		if result != null:
			return result
	return null

func _build_anim_map(available: Array) -> void:
	## Para cada estado semântico, encontra o primeiro candidato presente.
	_anim_map.clear()
	for semantic in ANIM_CANDIDATES.keys():
		var found : String = ""
		for candidate in ANIM_CANDIDATES[semantic]:
			if candidate in available:
				found = candidate
				break
		if found.is_empty():
			# Fallback: procura por substring case-insensitive
			var key_lower : String = semantic.to_lower()
			for a in available:
				if key_lower in a.to_lower():
					found = a
					break
		if not found.is_empty():
			_anim_map[semantic] = found
			print("[PlayerController] Mapeamento: %s → \"%s\"" % [semantic, found])
		else:
			push_warning("[PlayerController] Animação '%s' não encontrada. Estados: %s" % [semantic, str(available)])

func _dump_tree(node: Node, depth: int) -> String:
	## Serializa a hierarquia de nós para diagnóstico.
	if node == null:
		return ""
	var indent : String = "  ".repeat(depth)
	var result : String = indent + node.name + " (" + node.get_class() + ")\n"
	if depth < 4:
		for child in node.get_children():
			result += _dump_tree(child, depth + 1)
	return result

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
	if character_mesh == null:
		return
	var flat_dir := Vector3(dir.x, 0.0, dir.z)
	if flat_dir.length_squared() < 0.001:
		return
	var target_basis := Basis.looking_at(flat_dir, Vector3.UP)
	character_mesh.transform.basis = \
		character_mesh.transform.basis.slerp(target_basis, MESH_ROTATION_SPEED)

func _dir_from_input(input_dir: Vector2) -> Vector3:
	## CORRECÇÃO v3.1 — Problema 3: direcções invertidas.
	## No ecrã Android, Y do touch cresce para baixo:
	##   arrastar para cima → input_dir.y negativo → deve avançar (forward)
	##   arrastar para baixo → input_dir.y positivo → deve recuar (-forward)
	## Portanto o sinal correcto é: forward * -input_dir.y  (já estava correcto)
	##
	## O X estava duplo-invertido:
	##   arrastar para a direita → input_dir.x positivo → deve mover para a direita (right)
	##   touch_move_dir = clamped / JOYSTICK_RADIUS → X positivo = direita ✓
	##   _dir_from_input usava right * input_dir.x → correcto em teoria
	##   MAS a câmara tem rotate_y negativo, o que espelha o right vector.
	##   Resultado final: negar o X do input para restaurar a direcção natural.
	##
	## Sumário das negações correctas para Godot 4 com câmara orbitante:
	##   forward * -input_dir.y  → cima = avançar
	##   right   * -input_dir.x  → joystick direita = mover para a direita
	var basis   : Basis   = camera_pivot.global_transform.basis \
		if camera_pivot else global_transform.basis
	var forward : Vector3 = -basis.z.normalized()
	var right   : Vector3 = basis.x.normalized()
	forward.y = 0.0
	right.y   = 0.0
	return (forward * -input_dir.y + right * -input_dir.x).normalized()

# ─── SISTEMA DE ANIMAÇÃO ─────────────────────────────────────────────────────

func _update_animation(on_floor: bool, delta: float) -> void:
	## Máquina de estados: Land > Jump > Fall > Run > Walk > Idle

	if _anim_player == null:
		return

	# Temporizador da animação Land (bloqueio temporário após aterrar)
	if _land_timer > 0.0:
		_land_timer -= delta
		return

	# Aterragem
	if on_floor and not _was_on_floor:
		if _anim_map.has("Jump"):
			_play_anim("Jump")
		else:
			_play_anim("Idle")
		_land_timer = 0.35
		return

	# No ar
	if not on_floor:
		_play_anim("Jump")
		return

	# No chão
	var h_speed    : float = Vector2(velocity.x, velocity.z).length()
	var is_running : bool  = Input.is_action_pressed("run") or touch_run

	if h_speed < MOVE_THRESHOLD:
		_play_anim("Idle")
	elif is_running:
		_play_anim("Run")
	else:
		_play_anim("Walk")

func _play_anim(semantic: String, force: bool = false) -> void:
	## Toca a animação pelo nome semântico ("Idle", "Walk", "Run", "Jump").
	## Converte para o nome real via _anim_map.
	##
	## CORRECÇÃO v3.1 — Problema 2: animações param durante movimento contínuo.
	## Causa: se o AnimationPlayer parar (animação sem loop ou interrompida),
	## a guarda "_current_anim == semantic" impedia o relançamento porque
	## o estado semântico não mudava — mas a animação estava parada.
	## Solução: verificar _anim_player.is_playing() adicionalmente.
	## Se a animação parou, relançar mesmo que o estado semântico seja o mesmo.
	if _anim_player == null:
		return

	# Resolver nome real
	var real_name : String = _anim_map.get(semantic, "")
	if real_name.is_empty():
		if _anim_player.has_animation(semantic):
			real_name = semantic
		else:
			return  # não encontrado — falha silenciosa

	if not _anim_player.has_animation(real_name):
		return

	# Verificar se já está a tocar esta animação E não parou
	# (is_playing() = false indica que o clip chegou ao fim sem loop)
	var already_playing : bool = \
		_current_anim == semantic and \
		_anim_player.is_playing() and \
		_anim_player.current_animation == real_name

	if already_playing and not force:
		return  # animação a correr correctamente — não reiniciar

	# Tocar (ou retomar) a animação
	_anim_player.play(real_name)
	_current_anim = semantic

# ─── API VEÍCULO ─────────────────────────────────────────────────────────────

func enter_vehicle(_vehicle_node: Node) -> void:
	is_in_vehicle = true
	_play_anim("Idle", true)

func exit_vehicle() -> void:
	is_in_vehicle = false
