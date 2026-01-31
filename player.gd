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
@onready var jumpscare_layer = $JumpscareLayer
@onready var jumpscare_anim = $JumpscareLayer/JumpscareAnim 
@onready var scream_sound = $ScreamSound
@onready var light = $PointLight2D
@onready var mask_label = $HUD/MaskLabel
@onready var help_label = $HUD/HelpLabel 

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if jumpscare_layer: jumpscare_layer.visible = false
	if light: light.scale = Vector2(light_normal_size, light_normal_size)
	
	ajuster_jumpscare()
	update_mask_ui() 

func _physics_process(delta: float) -> void:
	if get_tree().paused: return

	# Touche Espace
	if Input.is_action_just_pressed("use_mask"):
		try_use_mask()

	# Mouvement
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	look_at(get_global_mouse_position())

# --- GESTION JUMPSCARE ---
func ajuster_jumpscare():
	var ecran_size = get_viewport_rect().size
	jumpscare_anim.position = ecran_size / 2
	var texture = jumpscare_anim.sprite_frames.get_frame_texture("default", 0)
	if texture:
		var image_size = texture.get_size()
		var scale_x = ecran_size.x / image_size.x
		var scale_y = ecran_size.y / image_size.y
		var final_scale = max(scale_x, scale_y)
		jumpscare_anim.scale = Vector2(final_scale, final_scale)

# --- FONCTIONS MASQUE & UI ---

func add_mask():
	masks_count += 1
	update_mask_ui()

func update_mask_ui():
	# 1. Mise à jour du compteur
	if mask_label:
		mask_label.text = "Masks: " + str(masks_count)
	
	# 2. Gestion du texte d'aide "Space to use"
	if help_label:
		# On affiche l'aide SEULEMENT si on a des masques ET qu'on n'est pas déjà caché
		if masks_count > 0 and not is_hidden:
			help_label.visible = true
		else:
			help_label.visible = false

func try_use_mask():
	if masks_count > 0 and not is_hidden:
		masks_count -= 1
		activate_stealth_mode()

		update_mask_ui() 

func activate_stealth_mode():
	is_hidden = true
	print("Mode Furtif Activé !")
	
	# On cache l'aide immédiatement car on utilise déjà le masque
	if help_label: help_label.visible = false
	
	if light:
		var tween = get_tree().create_tween()
		tween.tween_property(light, "scale", Vector2(light_hidden_size, light_hidden_size), 0.5)
	
	await get_tree().create_timer(mask_duration).timeout
	
	deactivate_stealth_mode()

func deactivate_stealth_mode():
	is_hidden = false
	print("Mode Furtif Fini.")
	
	# On réaffiche l'aide si il nous reste des masques
	update_mask_ui()
	
	if light:
		var tween = get_tree().create_tween()
		tween.tween_property(light, "scale", Vector2(light_normal_size, light_normal_size), 0.5)

# --- MORT ---
func kill_player():
	if get_tree().paused: return
	
	print("JUMPSCARE !")
	jumpscare_layer.visible = true
	jumpscare_anim.play("default")
	if scream_sound: scream_sound.play()
	
	get_tree().paused = true
	await jumpscare_anim.animation_finished
	get_tree().paused = false
	get_tree().reload_current_scene()
