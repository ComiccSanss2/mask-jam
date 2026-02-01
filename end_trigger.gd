extends Area2D

# --- PARAMÈTRES ---
@export var duration : float = 10.0
@export var npc_sprite : AnimatedSprite2D 
@onready var end_sound = $AudioStreamPlayerEnd 

var triggered : bool = false

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Player" and not triggered:
		start_cinematic(body)

func start_cinematic(player):
	triggered = true
	print("DÉBUT DU CAUCHEMAR")
	
	# 1. BLOQUER LE JOUEUR
	player.set_physics_process(false) 
	player.velocity = Vector2.ZERO
	
	# --- FIX : FORCER L'ARRÊT DU SON DE PAS ---
	# On cherche le nœud de son dans le joueur et on le coupe net
	var steps = player.get_node_or_null("FootstepsSound")
	if steps:
		steps.stop()
	# ------------------------------------------

	if player.has_node("AnimNormal"): player.get_node("AnimNormal").stop()
	if player.has_node("AnimMasked"): player.get_node("AnimMasked").stop()

	# 2. LE NPC
	if npc_sprite:
		npc_sprite.visible = true
		npc_sprite.play("default") 

	# 3. GESTION DU SHADER + AUDIO
	var shader_rect = player.get_node_or_null("CanvasLayer/ColorRect") 
	
	var tween = get_tree().create_tween().set_parallel(true)
	
	# --- GESTION AUDIO (AMBIANCE DE FIN) ---
	if end_sound:
		end_sound.volume_db = -40.0 
		end_sound.play()
		tween.tween_property(end_sound, "volume_db", 0.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	# --- GESTION SHADER ---
	if shader_rect and shader_rect.material:
		var mat = shader_rect.material
		
		tween.tween_property(mat, "shader_parameter/chroma_offset_px", 50.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.tween_property(mat, "shader_parameter/wobble_px", 20.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(mat, "shader_parameter/tape_noise", 1.0, duration)
		tween.tween_property(mat, "shader_parameter/jitter_px", 10.0, duration)
		tween.tween_property(mat, "shader_parameter/vignette", 1.0, duration).set_delay(5.0)

	else:
		print("Attention : Shader non trouvé, mais le son devrait marcher.")

	# 4. FIN
	await get_tree().create_timer(duration).timeout
	end_game()

func end_game():
	print("FIN.")
	get_tree().quit()
