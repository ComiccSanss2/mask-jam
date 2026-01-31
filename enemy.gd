extends CharacterBody2D

# États
enum State { WANDER, CHASE }
var current_state = State.WANDER

# --- PARAMÈTRES ---
@export var wander_speed = 100.0
@export var chase_speed = 160.0
@export var wander_range = 250.0

# --- RÉFÉRENCES ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var timer: Timer = $Timer
@onready var sprite: Sprite2D = $Sprite2D
@onready var ray_cast: RayCast2D = $RayCast2D
@onready var tension_sound: AudioStreamPlayer = $TensionSound


# Variables internes
var player_ref = null    
var last_position: Vector2
var stuck_timer: float = 0.0
var audio_tween: Tween 

func _ready():
	# Configuration Physique
	motion_mode = MOTION_MODE_FLOATING
	ray_cast.add_exception(self) 
	
	# Configuration Navigation (Pour ne pas raser les murs)
	nav_agent.path_postprocessing = NavigationPathQueryParameters2D.PATH_POSTPROCESSING_CORRIDORFUNNEL
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 30.0
	
	# Timer setup
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	
	# Attendre que la map soit prête
	await get_tree().physics_frame
	get_new_wander_target()

func _physics_process(delta):
	if get_tree().paused: return 
	
	rotation = 0 
	
	# --- 1. SYSTÈME DE VISION (RayCast) ---
	var can_see_player = false
	if player_ref != null:
		# Viser le joueur
		ray_cast.target_position = to_local(player_ref.global_position)
		ray_cast.force_raycast_update()
		var collider = ray_cast.get_collider()
		
		# Vérifier si on touche le joueur directement (pas de mur entre deux)
		if collider != null and collider.name == "Player":
			can_see_player = true
	
	# Changement d'état
	if can_see_player:
		current_state = State.CHASE
		timer.stop()
		stuck_timer = 0
	else:
		if current_state == State.CHASE:
			# Perdu de vue - on retourne se balader
			current_state = State.WANDER
			get_new_wander_target()

	# --- 2. DÉPLACEMENT ---
	var current_speed = wander_speed
	
	if current_state == State.CHASE:
		current_speed = chase_speed
		if player_ref:
			nav_agent.target_position = player_ref.global_position
	
	# Si arrivé à destination
	if nav_agent.is_navigation_finished():
		if current_state == State.WANDER and timer.is_stopped():
			velocity = Vector2.ZERO
			timer.start()
		return

	# --- 3. ANTI-STUCK (Anti-Blocage) ---
	if current_state == State.WANDER:
		# Si on bouge de moins de 1 pixel alors qu'on devrait avancer
		if global_position.distance_to(last_position) < 1.0:
			stuck_timer += delta
		else:
			stuck_timer = 0
		
		# Si bloqué plus de 0.5s, on change de direction
		if stuck_timer > 0.5:
			get_new_wander_target()
			stuck_timer = 0
		last_position = global_position

	# Calcul de la vélocité
	var next_pos = nav_agent.get_next_path_position()
	var new_velocity = global_position.direction_to(next_pos) * current_speed
	
	# Application avec lissage (Inertie)
	velocity = velocity.move_toward(new_velocity, 1200 * delta)
	
	# Flip Sprite
	if velocity.x > 0: sprite.flip_h = false
	elif velocity.x < 0: sprite.flip_h = true
	
	move_and_slide()

# --- FONCTIONS UTILITAIRES ---

func get_new_wander_target():
	var random_dir = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var unsafe_target = global_position + (random_dir * wander_range)
	# Trouve le point navigable le plus proche (évite de viser un mur)
	var map = get_world_2d().navigation_map
	var safe_target = NavigationServer2D.map_get_closest_point(map, unsafe_target)
	nav_agent.target_position = safe_target

func _on_timer_timeout():
	if current_state == State.WANDER:
		get_new_wander_target()

# --- GESTION AUDIO (FADE IN / FADE OUT) ---

func play_tension():
	# 1. Si une animation (baisse de volume) était en cours, on l'annule !
	if audio_tween:
		audio_tween.kill()
	
	# 2. Si le son est éteint, on le lance à volume -80 (silence)
	if not tension_sound.playing:
		tension_sound.volume_db = -80.0
		tension_sound.play()
	
	# 3. On crée la nouvelle animation (Fade In)
	audio_tween = get_tree().create_tween()
	audio_tween.tween_property(tension_sound, "volume_db", 0.0, 2.0)

func stop_tension():
	# 1. On annule toute animation précédente (montée de volume)
	if audio_tween:
		audio_tween.kill()
	
	# 2. On crée l'animation de baisse (Fade Out)
	audio_tween = get_tree().create_tween()
	audio_tween.tween_property(tension_sound, "volume_db", -80.0, 3.0)
	
	# 3. IMPORTANT : On n'arrête le son qu'une fois le silence atteint
	audio_tween.tween_callback(tension_sound.stop)

# --- SIGNAUX (N'oublie pas de les connecter dans l'éditeur !) ---

# DetectionArea
func _on_detection_area_body_entered(body):
	if body.name == "Player":
		player_ref = body
		play_tension() # <--- Fade In

func _on_detection_area_body_exited(body):
	if body.name == "Player":
		player_ref = null
		stop_tension() # <--- Fade Out
		if current_state == State.CHASE:
			current_state = State.WANDER
			get_new_wander_target()

# KillArea
func _on_kill_area_body_entered(body):
	if body.name == "Player":
		if body.has_method("kill_player"):
			body.kill_player()
