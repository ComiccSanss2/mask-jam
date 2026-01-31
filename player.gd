extends CharacterBody2D

# --- PARAMÈTRES MOUVEMENT ---
@export var speed : float = 150.0
@export var acceleration : float = 1500.0
@export var friction : float = 1200.0

# --- PARAMÈTRES MASQUE ---
@export var mask_duration : float = 4.0 
@export var light_normal_size : float = 50.0 
@export var light_hidden_size : float = 15.0 

# --- VARIABLES ---
var masks_count : int = 0
var is_hidden : bool = false 

# --- RÉFÉRENCES ---
# Jumpscare
@onready var jumpscare_layer = $JumpscareLayer
@onready var jumpscare_anim = $JumpscareLayer/JumpscareAnim 
@onready var scream_sound = $ScreamSound

# Personnage & UI & Sons
@onready var light = $PointLight2D
@onready var mask_label = $HUD/MaskLabel
@onready var help_label = $HUD/HelpLabel 
@onready var character_anim = $CharacterAnim
@onready var footsteps_sound = $FootstepsSound

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if jumpscare_layer: jumpscare_layer.visible = false
	if light: light.scale = Vector2(light_normal_size, light_normal_size)
	
	update_mask_ui()
	# On le fait une fois au début, mais on le refera à la mort par sécurité
	ajuster_jumpscare()

func _physics_process(delta: float) -> void:
	if get_tree().paused: return

	# 1. Masque
	if Input.is_action_just_pressed("use_mask"):
		try_use_mask()

	# 2. Mouvement
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_vector != Vector2.ZERO:
		# --- ON BOUGE ---
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
		
		# Animation 8 directions
		update_animation(input_vector)
		
		# Audio : Pas
		if not footsteps_sound.playing:
			footsteps_sound.pitch_scale = randf_range(0.9, 1.1)
			footsteps_sound.play()
			
	else:
		# --- ON NE BOUGE PLUS ---
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		character_anim.stop()
		if footsteps_sound.playing: footsteps_sound.stop()

	move_and_slide()

# --- GESTION ANIMATION 8 DIRECTIONS ---
func update_animation(direction: Vector2):
	var anim_name = "walk"
	
	if direction.y < 0: anim_name += "-up"
	elif direction.y > 0: anim_name += "-down"
	
	if direction.x < 0: anim_name += "-left"
	elif direction.x > 0: anim_name += "-right"
	
	if character_anim.sprite_frames.has_animation(anim_name):
		character_anim.play(anim_name)

# --- GESTION JUMPSCARE (Full Screen) ---
func ajuster_jumpscare():
	# On s'assure qu'on travaille sur la taille ACTUELLE de l'écran
	var ecran_size = get_viewport_rect().size
	
	# On centre
	jumpscare_anim.position = ecran_size / 2
	
	# On calcule l'échelle
	var texture = jumpscare_anim.sprite_frames.get_frame_texture("default", 0)
	if texture:
		var image_size = texture.get_size()
		# On prend le ratio le plus grand pour couvrir tout l'écran sans bandes noires
		var final_scale = max(ecran_size.x / image_size.x, ecran_size.y / image_size.y)
		jumpscare_anim.scale = Vector2(final_scale, final_scale)

# --- MASQUE & UI ---
func add_mask():
	masks_count += 1
	update_mask_ui()

func update_mask_ui():
	if mask_label: mask_label.text = "Masks: " + str(masks_count)
	if help_label:
		if masks_count > 0 and not is_hidden: help_label.visible = true
		else: help_label.visible = false

func try_use_mask():
	if masks_count > 0 and not is_hidden:
		masks_count -= 1
		activate_stealth_mode()
		update_mask_ui()

func activate_stealth_mode():
	is_hidden = true
	if help_label: help_label.visible = false
	if light:
		var tween = get_tree().create_tween()
		tween.tween_property(light, "scale", Vector2(light_hidden_size, light_hidden_size), 0.5)
	await get_tree().create_timer(mask_duration).timeout
	deactivate_stealth_mode()

func deactivate_stealth_mode():
	is_hidden = false
	update_mask_ui()
	if light:
		var tween = get_tree().create_tween()
		tween.tween_property(light, "scale", Vector2(light_normal_size, light_normal_size), 0.5)

# --- MORT ---
func kill_player():
	if get_tree().paused: return
	
	print("JUMPSCARE !")
	
	# 1. On coupe le son des pas pour laisser place au cri
	if footsteps_sound.playing: footsteps_sound.stop()
	
	# 2. IMPORTANT : On recalcule la taille du screamer MAINTENANT
	# C'est ça qui corrige le bug d'affichage après le masque
	ajuster_jumpscare()
	
	# 3. Affichage
	jumpscare_layer.visible = true
	jumpscare_anim.play("default")
	if scream_sound: scream_sound.play()
	
	get_tree().paused = true
	await jumpscare_anim.animation_finished
	get_tree().paused = false
	get_tree().reload_current_scene()
