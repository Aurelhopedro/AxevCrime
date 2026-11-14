extends Node3D

## =============================================================================
## AXEV CRIME — Main  (bootstrap da cena de jogo)
## =============================================================================
##
## Responsabilidades:
##   • Bloquear a orientação do ecrã em modo landscape no Android.
##   • Ocultar/mostrar a TouchUI consoante a plataforma.
##   • Ponto de entrada para futuras transições de fase
##     (mundo, missões, estado global).
##
## Nada de lógica de movimento aqui — isso fica em player_controller.gd.
## =============================================================================

@onready var player : CharacterBody3D = $Player

func _ready() -> void:
	var is_mobile : bool = OS.has_feature("android") \
		or OS.has_feature("ios") \
		or OS.has_feature("mobile")

	if is_mobile:
		# Bloquear landscape para evitar rotação acidental
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	else:
		# Desktop — esconder UI táctil (opcional; o TouchController já verifica)
		var touch_ui : CanvasLayer = player.get_node_or_null("TouchUI")
		if touch_ui:
			touch_ui.visible = false
		# Capturar rato
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	# Escape no desktop para libertar o cursor
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
