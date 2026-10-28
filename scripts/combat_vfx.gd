extends Node2D

const MAX_IMPACTS := 64
const MAX_STRIKES := 5
const MAX_EMITTERS := 24
const HUES := [Color("ffd36c"), Color("bd68ff"), Color("75ffcc")]

var stage: Node2D
var impacts: Array = []
var strikes: Array = []
var emitters: Array = []
var clock := 0.0
var glow: Texture2D
var spark: Texture2D
var ramps: Dictionary = {}

func _ready() -> void:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded, blend_add; void fragment(){ if(SCREEN_UV.y < 0.09375 || SCREEN_UV.y > 0.9458) { COLOR.a = 0.0; } }"
	var light_material := ShaderMaterial.new()
	light_material.shader = shader
	material = light_material
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var radius := Vector2(x - 31.5, y - 31.5).length() / 31.5
			var alpha := exp(-radius * radius * 7.5) * smoothstep(1.0, 0.78, radius)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	glow = ImageTexture.create_from_image(image)
	var spark_image := Image.create(6, 14, false, Image.FORMAT_RGBA8)
	for y in range(14):
		for x in range(6):
			var distance := Vector2((x - 2.5) / 2.5, (y - 6.5) / 6.5)
			spark_image.set_pixel(x, y, Color(1, 1, 1, maxf(0, 1.0 - distance.length()) * 0.9))
	spark = ImageTexture.create_from_image(spark_image)
	visible = false

func impact(point: Vector2, character: int, special: String = "") -> void:
	var hero := clampi(character, 1, 3)

	if special.is_empty():
		for index in range(impacts.size() - 1, -1, -1):
			var recent: Dictionary = impacts[index]
			if recent.age > 0.045: break
			if recent.hero == hero and recent.special.is_empty() and recent.p.distance_squared_to(point) < 12 * 12:
				recent.strength = minf(1.2, recent.strength + 0.12)
				return
	if stage and stage.sfx and special != "lightning":
		stage.sfx.play_cue("impact_%d" % hero, point, 0.85 if not special.is_empty() else 1.0)
	if impacts.size() >= MAX_IMPACTS: impacts.pop_front()
	var lifetime := 0.22 if hero == 1 else (0.27 if hero == 2 else 0.28)
	var radius := 23.0 if hero != 2 else 25.0
	if special == "orb":
		lifetime = 0.36
		radius = 43
	elif special == "bird":
		lifetime = 0.42
		radius = 47
	elif special == "lightning":
		lifetime = 0.30
		radius = 30
	impacts.append({"p": point, "hero": hero, "special": special, "age": 0.0, "duration": lifetime, "radius": radius, "phase": randf() * TAU, "strength": 1.0})
	_burst(point, hero, special)
	queue_redraw()

func lightning(origin: Vector2, targets: Array) -> void:
	var endpoints: Array[Vector2] = []
	for target in targets:
		if endpoints.size() == 4: break
		if target is Vector2 and origin.distance_squared_to(target) > 9:
			endpoints.append(target)
	if endpoints.is_empty(): return
	if stage and stage.sfx: stage.sfx.play_cue("upgrade_lightning", origin)
	if strikes.size() >= MAX_STRIKES: strikes.pop_front()
	strikes.append({"origin": origin, "targets": endpoints, "age": 0.0, "duration": 0.28, "phase": randf() * TAU})
	_burst(origin, 2, "lightning")
	for point in endpoints: impact(point, 2, "lightning")
	queue_redraw()

func advance(dt: float) -> void:
	clock += dt
	for index in range(impacts.size() - 1, -1, -1):
		impacts[index].age += dt
		if impacts[index].age >= impacts[index].duration: impacts.remove_at(index)
	for index in range(strikes.size() - 1, -1, -1):
		strikes[index].age += dt
		if strikes[index].age >= strikes[index].duration: strikes.remove_at(index)
	for entry in emitters:
		entry.remaining = maxf(0, entry.remaining - dt)
		if entry.remaining <= 0:
			entry.node.emitting = false
			entry.node.visible = false
	queue_redraw()

func clear() -> void:
	impacts.clear()
	strikes.clear()
	clock = 0
	for entry in emitters:
		entry.remaining = 0.0
		entry.node.emitting = false
		entry.node.visible = false
	queue_redraw()

func _process(_dt: float) -> void:
	var active: bool = stage == null or (stage.game_state in ["playing", "victory", "gameover"] and not stage.paused)
	visible = active
	if stage != null:
		position = Vector2(sin(stage.visual_time * 97), cos(stage.visual_time * 113)) * stage.shake
	var simulation_speed := 1.0
	for entry in emitters: entry.node.speed_scale = simulation_speed if active else 0.0

func _hue(hero: int, special: String) -> Color:
	return Color("6b82ff") if special == "bird" else HUES[hero - 1]

func _ramp(hero: int, special: String) -> Gradient:
	var key := "bird" if special == "bird" else str(hero)
	if ramps.has(key): return ramps[key]
	var hue := _hue(hero, special)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.65, 1.0])
	ramp.colors = PackedColorArray([Color(1, 0.98, 1, 0.95), hue.lightened(0.35), Color(hue.r, hue.g, hue.b, 0.65), Color(hue.r, hue.g, hue.b, 0)])
	ramps[key] = ramp
	return ramp

func _burst(point: Vector2, hero: int, special: String) -> void:
	if spark == null: return
	var selected: Dictionary = {}
	for entry in emitters:
		if entry.remaining <= 0:
			selected = entry
			break
	if selected.is_empty() and emitters.size() < MAX_EMITTERS:
		var particles := CPUParticles2D.new()
		particles.emitting = false
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.local_coords = true
		particles.texture = spark
		particles.use_parent_material = true
		particles.direction = Vector2.UP
		particles.spread = 180
		particles.gravity = Vector2.ZERO
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 3
		add_child(particles)
		selected = {"node": particles, "remaining": 0.0}
		emitters.append(selected)
	if selected.is_empty():
		selected = emitters[0]
		for entry in emitters:
			if entry.remaining < selected.remaining: selected = entry
	var particles: CPUParticles2D = selected.node
	var large := not special.is_empty()
	particles.emitting = false
	particles.position = point
	particles.amount = 16 if large else 7
	particles.lifetime = 0.34 if large else 0.22
	particles.initial_velocity_min = 85 if large else 60
	particles.initial_velocity_max = 225 if large else 140
	if hero == 1 and not large:
		particles.initial_velocity_min = 140
		particles.initial_velocity_max = 260
	particles.damping_min = 110
	particles.damping_max = 190
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0 if large else 0.68
	particles.color_ramp = _ramp(hero, special)
	particles.visible = true
	particles.speed_scale = 1.0
	particles.restart()
	particles.emitting = true
	selected.remaining = particles.lifetime

func _light(point: Vector2, diameter: float, hue: Color, alpha: float) -> void:
	if glow == null: return
	draw_texture_rect(glow, Rect2(point - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter), false, Color(hue.r, hue.g, hue.b, alpha))

func _draw() -> void:
	for strike in strikes: _draw_strike(strike)
	for hit in impacts: _draw_impact(hit)

func _draw_impact(hit: Dictionary) -> void:
	var p: Vector2 = hit.p
	var progress: float = hit.age / hit.duration
	var alpha: float = pow(1.0 - progress, 1.35) * hit.strength
	var radius: float = hit.radius
	var hue := _hue(hit.hero, hit.special)
	_light(p, radius * (2.1 + progress), hue, alpha * 0.42)
	var bright := Color(1, 0.98, 1, alpha)
	if hit.hero == 1:
		var ordinary: bool = hit.special.is_empty()
		var flare: float = radius * ((1.65 + progress * 0.60) if ordinary else (0.35 + progress * 0.85))
		for ray in range(6):
			var axis := Vector2.from_angle(hit.phase + ray * TAU / 6.0)
			var reach := flare * ((1.45 if ray % 3 == 0 else 0.82) if ordinary else (1.25 if ray % 3 == 0 else 0.68))
			if ordinary:
				draw_line(p + axis * reach * 0.42, p + axis * reach, Color(1, 0.36, 0.035, alpha * 0.95), 4.4, true)
				draw_line(p + axis * reach * 0.60, p + axis * reach * 0.96, Color(1, 0.78, 0.22, alpha * 0.9), 1.5, true)
				draw_line(p, p + axis * radius * 0.30, bright, 1.2, true)
			else:
				draw_line(p - axis * reach * 0.2, p + axis * reach, Color(1, 0.59, 0.13, alpha * 0.8), 3.5, true)
				draw_line(p, p + axis * reach * 0.86, bright, 1.2, true)
		for segment in range(3):
			var angle: float = hit.phase + segment * TAU / 3
			draw_arc(p, radius * (0.25 + progress), angle, angle + 1.1, 10, Color(1, 0.78, 0.30, alpha * 0.65), 1.5, true)
	elif hit.hero == 2:
		for spiral in range(3):
			var points := PackedVector2Array()
			for step in range(13):
				var amount := step / 12.0
				var angle: float = hit.phase + spiral * TAU / 3 + amount * 2.1 + progress * 4.6
				points.append(p + Vector2.from_angle(angle) * radius * (0.12 + amount * (0.45 + progress * 0.55)))
			draw_polyline(points, Color(0.56, 0.1, 1, alpha * 0.55), 5, true)
			draw_polyline(points, Color(0.9, 0.52, 1, alpha), 1.7, true)
	else:
		for segment in range(5):
			var angle: float = hit.phase + segment * TAU / 5 + progress * 1.3
			draw_arc(p, radius * (0.28 + progress * 0.85), angle, angle + 0.65, 10, Color(hue.r, hue.g, hue.b, alpha * 0.9), 2.1, true)
			var axis := Vector2.from_angle(angle + 0.32)
			var across := axis.orthogonal()
			var center := p + axis * radius * (0.4 + progress)
			draw_polyline(PackedVector2Array([center - across * 3 - axis * 5, center, center + across * 2 + axis * 7]), Color(0.8, 1, 1, alpha * 0.9), 1.2, true)

	for index in range(5):
		var axis := Vector2.from_angle(hit.phase + index * 2.399)
		var start := p + axis * radius * (0.35 + progress * 1.4)
		draw_line(start, start - axis * (3 + (1 - progress) * 7), Color(hue.r, hue.g, hue.b, alpha * 0.9), 1.2, true)
	if progress < 0.35:
		var core: float = 1.0 - progress / 0.35
		draw_circle(p, (3.5 + radius * 0.11) * core, Color(1, 0.97, 1, core * 0.9))

func _arc_points(start: Vector2, end: Vector2, phase: float, age: float) -> PackedVector2Array:
	var points := PackedVector2Array([start])
	var distance := start.distance_to(end)
	var normal := (end - start).normalized().orthogonal()
	var count := clampi(int(distance / 23.0), 8, 30)
	var tick := floorf(age * 48)
	for index in range(1, count):
		var fraction := index / float(count)
		var envelope := sin(fraction * PI)
		var jitter := sin(index * 9.71 + tick * 3.17 + phase) * 0.7 + sin(index * 3.13 - tick * 1.91 + phase * 1.8) * 0.3
		points.append(start.lerp(end, fraction) + normal * jitter * minf(26, distance * 0.075) * envelope)
	points.append(end)
	return points

func _draw_strike(strike: Dictionary) -> void:
	var progress: float = strike.age / strike.duration
	var fade := pow(1.0 - progress, 0.65)
	var flicker: float = 0.78 + sin(strike.age * 135 + strike.phase) * 0.22
	var alpha: float = fade * flicker
	var origin: Vector2 = strike.origin
	_light(origin, 64, Color("b766ff"), alpha * 0.7)
	draw_arc(origin, 9 + progress * 17, strike.phase, strike.phase + PI * 1.7, 24, Color(0.85, 0.45, 1, alpha), 2, true)
	for index in range(strike.targets.size()):
		var target: Vector2 = strike.targets[index]
		var points := _arc_points(origin, target, strike.phase + index * 1.73, strike.age)
		draw_polyline(points, Color(0.42, 0.05, 1, alpha * 0.13), 15, true)
		draw_polyline(points, Color(0.66, 0.13, 1, alpha * 0.65), 5.5, true)
		draw_polyline(points, Color(0.94, 0.78, 1, alpha), 1.7, true)
		var normal := (target - origin).normalized().orthogonal()
		for branch in range(2):
			var base_index := clampi(int(points.size() * (0.34 + branch * 0.31)), 1, points.size() - 2)
			var base: Vector2 = points[base_index]
			var branch_end := base.lerp(target, 0.14) + normal * (1 if branch == 0 else -1) * 24
			var fork := _arc_points(base, branch_end, strike.phase + branch + index, strike.age)
			draw_polyline(fork, Color(0.65, 0.18, 1, alpha * 0.5), 3.3, true)
			draw_polyline(fork, Color(0.9, 0.66, 1, alpha * 0.7), 0.9, true)
