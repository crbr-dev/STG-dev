extends RefCounted

const ORB_INTERVAL := 0.75
const ORB_SPEED := 560.0
const ORB_DAMAGE := 80.0
const ORB_REPEAT_DELAY := 0.10
const LIGHTNING_INTERVAL := 1.0
const LIGHTNING_DAMAGE := 100.0
const BIRD_INTERVAL := 1.0
const BIRD_CRUISE_SPEED := 520.0
const BIRD_DAMAGE := 240.0

var stage
var cooldown := 0.0
var projectiles: Array = []
var assets: Dictionary = {}
var counts := {"orb": 0, "lightning": 0, "bird": 0}
var max_lightning_targets := 0
var max_orb_hits := 0

func _init(owner) -> void:
	stage = owner
	for kind in ["orb", "bird"]:
		var path: String = "res://assets/upgrades/" + kind + ".json"
		if FileAccess.file_exists(path):
			var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			if ResourceLoader.exists(spec.path):
				spec["texture"] = load(spec.path)
				assets[kind] = spec

func clear() -> void:
	cooldown = 0.0
	projectiles.clear()
	counts = {"orb": 0, "lightning": 0, "bird": 0}
	max_lightning_targets = 0
	max_orb_hits = 0

func _eligible(enemy: Dictionary) -> bool:
	return float(enemy.hp) > 0 and enemy.p.y >= 80 and enemy.p.y <= 890 and enemy.p.x >= 0 and enemy.p.x <= 960

func _targets(origin: Vector2) -> Array:
	var candidates: Array = []
	for enemy in stage.enemies:
		if _eligible(enemy): candidates.append(enemy)
	candidates.sort_custom(func(a, b): return origin.distance_squared_to(stage._enemy_target_position(a, origin)) < origin.distance_squared_to(stage._enemy_target_position(b, origin)))
	return candidates

func _target_alive(enemy: Dictionary) -> bool:
	if enemy.is_empty() or not _eligible(enemy): return false
	for current in stage.enemies:
		if is_same(current, enemy): return true
	return false

func update(dt: float) -> void:
	cooldown = maxf(0, cooldown - dt)
	if stage.stage_index >= 4 and stage._primary_firing() and cooldown <= 0.00001:
		match int(stage.character_index):
			1:
				_spawn_orb()
				cooldown = ORB_INTERVAL
			2:
				if _lightning(): cooldown = LIGHTNING_INTERVAL
			3:
				_spawn_bird()
				cooldown = BIRD_INTERVAL
	for index in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[index]
		var previous: Vector2 = shot.p
		shot.age += dt
		if shot.kind == "bird": _guide_bird(shot, dt)
		shot.p += shot.v * dt
		shot.trail_clock += dt
		if shot.trail_clock >= 1.0 / 45.0:
			shot.trail_clock = 0.0
			shot.trail.append(shot.p)
			if shot.trail.size() > 18: shot.trail.pop_front()
		var consumed := false
		for enemy in stage.enemies:
			if not _eligible(enemy): continue
			if not stage._projectile_contact(enemy, previous, shot.p, float(shot.radius)): continue
			if shot.kind == "orb":
				var id: int = enemy.uid
				var record: Dictionary = shot.hits.get(id, {"count": 0, "time": -1.0})
				if record.count >= 2 or shot.age - record.time < ORB_REPEAT_DELAY: continue
				var before: float = enemy.hp
				stage._damage_enemy(enemy, ORB_DAMAGE)
				if enemy.hp >= before: continue
				record.count += 1
				record.time = shot.age
				shot.hits[id] = record
				max_orb_hits = maxi(max_orb_hits, record.count)
				stage.combat_vfx.impact(stage._hit_point(enemy, shot.p), 1, "orb")
			else:
				var before: float = enemy.hp
				stage._damage_enemy(enemy, BIRD_DAMAGE)
				if enemy.hp < before: stage.combat_vfx.impact(stage._hit_point(enemy, shot.p), 3, "bird")
				consumed = true
				break
		if consumed or shot.age > 4.0 or shot.p.y < -130 or shot.p.y > 1050 or shot.p.x < -130 or shot.p.x > 1090:
			projectiles.remove_at(index)

func _spawn_orb() -> void:
	counts.orb += 1
	var origin: Vector2 = stage.player + Vector2(0, -38)
	stage.sfx.play_cue("upgrade_orb", origin)
	projectiles.append({"kind": "orb", "p": origin, "v": Vector2(0, -ORB_SPEED), "age": 0.0, "radius": 32.0, "hits": {}, "trail": [origin], "trail_clock": 0.0, "phase": counts.orb * 1.7})

func _spawn_bird() -> void:
	counts.bird += 1
	var origin: Vector2 = stage.player + Vector2(0, -38)
	stage.sfx.play_cue("upgrade_bird", origin)
	var side := -1.0 if int(counts.bird) % 2 else 1.0
	var candidates := _targets(origin)
	var target: Dictionary = candidates[0] if not candidates.is_empty() else {}
	projectiles.append({"kind": "bird", "p": origin, "v": Vector2(side * 175, -300), "age": 0.0, "radius": 24.0, "target": target, "trail": [origin], "trail_clock": 0.0, "phase": side * 0.8, "side": side})

func _lightning() -> bool:
	var origin: Vector2 = stage.player + Vector2(0, -35)
	var targets := _targets(origin)
	if targets.is_empty(): return false
	var endpoints: Array = []
	for index in range(mini(4, targets.size())):
		var enemy: Dictionary = targets[index]
		var before: float = enemy.hp
		stage._damage_enemy(enemy, LIGHTNING_DAMAGE)
		if enemy.hp < before: endpoints.append(stage._hit_point(enemy, origin))
	counts.lightning += 1
	max_lightning_targets = maxi(max_lightning_targets, endpoints.size())
	stage.combat_vfx.lightning(origin, endpoints)
	return true

func _guide_bird(shot: Dictionary, dt: float) -> void:
	if not _target_alive(shot.target):
		var candidates := _targets(shot.p)
		shot.target = candidates[0] if not candidates.is_empty() else {}
	var desired := Vector2.UP
	var distance := 999.0
	if not shot.target.is_empty():
		var to_target: Vector2 = stage._enemy_target_position(shot.target, shot.p) - shot.p
		distance = to_target.length()
		var side_axis := Vector2(-to_target.y, to_target.x).normalized()
		var bend: float = minf(65.0, distance * 0.17) * sin(shot.age * 5.0 + shot.phase) * exp(-shot.age * 0.3)
		desired = (to_target + side_axis * bend).normalized()
	else:
		desired = Vector2(shot.side * cos(shot.age * 4) * 0.18, -1).normalized()
	var turn := absf(angle_difference(shot.v.angle(), desired.angle()))
	var angle := lerp_angle(shot.v.angle(), desired.angle(), 1.0 - exp(-dt * 6.5))
	var speed: float = lerpf(340.0, BIRD_CRUISE_SPEED, clampf(shot.age / 0.65, 0, 1))
	speed *= 1.0 - minf(turn / PI, 1.0) * 0.20
	speed += sin(shot.age * 9.0) * 23.0 * minf(shot.age, 1.0)
	if distance < 150: speed += 30.0 * (1.0 - distance / 150.0)
	shot.v = Vector2.from_angle(angle) * speed

func draw(canvas: CanvasItem) -> void:
	var offset: Vector2 = Vector2(sin(stage.visual_time * 97), cos(stage.visual_time * 113)) * stage.shake
	for shot in projectiles:
		var trail: Array = shot.trail
		var hue := Color("ffbc45") if shot.kind == "orb" else Color("526dff")
		for index in range(1, trail.size()):
			var strength := float(index) / trail.size()
			canvas.draw_line(trail[index - 1], trail[index], Color(hue.r, hue.g, hue.b, strength * 0.18), 16 * strength, true)
			canvas.draw_line(trail[index - 1], trail[index], Color(hue.r, hue.g, hue.b, strength * 0.50), 5 * strength, true)
			canvas.draw_line(trail[index - 1], trail[index], Color(0.82, 0.9, 1, strength * 0.40), maxf(0.7, 1.7 * strength), true)
		if not assets.has(shot.kind): continue
		var a: Dictionary = assets[shot.kind]
		var texture: Texture2D = a.texture
		var frame := int(shot.age * float(a.fps)) % int(a.frames)
		var cell := Vector2(texture.get_width() / float(a.hframes), texture.get_height() / float(a.vframes))
		var height: float = a.display_height
		var size := Vector2(height * cell.x / cell.y, height)
		var angle: float = shot.v.angle() + PI * 0.5 if shot.kind == "bird" else 0.0
		canvas.draw_set_transform(shot.p + offset, angle)
		canvas.draw_texture_rect_region(texture, Rect2(-size * 0.5, size), Rect2(Vector2(frame % int(a.hframes), int(frame / int(a.hframes))) * cell, cell))
		canvas.draw_set_transform(offset)

func draw_glow(canvas: CanvasItem, texture: Texture2D) -> void:
	var offset: Vector2 = Vector2(sin(stage.visual_time * 97), cos(stage.visual_time * 113)) * stage.shake
	for shot in projectiles:
		if shot.p.y < 92 or shot.p.y > 875: continue
		var pulse: float = 0.85 + sin(shot.age * 17 + shot.phase) * 0.15
		var hue := Color(1, 0.55, 0.07, 0.5 * pulse) if shot.kind == "orb" else Color(0.1, 0.25, 1, 0.55 * pulse)
		var size := Vector2(150, 150) if shot.kind == "orb" else Vector2(165, 130)
		canvas.draw_set_transform(shot.p + offset, shot.v.angle() + PI * 0.5)
		canvas.draw_texture_rect(texture, Rect2(-size * 0.5, size), false, hue)
	canvas.draw_set_transform(Vector2.ZERO)
