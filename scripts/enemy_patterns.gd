extends RefCounted

var stage
var pending: Array = []
var cues: Array = []
var echoes: Array = []
var clock := 0.0

const ATTACK_FRAMES := {
	1: {"tank": [1, 2, 0], "midboss": [1, 2, 0]},
	2: {"soldier": [1, 2, 3, 0], "tank": [1, 2, 0], "midboss": [1, 2, 0], "boss_core": [1, 2, 0]},
	3: {"tank": [1, 2, 3, 0], "gunship": [2, 3, 0], "hoverboat": [1, 2, 3, 0], "rocket": [2, 3, 0], "midboss": [1, 2, 0]},
	4: {"soldier": [1, 2, 3, 0], "hoverboat": [1, 2, 3, 0], "armored_esper": [1, 2, 3, 0], "silver_scout": [1, 2, 3, 0], "rail_fortress": [1, 2, 3, 0], "boss": [1, 2, 3, 0], "boss_open": [1, 2, 3, 0]},
	5: {"soldier": [1, 2, 3, 0], "hoverboat": [1, 2, 3, 0], "silver_scout": [1, 2, 3, 0], "yellow_jeep": [1, 2, 3, 0], "yellow_heavy_tank": [1, 2, 3, 0], "green_heavy_tank": [1, 2, 3, 0], "tank": [1, 2, 3, 0], "gunship": [2, 3, 0], "round_barge": [1, 2, 0], "maid": [1, 2, 3, 0], "statue": [1, 2, 3, 0]}
}

func animation_time(enemy: Dictionary, actor_id: String) -> float:
	var frames: Array = ATTACK_FRAMES.get(stage.stage_index, {}).get(actor_id, [])
	if frames.is_empty():
		if stage.stage_index == 1 and actor_id == "soldier":
			return float(enemy.get("walk_age", 0.0)) if enemy.get("walking", false) else 0.0
		return float(enemy.get("anim_age", enemy.age))
	var fps := maxf(1.0, float(stage.art.get(actor_id, {}).get("fps", 8.0)))
	var shot_age := clock - float(enemy.get("shot_anim_start", -1000.0))
	var index := int(maxf(0.0, shot_age) * fps)
	var frame: int = int(frames[index]) if shot_age >= 0 and index < frames.size() else 0
	return (frame + 0.001) / fps

func _animate_shot(owner: Dictionary) -> void:

	if clock - float(owner.get("shot_anim_start", -1000.0)) >= 0.5:
		owner["shot_anim_start"] = clock

func _init(stage_node) -> void:
	stage = stage_node

func clear() -> void:
	for enemy in stage.enemies: enemy.erase("shot_anim_start")
	pending.clear()
	cues.clear()
	echoes.clear()
	clock = 0.0

func _alive(owner: Dictionary) -> bool:
	return is_instance_valid(stage) and stage.enemies.has(owner) and float(owner.hp) > 0 and owner.p.y > -300 and owner.p.y < 1040

func _queue(owner: Dictionary, delay: float, offset: Vector2, angle: float, speed: float, kind: int = 0, shape: String = "drop", visual_scale: float = 1.0, echo: Dictionary = {}) -> void:
	if pending.size() >= 1800: return
	pending.append({"owner": owner, "remaining": delay, "offset": offset, "angle": angle, "speed": speed, "kind": kind, "shape": shape, "scale": visual_scale, "echo": echo})

func _cue(owner: Dictionary, offset: Vector2, color: Color, duration: float, rays: bool = false, delay: float = 0.0, echo: Dictionary = {}) -> void:
	cues.append({"owner": owner, "offset": offset, "color": color, "age": -delay, "duration": duration, "rays": rays, "echo": echo})

func _aim(owner: Dictionary, offset: Vector2 = Vector2(0, 25)) -> float:
	return (stage.player - (owner.p + offset)).angle()

func _emitter_position(emission: Dictionary) -> Vector2:
	if not emission.echo.is_empty(): return emission.echo.p + emission.offset
	return emission.owner.p + emission.offset

func fire(enemy: Dictionary) -> void:
	if not _alive(enemy): return
	enemy.pattern = int(enemy.pattern) + 1
	match String(enemy.kind):
		"soldier": _soldier(enemy)
		"drone": _drone(enemy)
		"tank": _tank(enemy)
		"midboss": _midboss(enemy)
		"boss": _boss(enemy)

func _soldier(enemy: Dictionary) -> void:
	var angle := _aim(enemy, Vector2(0, 10))
	var side := -1.0 if int(enemy.variant) % 2 == 0 else 1.0
	_cue(enemy, Vector2(0, 10), Color("c3fbff"), 0.13)
	_queue(enemy, 0.09, Vector2(0, 10), angle, 370, 0, "drop", 0.82)
	if int(enemy.pattern) % 3 != 0:
		_queue(enemy, 0.20, Vector2(side * 3, 10), angle + side * 0.018, 382, 0, "drop", 0.82)
	enemy.shot = 1.95 + 0.15 * (int(enemy.variant) % 4)

func _drone(enemy: Dictionary) -> void:

	var angle := _aim(enemy)
	_cue(enemy, Vector2(0, 27), Color("8af5ff"), 0.17)
	for shot in range(3):
		for lane in range(-1, 2):
			_queue(enemy, 0.10 + shot * 0.055, Vector2(lane * 13, 27), angle + lane * 0.09, 420 + shot * 22, 0, "drop", 0.94)
	enemy.shot = 1.60 + 0.11 * (int(enemy.variant) % 3)

func _tank(enemy: Dictionary) -> void:

	var angle := _aim(enemy, Vector2(0, 38))
	for shot in range(2):
		for barrel in range(2):
			var side := -1.0 if barrel == 0 else 1.0
			var delay := 0.13 + shot * 0.14 + barrel * 0.07
			var offset := Vector2(side * 24, 38)
			_cue(enemy, offset, Color("bbffff"), 0.11, false, delay - 0.08)
			_queue(enemy, delay, offset, angle + side * 0.027, 480 + shot * 35, 0, "drop", 1.08)
	enemy.shot = 1.65 + 0.13 * ((int(enemy.pattern) + int(enemy.variant)) % 4)

func _midboss(enemy: Dictionary) -> void:
	var cycle := int(enemy.pattern)
	var aimed := _aim(enemy)
	var damaged := float(enemy.hp) / float(enemy.max_hp) < 0.57
	for pod in range(2):
		var side := -1.0 if pod == 0 else 1.0
		var origin := Vector2(side * 124, 22)
		var start := 0.18 + pod * 0.18
		_cue(enemy, origin, Color("9cfaff"), 0.2, false, pod * 0.18)
		for shot in range(3):
			for lane in range(4):
				var fan := (lane - 1.5) * 0.115
				_queue(enemy, start + shot * 0.075, origin, aimed + fan + side * 0.12, 270 + shot * 28, 0, "bead", 0.85)
	if damaged:

		_cue(enemy, Vector2(0, -58), Color("ff9de7"), 0.24, true)
		for pulse in range(3):
			for lane in range(9):
				if (lane + cycle) % 5 == 0: continue
				var angle := aimed + (lane - 4) * 0.245 + sin(cycle * 0.85 + pulse * 0.5) * 0.17
				_queue(enemy, 0.26 + pulse * 0.085, Vector2(0, -58), angle, 210 + pulse * 25, 1, "bead", 0.76)
	elif cycle % 2 == 0:
		_cue(enemy, Vector2(0, 66), Color("ffa9ed"), 0.16)
		for shot in range(4):
			_queue(enemy, 0.24 + shot * 0.09, Vector2(0, 66), aimed + sin(shot * 0.6) * 0.045, 255 + shot * 10, 1, "bead", 0.87)
	enemy.shot = 1.22 if damaged else 1.48

func _boss_phase(age: float) -> String:

	if age < 6: return "train"
	if age < 13: return "echoes"
	if age < 21: return "train"
	if age < 28: return "arcs"
	if age < 31: return "reposition"
	if age < 38: return "echoes"
	if age < 42: return "arcs"
	if age < 49: return "train"
	return "echoes"

func _boss(enemy: Dictionary) -> void:
	var phase := _boss_phase(float(enemy.age))
	match phase:
		"train": _boss_train(enemy)
		"echoes": _boss_echoes(enemy)
		"arcs": _boss_arcs(enemy)
		"reposition":
			_cue(enemy, Vector2.ZERO, Color("c8e9ff"), 0.35, true)
			enemy.shot = 0.9

func _boss_train(enemy: Dictionary) -> void:
	var angle := _aim(enemy)
	_cue(enemy, Vector2(0, 8), Color("d4f5ff"), 0.32, true)

	for lane in range(-1, 2):
		for shot in range(16):
			var speed := lerpf(700.0, 315.0, shot / 15.0)
			var bias := sin(int(enemy.pattern) * 0.77) * 0.045
			_queue(enemy, 0.30 + shot * 0.012, Vector2(lane * 10, 31), angle + lane * 0.62 + bias, speed, 0, "bead", 0.95)
	enemy.shot = 1.64 + (int(enemy.pattern) % 2) * 0.14

func _ensure_echoes(enemy: Dictionary) -> void:
	var found := false
	for echo in echoes:
		if is_same(echo.owner, enemy) and echo.life > 0.25:
			echo.life = 1.8
			found = true
	if found: return
	for index in range(12):
		var angle := TAU * index / 12.0
		echoes.append({"owner": enemy, "index": index, "angle": angle, "p": enemy.p, "life": 1.8, "age": 0.0, "flash": 0.0})

func _boss_echoes(enemy: Dictionary) -> void:
	_ensure_echoes(enemy)
	var active: Array = []
	for echo in echoes:
		if is_same(echo.owner, enemy) and echo.life > 0.25: active.append(echo)
	if active.is_empty():
		enemy.shot = 0.5
		return
	var indices := [0, 4, 7]
	for index in range(3):
		var echo: Dictionary = active[(int(enemy.pattern) * 3 + indices[index]) % active.size()]
		var angle: float = (stage.player - echo.p).angle()
		var start := 0.32 + index * 0.14
		_cue(enemy, Vector2.ZERO, Color("ffbaf4"), 0.16, false, start - 0.14, echo)
		for shot in range(3):
			for lane in range(-1, 2):
				_queue(enemy, start + shot * 0.065, Vector2.ZERO, angle + lane * 0.083, 470 + lane * 12 + shot * 5, 1, "needle", 1.0, echo)
	enemy.shot = 0.91 + (int(enemy.pattern) % 3) * 0.06

func _boss_arcs(enemy: Dictionary) -> void:
	var turn := sin(int(enemy.pattern) * 0.72) * 0.14
	for source in range(2):
		var side := -1.0 if source == 0 else 1.0
		var offset := Vector2(side * 28, 24)
		_cue(enemy, offset, Color("8eeeff"), 0.2, false, source * 0.07)
		for index in range(19):

			if (index + int(enemy.pattern) + source) % 7 == 0: continue
			var angle := -0.18 + index * (PI + 0.36) / 18.0 + turn * side
			var velocity := Vector2(cos(angle) * 1.25, sin(angle) * 0.8 + 0.24) * (245 + source * 28)
			_queue(enemy, 0.19 + source * 0.07 + (index % 3) * 0.018, offset, velocity.angle(), velocity.length(), 0, "bead", 0.87)
	enemy.shot = 0.78 + sin(int(enemy.pattern) * 1.3) * 0.07

func update(dt: float) -> void:
	clock += dt
	for index in range(echoes.size() - 1, -1, -1):
		var echo: Dictionary = echoes[index]
		echo.age += dt
		echo.life -= dt
		echo.flash = maxf(0, echo.flash - dt * 5)
		if not _alive(echo.owner):
			echoes.remove_at(index)
			continue
		if _boss_phase(float(echo.owner.age)) != "echoes": echo.life = minf(echo.life, 0.35)
		var angle: float = echo.angle + sin(clock * 0.35) * 0.12
		var target: Vector2 = echo.owner.p + Vector2(cos(angle) * 190, sin(angle) * 95 + 18)
		echo.p = echo.p.move_toward(target, dt * 290)
		if echo.life <= 0: echoes.remove_at(index)
	var audible_origin := Vector2.INF
	for index in range(pending.size() - 1, -1, -1):
		var shot: Dictionary = pending[index]
		if not _alive(shot.owner):
			pending.remove_at(index)
			continue
		shot.remaining -= dt
		if shot.remaining > 0: continue
		if not shot.echo.is_empty():
			if shot.echo.life <= 0:
				pending.remove_at(index)
				continue
			shot.echo.flash = 1.0

		if stage.bullets.size() <= 1800:
			_animate_shot(shot.owner if shot.echo.is_empty() else shot.echo)
		var origin: Vector2 = _emitter_position(shot)
		var previous_count: int = stage.bullets.size()
		stage._bullet(origin, shot.angle, shot.speed, shot.kind, shot.shape, shot.scale)
		if stage.bullets.size() > previous_count and audible_origin == Vector2.INF: audible_origin = origin
		pending.remove_at(index)
	if audible_origin != Vector2.INF: stage.sfx.play_cue("enemy_shot", audible_origin)
	for index in range(cues.size() - 1, -1, -1):
		var cue: Dictionary = cues[index]
		cue.age += dt
		if not _alive(cue.owner) or cue.age > cue.duration: cues.remove_at(index)

func draw_cues(canvas: CanvasItem) -> void:
	for echo in echoes:
		if not _alive(echo.owner): continue
		var alpha: float = minf(0.88, echo.age * 2.4) * minf(1, echo.life * 3)
		stage._draw_actor("boss", echo.p + Vector2(0, sin(clock * 3 + echo.index) * 3), 76, clock + echo.index * 0.17, Color(1.15 + echo.flash * 0.8, 1.65 + echo.flash * 0.65, 2.15 + echo.flash * 0.35, alpha))
	for cue in cues:
		if cue.age < 0 or not _alive(cue.owner): continue
		var position: Vector2 = _emitter_position(cue)
		var progress: float = cue.age / cue.duration
		var strength: float = sin(progress * PI)
		var color: Color = cue.color
		color.a = strength * 0.72
		canvas.draw_circle(position, 12 + strength * 5, Color(color.r, color.g, color.b, strength * 0.12))
		canvas.draw_line(position - Vector2(9 * strength, 0), position + Vector2(9 * strength, 0), color, 2, true)
		canvas.draw_line(position - Vector2(0, 13 * strength), position + Vector2(0, 13 * strength), color, 2, true)
		if cue.rays:
			for ray in range(7):
				var axis := Vector2.from_angle(TAU * ray / 7.0 + progress * 0.28)
				canvas.draw_line(position + axis * (18 + progress * 15), position + axis * (42 + progress * 72), color, 1.2, true)
