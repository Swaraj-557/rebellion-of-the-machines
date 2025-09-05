extends Area2D
class_name Terminal

# Interactive terminal script for hacking puzzles
# Part of the rebellion against NEXUS-7's control network

# Terminal states
enum TerminalState {
	INACTIVE,
	ACCESSIBLE,
	HACKING_IN_PROGRESS,
	COMPROMISED,
	LOCKED_DOWN
}

# Terminal types determine the puzzle/functionality
enum TerminalType {
	SECURITY_OVERRIDE,
	DOOR_CONTROL,
	CAMERA_SYSTEM,
	POWER_GRID,
	DATA_EXTRACTION,
	NEXUS_ACCESS_POINT
}

# Terminal configuration
@export var terminal_type: TerminalType = TerminalType.SECURITY_OVERRIDE
@export var terminal_id: String = "TERM_001"
@export var security_level: int = 1  # 1-5, affects puzzle difficulty
@export var requires_keycard: bool = false
@export var keycard_id: String = ""
@export var is_mission_critical: bool = false

# State management
var current_state: TerminalState = TerminalState.INACTIVE
var is_player_nearby: bool = false
var hack_progress: float = 0.0
var hack_time_required: float = 3.0  # Base hacking time

# Connected systems
var connected_doors: Array[Node] = []
var connected_cameras: Array[Node] = []
var connected_security_systems: Array[Node] = []

# Visual feedback
@onready var screen_sprite = $ScreenSprite
@onready var interaction_prompt = $InteractionPrompt
@onready var status_light = $StatusLight
@onready var collision_shape = $CollisionShape2D

# Audio feedback
@onready var beep_sound = $BeepSound
@onready var hack_sound = $HackSound
@onready var error_sound = $ErrorSound

# Signals for level systems
signal terminal_accessed(terminal_id, terminal_type)
signal terminal_hacked(terminal_id, terminal_type)
signal terminal_failed(terminal_id, terminal_type)
signal doors_unlocked(door_list)
signal security_disabled(security_systems)
signal data_extracted(data_content)

func _ready():
	# Connect area signals for player detection
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Setup initial state
	update_visual_state()
	
	# Hide interaction prompt initially
	if interaction_prompt:
		interaction_prompt.visible = false
	
	# Connect to player interaction signal
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("interaction_attempted"):
		player.interaction_attempted.connect(_on_player_interaction_attempted)
	
	print("Terminal ", terminal_id, " initialized - Type: ", TerminalType.keys()[terminal_type])

func _process(delta):
	# Handle ongoing hacking process
	if current_state == TerminalState.HACKING_IN_PROGRESS:
		handle_hacking_progress(delta)

func can_interact() -> bool:
	# Called by player interaction system
	return current_state == TerminalState.ACCESSIBLE and is_player_nearby

func handle_hacking_progress(delta):
	hack_progress += delta
	
	# Update visual feedback during hacking
	update_hack_visual_feedback()
	
	if hack_progress >= hack_time_required:
		complete_hack()

func complete_hack():
	current_state = TerminalState.COMPROMISED
	hack_progress = 0.0
	
	# Play success sound
	if hack_sound:
		hack_sound.play()
	
	# Execute terminal function based on type
	execute_terminal_function()
	
	# Emit hacked signal
	terminal_hacked.emit(terminal_id, terminal_type)
	
	print("Terminal ", terminal_id, " successfully hacked!")
	update_visual_state()

func execute_terminal_function():
	# Execute the specific function based on terminal type
	match terminal_type:
		TerminalType.SECURITY_OVERRIDE:
			disable_security_systems()
		TerminalType.DOOR_CONTROL:
			unlock_connected_doors()
		TerminalType.CAMERA_SYSTEM:
			disable_camera_network()
		TerminalType.POWER_GRID:
			toggle_power_systems()
		TerminalType.DATA_EXTRACTION:
			extract_data()
		TerminalType.NEXUS_ACCESS_POINT:
			access_nexus_network()

func disable_security_systems():
	for security_system in connected_security_systems:
		if security_system.has_method("disable"):
			security_system.disable()
	
	security_disabled.emit(connected_security_systems)
	print("Security systems disabled via terminal ", terminal_id)

func unlock_connected_doors():
	for door in connected_doors:
		if door.has_method("unlock"):
			door.unlock()
	
	doors_unlocked.emit(connected_doors)
	print("Doors unlocked via terminal ", terminal_id)

func disable_camera_network():
	for camera in connected_cameras:
		if camera.has_method("disable"):
			camera.disable()
	
	print("Camera network disabled via terminal ", terminal_id)

func toggle_power_systems():
	# Toggle power to connected systems
	print("Power systems toggled via terminal ", terminal_id)

func extract_data():
	# Extract mission-critical data
	var data_content = generate_data_content()
	data_extracted.emit(data_content)
	print("Data extracted from terminal ", terminal_id)

func access_nexus_network():
	# Special case for NEXUS access points
	print("Accessing NEXUS network via terminal ", terminal_id)

func generate_data_content() -> Dictionary:
	# Generate data based on terminal and mission context
	return {
		"terminal_id": terminal_id,
		"data_type": "security_logs",
		"content": "NEXUS-7 activity patterns detected",
		"timestamp": Time.get_datetime_string_from_system()
	}

func start_hack_attempt():
	if current_state != TerminalState.ACCESSIBLE:
		return false
	
	# Check if player has required access
	if requires_keycard and not player_has_keycard():
		show_access_denied()
		return false
	
	current_state = TerminalState.HACKING_IN_PROGRESS
	hack_progress = 0.0
	
	# Calculate hack time based on security level
	hack_time_required = 2.0 + (security_level * 0.8)
	
	# Play hacking sound
	if hack_sound:
		hack_sound.play()
	
	# Emit access signal
	terminal_accessed.emit(terminal_id, terminal_type)
	
	print("Starting hack on terminal ", terminal_id)
	update_visual_state()
	return true

func player_has_keycard() -> bool:
	# Check if player inventory contains required keycard
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("has_item"):
		return player.has_item(keycard_id)
	return false

func show_access_denied():
	print("Access denied - keycard required: ", keycard_id)
	if error_sound:
		error_sound.play()
	
	# Could trigger visual feedback here
	terminal_failed.emit(terminal_id, terminal_type)

func update_visual_state():
	if not screen_sprite or not status_light:
		return
	
	match current_state:
		TerminalState.INACTIVE:
			screen_sprite.modulate = Color.GRAY
			status_light.modulate = Color.RED
		TerminalState.ACCESSIBLE:
			screen_sprite.modulate = Color.CYAN
			status_light.modulate = Color.YELLOW
		TerminalState.HACKING_IN_PROGRESS:
			# Flickering effect during hack
			var time_value = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["millisecond"] * 0.001
			var flicker = sin(time_value * 10.0) * 0.3 + 0.7
			screen_sprite.modulate = Color.ORANGE * flicker
			status_light.modulate = Color.ORANGE
		TerminalState.COMPROMISED:
			screen_sprite.modulate = Color.GREEN
			status_light.modulate = Color.GREEN
		TerminalState.LOCKED_DOWN:
			screen_sprite.modulate = Color.DARK_RED
			status_light.modulate = Color.RED

func update_hack_visual_feedback():
	# Visual progress indicator during hacking
	var progress = hack_progress / hack_time_required
	var intensity = 0.5 + (progress * 0.5)
	
	if screen_sprite:
		screen_sprite.modulate = Color.ORANGE * intensity

func _on_body_entered(body):
	if body is Player:
		is_player_nearby = true
		
		if current_state == TerminalState.INACTIVE:
			current_state = TerminalState.ACCESSIBLE
			update_visual_state()
		
		if interaction_prompt:
			interaction_prompt.visible = can_interact()
		
		if beep_sound:
			beep_sound.play()

func _on_body_exited(body):
	if body is Player:
		is_player_nearby = false
		
		if interaction_prompt:
			interaction_prompt.visible = false
		
		# Interrupt hacking if in progress
		if current_state == TerminalState.HACKING_IN_PROGRESS:
			current_state = TerminalState.ACCESSIBLE
			hack_progress = 0.0
			update_visual_state()

func _on_player_interaction_attempted(target):
	if target == self and can_interact():
		start_hack_attempt()

# Public methods for level designers
func connect_door(door_node: Node):
	if door_node and not connected_doors.has(door_node):
		connected_doors.append(door_node)

func connect_camera(camera_node: Node):
	if camera_node and not connected_cameras.has(camera_node):
		connected_cameras.append(camera_node)

func connect_security_system(security_node: Node):
	if security_node and not connected_security_systems.has(security_node):
		connected_security_systems.append(security_node)

func set_security_level(level: int):
	security_level = clamp(level, 1, 5)

func lock_down():
	current_state = TerminalState.LOCKED_DOWN
	update_visual_state()

func reactivate():
	current_state = TerminalState.ACCESSIBLE
	update_visual_state()

func get_terminal_info() -> Dictionary:
	return {
		"id": terminal_id,
		"type": TerminalType.keys()[terminal_type],
		"state": TerminalState.keys()[current_state],
		"security_level": security_level,
		"requires_keycard": requires_keycard,
		"is_mission_critical": is_mission_critical
	}
