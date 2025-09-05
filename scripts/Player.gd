extends CharacterBody2D
class_name Player

# Player movement and interaction script for Alex Chen
# Handles basic movement, camera follow, and interaction system

# Movement constants
const SPEED = 300.0
const ACCELERATION = 1500.0
const FRICTION = 1200.0

# Stealth constants
const STEALTH_SPEED_MULTIPLIER = 0.4
const STEALTH_DETECTION_MULTIPLIER = 0.6

# Player state
var is_in_stealth_mode = false
var can_interact = false
var nearby_interactable = null

# Signals for communication with other systems
signal player_detected_by_enemy
signal player_entered_stealth
signal player_exited_stealth
signal interaction_attempted(target)

@onready var camera = $Camera2D
@onready var interaction_area = $InteractionArea
@onready var collision_shape = $CollisionShape2D

func _ready():
	# Connect interaction area signals
	if interaction_area:
		interaction_area.area_entered.connect(_on_interaction_area_entered)
		interaction_area.area_exited.connect(_on_interaction_area_exited)
	
	# Setup camera
	if camera:
		camera.enabled = true
		camera.make_current()

func _physics_process(delta):
	handle_movement(delta)
	handle_stealth_input()
	handle_interaction_input()

func handle_movement(delta):
	# Get input direction
	var input_direction = Vector2.ZERO
	
	if Input.is_action_pressed("move_left"):
		input_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		input_direction.x += 1
	if Input.is_action_pressed("move_up"):
		input_direction.y -= 1
	if Input.is_action_pressed("move_down"):
		input_direction.y += 1
	
	# Normalize diagonal movement
	input_direction = input_direction.normalized()
	
	# Calculate target velocity
	var target_speed = SPEED
	if is_in_stealth_mode:
		target_speed *= STEALTH_SPEED_MULTIPLIER
	
	var target_velocity = input_direction * target_speed
	
	# Apply acceleration or friction
	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	
	# Move the player
	move_and_slide()

func handle_stealth_input():
	if Input.is_action_just_pressed("stealth_mode"):
		toggle_stealth_mode()

func handle_interaction_input():
	if Input.is_action_just_pressed("interact") and can_interact and nearby_interactable:
		interaction_attempted.emit(nearby_interactable)

func toggle_stealth_mode():
	is_in_stealth_mode = !is_in_stealth_mode
	
	if is_in_stealth_mode:
		player_entered_stealth.emit()
		# Visual feedback - could modulate player sprite alpha
		modulate = Color(0.7, 0.7, 1.0, 0.8)
	else:
		player_exited_stealth.emit()
		# Return to normal appearance
		modulate = Color.WHITE
	
	print("Stealth mode: ", "ON" if is_in_stealth_mode else "OFF")

func get_detection_multiplier() -> float:
	# Returns detection multiplier for enemy AI
	return STEALTH_DETECTION_MULTIPLIER if is_in_stealth_mode else 1.0

func get_stealth_status() -> bool:
	return is_in_stealth_mode

# Interaction system
func _on_interaction_area_entered(area):
	# Check if the area belongs to an interactable object
	var interactable = area.get_parent()
	if interactable.has_method("can_interact"):
		nearby_interactable = interactable
		can_interact = true
		print("Press E to interact with ", interactable.name)

func _on_interaction_area_exited(area):
	# Check if we're leaving the current interactable
	var interactable = area.get_parent()
	if interactable == nearby_interactable:
		nearby_interactable = null
		can_interact = false
		print("Left interaction area")

# Called by enemies when player is detected
func on_detected_by_enemy(enemy):
	player_detected_by_enemy.emit()
	print("Detected by: ", enemy.name)

# Utility function to get player position for other systems
func get_player_position() -> Vector2:
	return global_position
