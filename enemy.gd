extends CharacterBody2D

# --- ÉTATS ---
enum State { WANDER, NOTICE, CHASE }
var current_state = State.WANDER

# --- PARAMÈTRES ---
@export var wander_speed = 100.0
@export var chase_speed = 160.0
@export var wander_range = 250.0
@export var notice_duration = 1.0 

# --- PARAMÈTRES PERSONNALISABLES (CUSTOM ASSETS) ---
@export_group("Custom Assets")
@export var specific_tension_sound : AudioStream  
@export var jumpscare_scream_sound : AudioStream  
@export var jumpscare_anim_name : String = "default" 

# TAILLE ET LARGEUR
@export var jumpscare_scale_modifier : float = 1.0 # Zoom global
@export var jumpscare_width_modifier : float = 1.0 # <--- NOUVEAU : Élargir/Étirer

# --- RÉFÉRENCES ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var timer: Timer = $Timer
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var ray_cast: RayCast2D = $RayCast2D
@onready var tension_sound: AudioStreamPlayer = $TensionSound

# --- VARIABLES INTERNES ---
var player_ref = null       
var last_position: Vector2  
var stuck_timer: float = 0.0
var audio_tween: Tween      

func _ready():
	motion_mode = MOTION_MODE_FLOATING
	
	if specific_tension_sound != null:
		tension_sound.stream = specific_tension_sound
	
	ray_cast.add_exception(self)
	
	nav_agent.path_postprocessing = NavigationPathQueryParameters2D.PATH_POSTPROCESSING_CORRIDORFUNNEL
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 30.0
	
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	
	await get_tree().physics_frame
	get_new_wander_target()

func _physics_process(delta):
	if get_tree().paused: return
	rotation = 0 
	
	# --- 1. VISION ---
	var can_see_player = false
	if player_ref != null:
		var is_player_hidden = false
		if "is_hidden" in player_ref and player_ref.is_hidden:
			is_player_hidden = true
		if not is_player_hidden:
			ray_cast.target_position = to_local(player_ref.global_position)
			ray_cast.force_raycast_update()
			var collider = ray_cast.get_collider()
			if collider != null and collider.name == "Player":
				can_see_player = true
	
	# --- 2. ÉTATS ---
	if can_see_player:
		if current_state == State.WANDER:
			start_notice_delay()
	else:
		if current_state == State.CHASE or current_state == State.NOTICE:
			current_state = State.WANDER
			get_new_wander_target()

	# --- 3. DÉPLACEMENT ---
	var current_speed = wander_speed
	match current_state:
		State.NOTICE:
			velocity = Vector2.ZERO
			if player_ref:
				var dir = global_position.direction_to(player_ref.global_position)
				if dir.x > 0: sprite.flip_h = false
				elif dir.x < 0: sprite.flip_h = true
			move_and_slide()
			return 

		State.CHASE:
			current_speed = chase_speed
			timer.stop() 
			if player_ref:
				nav_agent.target_position = player_ref.global_position
				
		State.WANDER:
			current_speed = wander_speed

	if nav_agent.is_navigation_finished():
		if current_state == State.WANDER and timer.is_stopped():
			velocity = Vector2.ZERO
			timer.start()
		return

	# --- 4. ANTI-STUCK ---
	if current_state == State.WANDER:
		if global_position.distance_to(last_position) < 1.0:
			stuck_timer += delta
		else:
			stuck_timer = 0
		if stuck_timer > 0.5:
			get_new_wander_target()
			stuck_timer = 0
		last_position = global_position

	var next_pos = nav_agent.get_next_path_position()
	var new_velocity = global_position.direction_to(next_pos) * current_speed
	velocity = velocity.move_toward(new_velocity, 1200 * delta)
	
	if velocity.x > 0: sprite.flip_h = false
	elif velocity.x < 0: sprite.flip_h = true
	move_and_slide()

# --- DELAY & NAV & AUDIO (Inchangés) ---
func start_notice_delay():
	current_state = State.NOTICE
	velocity = Vector2.ZERO
	timer.stop() 
	await get_tree().create_timer(notice_duration).timeout
	if current_state == State.NOTICE:
		current_state = State.CHASE
		stuck_timer = 0

func get_new_wander_target():
	var random_dir = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var unsafe_target = global_position + (random_dir * wander_range)
	var map = get_world_2d().navigation_map
	var safe_target = NavigationServer2D.map_get_closest_point(map, unsafe_target)
	nav_agent.target_position = safe_target

func _on_timer_timeout():
	if current_state == State.WANDER:
		get_new_wander_target()

func play_tension():
	if audio_tween: audio_tween.kill()
	if not tension_sound.playing:
		tension_sound.volume_db = -80.0
		tension_sound.play()
	audio_tween = get_tree().create_tween()
	audio_tween.tween_property(tension_sound, "volume_db", 0.0, 2.0)

func stop_tension():
	if audio_tween: audio_tween.kill()
	audio_tween = get_tree().create_tween()
	audio_tween.tween_property(tension_sound, "volume_db", -80.0, 3.0)
	audio_tween.tween_callback(tension_sound.stop)

# --- SIGNAUX ---
func _on_detection_area_body_entered(body):
	if body.name == "Player":
		player_ref = body
		play_tension() 

func _on_detection_area_body_exited(body):
	if body.name == "Player":
		player_ref = null
		stop_tension() 
		if current_state == State.CHASE or current_state == State.NOTICE:
			current_state = State.WANDER
			get_new_wander_target()

func _on_kill_area_body_entered(body):
	if body.name == "Player":
		if body.has_method("kill_player"):
			# --- MODIFICATION ICI ---
			# On envoie les 4 paramètres : Nom, Son, Zoom, et Largeur
			body.kill_player(jumpscare_anim_name, jumpscare_scream_sound, jumpscare_scale_modifier, jumpscare_width_modifier)
