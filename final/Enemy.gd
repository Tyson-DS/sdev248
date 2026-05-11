extends CharacterBody2D

signal health_changed(new_health: int, max_health: int)
signal died

@export var max_health := 100
@export var walk_speed := 160.0
@export var gravity := 980.0

@export var punch_damage := 8

@export var attack_lock_time := 1     # how long you can't move during attack
@export var hurt_lock_time := 0.25       # short stun when hit
@export var attack_cooldown := 1

@export var block_chance := 0.35
@export var block_min_time := 1
@export var block_max_time := 2
@export var block_range := 120.0


@export var ai_attack_range := 200
@export var ai_aggression := 0.35          # 0..1, higher = attacks more

@onready var flip: Node2D = $Flip
@onready var sprite: Node = $Flip/Sprite2D
@onready var hurtbox: Area2D = $hurtbox
@onready var hitbox: Area2D = $Flip/hitbox
@onready var hitbox_shape: CollisionShape2D = $Flip/hitbox/CollisionShape2D
@onready var swordsound: AudioStreamPlayer = $swordsound

var health: int
var facing := -1 # this will flip in-game
var _attack_locked := 0.0
var _hurt_locked := 0.0
var _cooldown := 0.0
var _block_timer := 0.0
var _block_cooldown := 0.0
var _dead := false
var blocking = false

# for AI
var target: CharacterBody2D

var screensize = Vector2.ZERO
enum { IDLE, RUN, JUMP, ATTACK, HURT, KO }
var state = IDLE

func _ready():
	screensize = get_viewport_rect().size
	change_state(IDLE)
	health = max_health
	emit_signal("health_changed", health, max_health)

	hitbox.monitoring = false
	hitbox_shape.disabled = true

	# When our hitbox touches someone's hurtbox
	hitbox.area_entered.connect(_on_hitbox_area_entered)

func set_target(t: CharacterBody2D) -> void:
	target = t

func _physics_process(delta: float) -> void:
	if position.x > screensize.x:
		position.x = 0
	if position.x < 0:
		position.x = screensize.x
	if _dead:
		return

	# Timers
	_attack_locked = max(0.0, _attack_locked - delta)
	_hurt_locked = max(0.0, _hurt_locked - delta)
	_cooldown = max(0.0, _cooldown - delta)
	_block_timer = max(0.0, _block_timer - delta)
	_block_cooldown = max(0.0, _block_cooldown - delta)

	blocking = _block_timer > 0.0
	$Blockcircle.visible = blocking

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Decide facing based on target (or movement)
	if target and not _dead:
		facing = 1 if target.global_position.x < global_position.x else -1
	_apply_facing_to_sprite()

	if _hurt_locked > 0.0:
		change_state(HURT)
		move_and_slide()
		return

	if _attack_locked > 0.0:
		move_and_slide()
		return

	_ai_control(delta)
	move_and_slide()


func _ai_control(delta: float) -> void:
	if not target:
		velocity.x = move_toward(velocity.x, 0, walk_speed * 6 * delta)
		change_state(IDLE)
		return

	var dx := target.global_position.x - global_position.x
	var dist = abs(dx)

	_try_block(dist)

	if blocking:
		velocity.x = move_toward(velocity.x, 0, walk_speed * 6 * delta)
		change_state(IDLE)
		return

	if dist > ai_attack_range:
		change_state(RUN)
		var dir = sign(dx)
		velocity.x = dir * walk_speed * 0.85
	else:
		velocity.x = move_toward(velocity.x, 0, walk_speed * 6 * delta)

		if _cooldown <= 0.0 and randf() < ai_aggression:
			_try_attack()

func _try_attack() -> void:
	if _cooldown > 0.0 or _attack_locked > 0.0:
		return
	hitbox.set_meta("damage", punch_damage)
	hitbox.set_meta("owner", self)
	_attack_locked = attack_lock_time
	_cooldown = randf_range(attack_cooldown, attack_cooldown *1.5)
	
	change_state(ATTACK)
	
	await get_tree().create_timer(0.5).timeout
	if _dead or state == HURT:
		return
	
	hitbox.monitoring = true
	hitbox_shape.disabled = false

	
	# Turn off hitbox after a short moment (active frames)
	# Active window is smaller than attack_lock_time
	swordsound.play()
	await get_tree().create_timer(0.10).timeout
	hitbox.monitoring = false
	hitbox_shape.disabled = true
	await $AnimationPlayer.animation_finished
	
	if _dead or state == HURT:
		return
	change_state(IDLE)
func _try_block(dist: float) -> void:
	if target == null:
		return
	if blocking:
		return
	if _block_cooldown > 0.0:
		return
	if dist > block_range:
		return

	# only block if player is attacking
	if not target.has_method("get_state"):
		return
	if target.get_state() != ATTACK:
		return

	if randf() < block_chance:
		blocking = true
		_block_timer = randf_range(block_min_time, block_max_time)
		_block_cooldown = randf_range(0.5, 1.2)
		change_state(IDLE)
		
func take_damage(amount: int) -> void:
	if _dead:
		return
	blocking = false
	_block_timer = 0.0
	health = max(0, health - amount)
	emit_signal("health_changed", health, max_health)

	_hurt_locked = hurt_lock_time
	velocity.x = -facing * 120.0  # small knockback
	velocity.y = min(velocity.y, -60.0)

	if health <= 0:
		_dead = true
		change_state(KO)
		emit_signal("died")

func _on_hitbox_area_entered(area: Area2D) -> void:
	# We only care if we hit someone else's hurtbox
	if area.name != "hurtbox":
		return
	var other := area.get_parent()
	if other == self:
		return

	# prevent double-hits in same active window by disabling hitbox immediately
	hitbox.set_deferred("monitorintg", false)
	hitbox_shape.set_deferred("disable", true)

	var dmg := int(hitbox.get_meta("damage"))
	# If opponent is blocking, reduce damage
	if other.has_method("is_blocking") and other.is_blocking():
		dmg = int(ceil(dmg * 0.35))

	if other.has_method("take_damage"):
		other.take_damage(dmg)

func is_blocking() -> bool:
	return blocking

func change_state(new_state) -> void:
	if state == new_state:
		return
	state = new_state
	
	match state:
		KO: #5
			return	
		ATTACK: #3
			$AnimationPlayer.play("attack")
		HURT: #4
			$AnimationPlayer.play("hurt")
		RUN: #1
			$AnimationPlayer.play("run")
		IDLE: #0
			$AnimationPlayer.play("idle")

func _apply_facing_to_sprite() -> void:
	flip.scale.x = facing
func get_cool_down():
	return _cooldown
