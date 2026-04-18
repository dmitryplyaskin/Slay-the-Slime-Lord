extends Area2D
class_name Slime

signal defeated(world_position: Vector2, slime_color: Color)

const EDGE_PADDING := 34.0
const HIT_RADIUS := 30.0
const MIN_IDLE_TIME := 0.45
const MAX_IDLE_TIME := 1.35
const MIN_MOVE_TIME := 0.35
const MAX_MOVE_TIME := 0.85
const INITIAL_MOVE_CHANCE := 0.35
const MOVE_CHANCE_AFTER_IDLE := 0.65

var slime_color: Color = Color(0.46, 0.86, 0.47, 1.0)
var max_health := 20.0
var health := 20.0
var move_speed := 80.0
var move_velocity := Vector2.ZERO
var arena_rect := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
var targeted := false
var slime_name_key := "slime.moss.name"
var slime_index := 1
var behavior_timer := 0.0
var behavior_rng := RandomNumberGenerator.new()


func _ready() -> void:
	behavior_rng.randomize()
	_pick_initial_behavior()
	queue_redraw()


func setup(arena: Rect2, spawn_position: Vector2, speed: float, color: Color, hp: float, name_key: String, display_index: int) -> void:
	arena_rect = arena
	global_position = spawn_position
	move_speed = speed
	move_velocity = Vector2.ZERO
	slime_color = color
	max_health = hp
	health = hp
	slime_name_key = name_key
	slime_index = display_index
	if is_node_ready():
		_pick_initial_behavior()
	queue_redraw()


func _process(delta: float) -> void:
	_update_behavior(delta)
	position += move_velocity * delta
	_keep_inside_arena()
	queue_redraw()


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return

	health = maxf(0.0, health - amount)
	if health <= 0.0:
		targeted = false
		defeated.emit(global_position, slime_color)
		queue_free()
	else:
		queue_redraw()


func set_targeted(value: bool) -> void:
	if targeted == value:
		return
	targeted = value
	queue_redraw()


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return health / max_health


func get_display_name() -> String:
	return "%s %d" % [Localization.tr_key(slime_name_key), slime_index]


func get_hit_radius() -> float:
	return HIT_RADIUS


func _keep_inside_arena() -> void:
	var min_x := arena_rect.position.x + EDGE_PADDING
	var max_x := arena_rect.end.x - EDGE_PADDING
	var min_y := arena_rect.position.y + EDGE_PADDING
	var max_y := arena_rect.end.y - EDGE_PADDING

	if position.x < min_x:
		position.x = min_x
		move_velocity.x = absf(move_velocity.x)
	elif position.x > max_x:
		position.x = max_x
		move_velocity.x = -absf(move_velocity.x)

	if position.y < min_y:
		position.y = min_y
		move_velocity.y = absf(move_velocity.y)
	elif position.y > max_y:
		position.y = max_y
		move_velocity.y = -absf(move_velocity.y)


func _update_behavior(delta: float) -> void:
	behavior_timer -= delta
	if behavior_timer > 0.0:
		return

	if move_velocity == Vector2.ZERO:
		if behavior_rng.randf() < MOVE_CHANCE_AFTER_IDLE:
			_start_moving_randomly()
		else:
			_start_idling()
	else:
		_start_idling()


func _pick_initial_behavior() -> void:
	if move_speed <= 0.0 or behavior_rng.randf() >= INITIAL_MOVE_CHANCE:
		_start_idling()
	else:
		_start_moving_randomly()


func _start_idling() -> void:
	move_velocity = Vector2.ZERO
	behavior_timer = behavior_rng.randf_range(MIN_IDLE_TIME, MAX_IDLE_TIME)


func _start_moving_randomly() -> void:
	if move_speed <= 0.0:
		_start_idling()
		return

	var direction := Vector2.from_angle(behavior_rng.randf_range(0.0, TAU))
	move_velocity = direction * move_speed
	behavior_timer = behavior_rng.randf_range(MIN_MOVE_TIME, MAX_MOVE_TIME)


func _draw() -> void:
	var pulse := 0.92 + sin(Time.get_ticks_msec() * 0.007 + position.x * 0.01) * 0.05
	var body_color := slime_color
	if targeted:
		body_color = body_color.lightened(0.15)

	draw_set_transform(Vector2(0.0, 16.0), 0.0, Vector2(1.2, 0.45))
	draw_circle(Vector2.ZERO, 24.0, Color(0.0, 0.0, 0.0, 0.2))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 * pulse, 0.86))
	draw_circle(Vector2.ZERO, 28.0, body_color)
	draw_circle(Vector2(-14.0, -8.0), 13.0, body_color.lightened(0.14))
	draw_circle(Vector2(12.0, -10.0), 11.0, body_color.lightened(0.08))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(-8.0, -4.0), 4.5, Color(0.08, 0.1, 0.15, 0.95))
	draw_circle(Vector2(9.0, -5.0), 4.0, Color(0.08, 0.1, 0.15, 0.95))
	draw_circle(Vector2(-7.0, -5.0), 1.5, Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(Vector2(10.0, -6.0), 1.4, Color(1.0, 1.0, 1.0, 0.85))

	var health_ratio := get_health_ratio()
	var bar_width := 54.0
	var bar_position := Vector2(-bar_width * 0.5, -42.0)
	draw_rect(Rect2(bar_position, Vector2(bar_width, 7.0)), Color(0.06, 0.07, 0.1, 0.75), true)
	draw_rect(Rect2(bar_position + Vector2.ONE, Vector2((bar_width - 2.0) * health_ratio, 5.0)), Color(0.56, 0.96, 0.67, 0.95), true)
