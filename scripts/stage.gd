extends Node2D

const W := 960.0
const H := 960.0
const MAP_VIEW_SIZE := 1024.0
const CAMERA_PAN_MAX := 13.0
const CAMERA_FOLLOW_SPEED := 8.0
const CAMERA_EDGE_ZONE := 0.20
const PLAY_TOP := 62.0
const PLAY_BOTTOM := 906.0
const PLAYER_HOVER_AMPLITUDE := 3.0
const GOLD := Color("ffe36b")
const CYAN := Color("9bffff")
const PINK := Color("ff61db")
const WHITE := Color("fff9ee")
const NeonUI = preload("res://scripts/neon_ui.gd")
const ProjectileGlow = preload("res://scripts/projectile_glow.gd")
const IntroPlayer = preload("res://scripts/intro_player.gd")
const EndingPlayer = preload("res://scripts/ending_player.gd")
const Gamepad = preload("res://scripts/gamepad.gd")
const EnemyPatterns = preload("res://scripts/enemy_patterns.gd")
const Stage3Weapons = preload("res://scripts/stage3_weapons.gd")
const CharacterSelect = preload("res://scripts/character_select.gd")
const CombatVFX = preload("res://scripts/combat_vfx.gd")
const UpgradedAttacks = preload("res://scripts/upgraded_attacks.gd")
const BGMPlayer = preload("res://scripts/bgm_player.gd")
const SFXPlayer = preload("res://scripts/sfx_player.gd")
const VoicePlayer = preload("res://scripts/voice_player.gd")
const StageLighting = preload("res://scripts/stage_lighting.gd")
const PowerupBurst = preload("res://scripts/powerup_burst.gd")
const CHAPTER_COUNT := 5
const HERO_NAMES := ["YUSUKE SAGAMI", "J-B 5TH", "IRORI MIMASAKA"]
const HERO_DIRECTORIES := ["res://assets/sprites", "res://assets/stage2/sprites", "res://assets/stage3/sprites"]

var stage_index := 1
var character_index := 1
var hero_library: Dictionary = {}
var hero_portraits: Array[Texture2D] = []
var stage_spec: Dictionary = {}
var carry_snapshot: Dictionary = {}
var art: Dictionary = {}
var backgrounds: Array[Texture2D] = []
var background_map: Texture2D
var terrain_mask: Image
var terrain_paths: Array = []
var rail_paths: Array = []
var fonts: Font
var title_cover: Texture2D
var crt_layer: CanvasLayer
var intro_player: Node2D
var ending_player: Node2D
var gamepad: Node
var bgm: Node
var sfx: Node
var voice: Node
var lighting: Node
var boss_warning_played := false
var enemy_patterns: RefCounted
var combat_vfx: Node2D
var powerup_burst: Node2D
var upgraded_attacks: RefCounted
var elapsed := 0.0
var visual_time := 0.0
var player := Vector2(480, 762)
var player_velocity := Vector2.ZERO
var camera_pan_x := 0.0
var player_shots: Array = []
var bullets: Array = []
var enemies: Array = []
var particles: Array = []
var explosions: Array = []
var pickups: Array = []
var decals: Array = []
var maid_remains: Array[Dictionary] = []
var maid_remains_rng := RandomNumberGenerator.new()
var popups: Array = []
var schedule: Array = []
var event_index := 0
var score := 0
var high_score := 3000000
var lives := 3
var power := 100.0
var power_level := 1
var power_pickup_count := 0
var multiplier := 1
var shot_timer := 0.0
var power_shot_timer := 0.0
var blast_timer := 0.0
var invulnerable := 2.5
var screen_flash := 0.0
var shake := 0.0
var game_state := "title"
var paused := false
var player_animation_time := 0.0
var starting_lives := 3
var boss_spawned := false
var boss_defeated := false
var boss_defeat_time := 0.0
var victory_time := 0.0
var spawned_total := 0
var destroyed_total := 0
var texture_cache: Dictionary = {}
var explosion_frames := 16
var explosion_columns := 4
var explosion_rows := 4
var explosion_duration := 1.0
var explosion_variants: Array[Dictionary] = []
var explosion_rng := RandomNumberGenerator.new()
var yusuke_shot_spec: Dictionary = {}

func _ready() -> void:
	randomize()
	explosion_rng.randomize()
	maid_remains_rng.randomize()
	bgm = BGMPlayer.new()
	add_child(bgm)
	sfx = SFXPlayer.new()
	add_child(sfx)
	voice = VoicePlayer.new()
	add_child(voice)
	gamepad = Gamepad.new()
	add_child(gamepad)
	gamepad.command.connect(_gamepad_command)
	character_index = stage_index if stage_index <= 3 else 1
	stage_spec = JSON.parse_string(FileAccess.get_file_as_string("res://data/stage_%02d.json" % stage_index))
	fonts = ThemeDB.fallback_font
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Consolas", "Courier New"])
	system_font.font_weight = 700
	system_font.font_italic = true
	fonts = system_font
	if FileAccess.file_exists("res://assets/ui/arcade.ttf"):
		fonts = load("res://assets/ui/arcade.ttf")
	_load_art()
	lighting = StageLighting.new()
	lighting.stage = self
	add_child(lighting)
	_setup_title_crt()
	var glow := ProjectileGlow.new()
	glow.stage = self
	add_child(glow)
	combat_vfx = CombatVFX.new()
	combat_vfx.stage = self
	add_child(combat_vfx)
	powerup_burst = PowerupBurst.new()
	powerup_burst.stage = self
	add_child(powerup_burst)
	upgraded_attacks = UpgradedAttacks.new(self)
	intro_player = IntroPlayer.new()
	add_child(intro_player)
	intro_player.finished.connect(_start)
	intro_player.configure(stage_spec.get("intro", {}))
	ending_player = EndingPlayer.new()
	add_child(ending_player)
	ending_player.return_requested.connect(_return_to_title)
	_build_schedule()
	_create_patterns()
	RenderingServer.set_default_clear_color(Color("05080d"))

func _load_art() -> void:
	backgrounds.clear()
	art.clear()
	texture_cache.clear()
	terrain_paths.clear()
	rail_paths.clear()
	background_map = null
	terrain_mask = null
	var background_directory: String = stage_spec.get("background_directory", "res://assets/backgrounds")
	var sprite_directory: String = stage_spec.get("sprite_directory", "res://assets/sprites")
	if ResourceLoader.exists("res://assets/ui/title_cover.png"):
		title_cover = load("res://assets/ui/title_cover.png")
	if ResourceLoader.exists(stage_spec.map):
		background_map = load(stage_spec.map)
	if ResourceLoader.exists(background_directory + "/terrain_mask.png"):
		var terrain_texture: Texture2D = load(background_directory + "/terrain_mask.png")
		terrain_mask = terrain_texture.get_image()
		if terrain_mask.is_compressed(): terrain_mask.decompress()
	if FileAccess.file_exists(background_directory + "/terrain.json"):
		var terrain_spec = JSON.parse_string(FileAccess.get_file_as_string(background_directory + "/terrain.json"))
		if terrain_spec is Dictionary:
			terrain_paths = terrain_spec.get("paths", [])
			rail_paths = terrain_spec.get("rail_paths", [])
		if stage_index >= 2 and terrain_spec is Dictionary:
			if terrain_spec.has("camera_keyframes"): stage_spec.camera = terrain_spec.camera_keyframes
			if terrain_spec.has("boss_anchor"): stage_spec.boss_anchor = terrain_spec.boss_anchor
	if stage_index == 5:
		backgrounds.append(load(background_directory + "/stage_08.png"))
	art = _read_art_manifest(sprite_directory)
	if stage_index >= 4:
		_ensure_hero_library()
		_select_character(character_index)
	for id in ["bullet_blue", "bullet_pink"]:
		var p: String = "res://assets/fx/" + id + ".png"
		if ResourceLoader.exists(p): texture_cache[id] = load(p)
	_load_explosion_art()
	yusuke_shot_spec.clear()
	var shot_manifest := "res://assets/fx/yusuke_shot_manifest.json"
	if FileAccess.file_exists(shot_manifest):
		var parsed_shot = JSON.parse_string(FileAccess.get_file_as_string(shot_manifest))
		if parsed_shot is Dictionary and ResourceLoader.exists(str(parsed_shot.get("path", ""))):
			yusuke_shot_spec = parsed_shot
			texture_cache["yusuke_shot"] = load(parsed_shot.path)

func _load_explosion_art() -> void:
	explosion_variants.clear()
	for style in ["original", "smoke", "fire"]:
		var stem: String = "explosion" if style == "original" else "explosion_" + style
		var manifest_path: String = "res://assets/fx/" + stem + "_manifest.json"
		var fx_manifest: Dictionary = {}
		if FileAccess.file_exists(manifest_path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			if parsed is Dictionary: fx_manifest = parsed
		var path: String = fx_manifest.get("path", "res://assets/fx/" + stem + "_sheet.png")
		if not ResourceLoader.exists(path): continue
		var texture_key: String = stem + "_sheet"
		texture_cache[texture_key] = load(path)
		var frames := int(fx_manifest.get("frames", 16))
		var columns := int(fx_manifest.get("columns", 4))
		var rows := int(fx_manifest.get("rows", 4))
		var duration := float(frames) / maxf(1, float(fx_manifest.get("fps", 20)))
		explosion_variants.append({"id": style, "texture_key": texture_key, "frames": frames, "columns": columns, "rows": rows, "duration": duration})
		if style == "original":
			explosion_frames = frames
			explosion_columns = columns
			explosion_rows = rows
			explosion_duration = duration

func _read_art_manifest(directory: String, heroes_only: bool = false) -> Dictionary:
	var result: Dictionary = {}
	var manifest: Dictionary = {}
	var manifest_path := directory + "/manifest.json"
	if FileAccess.file_exists(manifest_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary: manifest = parsed.get("sprites", parsed)
	for id in manifest:
		if not manifest[id] is Dictionary: continue
		if heroes_only and not (str(id).begins_with("player") or str(id).begins_with("magic")): continue
		var m: Dictionary = manifest[id]
		var path: String = m.get("path", directory + "/" + id + ".png")
		if not ResourceLoader.exists(path): path = directory + "/" + id + ".png"
		if ResourceLoader.exists(path):
			result[id] = {"texture": load(path), "hframes": int(m.get("hframes", 4)), "vframes": int(m.get("vframes", 1)), "frames": int(m.get("frames", 4)), "fps": float(m.get("fps", 9)), "display_height": float(m.get("display_height", 0)), "baked_ground_shadow": bool(m.get("baked_ground_shadow", false)), "muzzles": m.get("muzzles", {}), "loop": m.get("loop", true)}
	return result

func _ensure_hero_library() -> void:
	if not hero_library.is_empty(): return
	for index in range(1, 4):
		hero_library[index] = _read_art_manifest(HERO_DIRECTORIES[index - 1], true)
		var path: String = "res://assets/ui/portraits/" + ["yusuke", "jb", "irori"][index - 1] + ".png"
		hero_portraits.append(load(path) if ResourceLoader.exists(path) else null)

func _select_character(index: int) -> void:
	if game_state == "character_select" and clampi(index, 1, 3) != character_index: sfx.play_ui("ui_move")
	if upgraded_attacks: upgraded_attacks.clear()
	if combat_vfx: combat_vfx.clear()
	if powerup_burst: powerup_burst.clear()
	character_index = clampi(index, 1, 3)
	_ensure_hero_library()
	for id in art.keys():
		if str(id).begins_with("player") or str(id).begins_with("magic"): art.erase(id)
	for id in hero_library[character_index]:
		art[id] = hero_library[character_index][id].duplicate()
		if stage_index >= 4: art[id].fps *= 1.12
	player_animation_time = 0
	queue_redraw()

func _begin_character_select() -> void:
	_reset_horizontal_camera()
	voice.reset()
	sfx.reset_world()
	gamepad.clear_feedback()
	game_state = "character_select"
	paused = false
	elapsed = 0
	_select_character(character_index)
	queue_redraw()

func _setup_title_crt() -> void:
	crt_layer = CanvasLayer.new()
	crt_layer.layer = 30
	add_child(crt_layer)
	var overlay := ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://shaders/title_crt.gdshader")
	overlay.material = shader_material
	crt_layer.add_child(overlay)

func _build_schedule() -> void:
	schedule.clear()
	if stage_index >= 2:
		var path := "res://data/stage%d_encounters.json" % stage_index
		if FileAccess.file_exists(path):
			var contents = JSON.parse_string(FileAccess.get_file_as_string(path))
			var events: Array = contents.get("events", []) if contents is Dictionary else contents
			for event in events:
				_event(float(event.time), str(event.kind), float(event.x), float(event.get("y", -120)), int(event.get("variant", 0)))
			schedule.sort_custom(func(a, b): return a.time < b.time)
		return

	for t in range(2, 38, 4):
		for j in range(3): _event(t + j * 0.38, "drone", 130 + fmod(t * 41 + j * 210, 710), -100, j)
	for t in [10, 20, 31]:
		_event(t, "tank", 185, -90, 0)
		_event(t + 0.8, "tank", 765, -90, 1)
	for t in range(7, 40, 6):
		for j in range(4): _event(t + j * 0.22, "soldier", 200 + j * 175, -55, j)
	_event(36, "midboss", 480, -350, 0)
	for t in range(61, 105, 5):
		_event(t, "tank", 155 + fmod(t * 47, 650), -100, t % 2)
		for j in range(3): _event(t + 1 + j * 0.4, "drone", 140 + j * 310, -85, j)
	for t in range(74, 121, 5):
		for j in range(5): _event(t + j * 0.17, "soldier", 120 + j * 180, -50, j)
	for t in [109, 114, 119]:
		_event(t, "tank", 220, -90, 0)
		_event(t + 0.5, "tank", 740, -90, 1)
	_event(120, "boss", 480, -180, 0)
	schedule.sort_custom(func(a, b): return a.time < b.time)

func _event(t: float, kind: String, x: float, y: float, variant: int) -> void:
	schedule.append({"time": t, "kind": kind, "p": Vector2(x, y), "variant": variant})

func _create_patterns() -> void:
	var script_path: String = stage_spec.get("patterns", "res://scripts/enemy_patterns.gd")
	enemy_patterns = load(script_path).new(self) if ResourceLoader.exists(script_path) else EnemyPatterns.new(self)

func _select_stage(index: int) -> void:
	_reset_horizontal_camera()
	voice.reset()
	if game_state == "title" and clampi(index, 1, CHAPTER_COUNT) != stage_index: sfx.play_ui("ui_move")
	sfx.reset_world()
	boss_warning_played = false
	gamepad.clear_feedback()
	shake = 0
	if ending_player: ending_player.stop()
	if upgraded_attacks: upgraded_attacks.clear()
	if combat_vfx: combat_vfx.clear()
	if powerup_burst: powerup_burst.clear()
	stage_index = clampi(index, 1, CHAPTER_COUNT)
	if stage_index <= 3: character_index = stage_index
	stage_spec = JSON.parse_string(FileAccess.get_file_as_string("res://data/stage_%02d.json" % stage_index))
	_load_art()
	_build_schedule()
	_create_patterns()
	intro_player.configure(stage_spec.get("intro", {}))
	elapsed = 0
	enemies.clear()
	bullets.clear()
	player_shots.clear()
	explosions.clear()
	decals.clear()
	maid_remains.clear()
	pickups.clear()
	popups.clear()
	particles.clear()
	boss_spawned = false
	boss_defeated = false
	queue_redraw()

func _advance_stage() -> void:
	if voice.is_narrative_busy(): return
	carry_snapshot = {"score": score, "power": power}
	_select_stage(mini(stage_index + 1, CHAPTER_COUNT))
	_begin_intro()

func _start() -> void:
	_reset_horizontal_camera()
	voice.reset()
	var confirming_character := game_state == "character_select"
	sfx.reset_world()
	if confirming_character: sfx.play_ui("ui_confirm")
	boss_warning_played = false
	bgm.reset()
	gamepad.clear_feedback()
	shake = 0
	screen_flash = 0
	if ending_player: ending_player.stop()
	if enemy_patterns: enemy_patterns.clear()
	if upgraded_attacks: upgraded_attacks.clear()
	if combat_vfx: combat_vfx.clear()
	if powerup_burst: powerup_burst.clear()
	elapsed = 0
	player = Vector2(480, 762)
	player_velocity = Vector2.ZERO
	player_shots.clear()
	bullets.clear()
	enemies.clear()
	particles.clear()
	explosions.clear()
	pickups.clear()
	decals.clear()
	maid_remains.clear()
	popups.clear()
	event_index = 0
	score = 0
	lives = starting_lives
	power = 100
	power_level = 1 if stage_index == 1 else 3
	power_pickup_count = 0
	invulnerable = 2.5
	boss_spawned = false
	boss_defeated = false
	boss_defeat_time = 0
	victory_time = 0
	shot_timer = 0
	power_shot_timer = 0
	player_animation_time = 0
	blast_timer = 0
	spawned_total = 0
	destroyed_total = 0
	paused = false
	game_state = "playing"
	if not carry_snapshot.is_empty():
		score = int(carry_snapshot.score)
		power = float(carry_snapshot.power)
		carry_snapshot.clear()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	if game_state == "intro":
		return
	if game_state == "ending":
		if event.keycode == KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
			ending_player.request_return()
		return
	if paused and game_state in ["victory", "gameover"] and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
		_set_paused(false)
		return
	if game_state == "character_select":
		match event.keycode:
			KEY_LEFT, KEY_A: _select_character(posmod(character_index - 2, 3) + 1)
			KEY_RIGHT, KEY_D: _select_character(character_index % 3 + 1)
			KEY_1, KEY_2, KEY_3: _select_character(event.keycode - KEY_1 + 1)
			KEY_ENTER, KEY_SPACE, KEY_Z: _start()
			KEY_ESCAPE: _leave_character_select()
			KEY_F11:
				var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	match event.keycode:
		KEY_ENTER, KEY_SPACE:
			if game_state == "title": _begin_intro()
			elif game_state == "victory" and stage_index < CHAPTER_COUNT: _advance_stage()
			elif game_state != "playing":
				if stage_index >= 4: _begin_character_select()
				else: _start()
		KEY_LEFT, KEY_RIGHT:
			if game_state == "title": _select_stage(posmod(stage_index - 1 + (1 if event.keycode == KEY_RIGHT else -1), CHAPTER_COUNT) + 1)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			if game_state == "title": _select_stage(event.keycode - KEY_1 + 1)
		KEY_ESCAPE:
			if game_state == "playing" or (game_state in ["victory", "gameover"] and voice.has_active_voice()): _set_paused(not paused)
		KEY_R:
			if stage_index >= 4: _begin_character_select()
			else: _start()
		KEY_X:
			if game_state == "playing" and not paused: _bomb()
		KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _set_paused(value: bool) -> void:
	if value != paused: sfx.play_ui("pause" if value else "resume")
	paused = value
	sfx.set_world_paused(value)
	voice.set_paused(value)
	if paused:
		gamepad.clear_feedback()
		shake = 0

func _gamepad_command(action: String) -> void:
	if action in ["focus_lost", "disconnected"]:
		if game_state == "playing" or (game_state in ["victory", "gameover"] and voice.has_active_voice()): _set_paused(true)
		return
	if game_state == "intro": return
	if game_state == "ending":
		if action in ["fire", "bomb", "pause"]: ending_player.request_return()
		return
	if paused and game_state in ["victory", "gameover"] and action in ["fire", "bomb", "pause"]:
		_set_paused(false)
		return
	if game_state == "victory" and action == "pause" and voice.is_narrative_busy():
		_set_paused(true)
		return
	if game_state == "title":
		if action in ["left", "right"]: _select_stage(posmod(stage_index - 1 + (1 if action == "right" else -1), CHAPTER_COUNT) + 1)
		elif action in ["fire", "pause"]: _begin_intro()
	elif game_state == "character_select":
		if action in ["left", "right"]: _select_character(posmod(character_index - 1 + (1 if action == "right" else -1), 3) + 1)
		elif action in ["fire", "pause"]: _start()
		elif action == "bomb": _leave_character_select()
	elif game_state == "playing":
		if action == "pause": _set_paused(not paused)
		elif paused:
			if action in ["fire", "bomb"]: _set_paused(false)
			elif action == "restart":
				if stage_index >= 4: _begin_character_select()
				else: _start()
		elif action == "bomb": _bomb()
	elif game_state in ["victory", "gameover"] and action in ["fire", "pause"]:
		if game_state == "victory" and stage_index < CHAPTER_COUNT: _advance_stage()
		elif stage_index >= 4: _begin_character_select()
		else: _start()

func _begin_intro() -> void:
	_reset_horizontal_camera()
	voice.reset()
	if game_state == "title": sfx.play_ui("coin")
	sfx.reset_world()
	gamepad.clear_feedback()
	if stage_index >= 4:
		_begin_character_select()
		return
	game_state = "intro"
	if not intro_player.begin(): _start()

func _begin_ending() -> void:
	_reset_horizontal_camera()
	voice.reset()
	sfx.reset_world()
	gamepad.clear_feedback()
	paused = false
	player_shots.clear()
	bullets.clear()
	upgraded_attacks.clear()
	combat_vfx.clear()
	if enemy_patterns: enemy_patterns.clear()
	game_state = "ending"
	crt_layer.visible = false
	if not ending_player.begin(): game_state = "victory"
	queue_redraw()

func _return_to_title() -> void:
	voice.reset()
	sfx.play_ui("ui_cancel")
	sfx.reset_world()
	ending_player.stop()
	carry_snapshot.clear()
	paused = false
	_select_stage(1)
	game_state = "title"
	visual_time = 0.0
	crt_layer.visible = true
	get_window().title = str(ProjectSettings.get_setting("application/config/name"))
	queue_redraw()

func _leave_character_select() -> void:
	voice.reset()
	sfx.reset_world()
	sfx.play_ui("ui_cancel")
	paused = false
	game_state = "title"
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if game_state == "title" and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if Rect2(220, 750, 520, 80).has_point(point):
			_begin_intro()
			get_viewport().set_input_as_handled()
		return
	if game_state != "character_select": return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		for index in range(3):
			if CharacterSelect.card_rect(index).has_point(point):
				_select_character(index + 1)
				return
		if CharacterSelect.confirm_rect().has_point(point): _start()

func _process(dt: float) -> void:
	bgm.sync(game_state, stage_index, boss_spawned, boss_defeated, paused)
	sfx.set_world_paused(paused)
	voice.set_paused(paused)
	gamepad.advance_feedback(minf(dt, 0.1), not paused and game_state in ["playing", "gameover", "victory"], shake if game_state == "playing" else 0.0)
	if game_state == "ending": ending_player.return_button.text = "返回主标题  /  A" if gamepad.using_gamepad else "返回主标题  /  ENTER"
	visual_time += minf(dt, 0.1)
	crt_layer.visible = game_state in ["title", "intro", "character_select"]
	if game_state in ["title", "intro", "character_select", "ending"]:
		queue_redraw()
		return
	if paused:
		queue_redraw()
		return
	_simulate(minf(dt, 0.05))
	queue_redraw()

func _simulate(dt: float) -> void:
	if game_state == "ending": return
	if game_state == "gameover":
		_update_effects(dt)
		return
	if game_state == "victory":
		victory_time += dt
		_update_effects(dt)
		if stage_index < CHAPTER_COUNT and victory_time >= 4.0: _advance_stage()
		return
	elapsed += enemy_patterns.clock_step(dt) if stage_index == 5 else dt
	if not boss_warning_played and elapsed >= float(stage_spec.boss_time) - 3.0:
		boss_warning_played = true
		sfx.play_cue("boss_warning", Vector2(480, 400))
	invulnerable = maxf(0, invulnerable - dt)
	screen_flash = maxf(0, screen_flash - dt * 3)
	shake = maxf(0, shake - dt * 22)
	shot_timer -= dt
	power_shot_timer -= dt
	blast_timer = maxf(0, blast_timer - dt)
	power = minf(100, power + dt * 1.6)
	_update_player(dt)
	while event_index < schedule.size() and schedule[event_index].time <= elapsed:
		_spawn(schedule[event_index])
		event_index += 1
	_update_enemies(dt)
	enemy_patterns.update(dt)
	_update_projectiles(dt)
	upgraded_attacks.update(dt)
	_update_pickups(dt)
	_update_effects(dt)
	if boss_defeated and elapsed > float(stage_spec.boss_time) + 4 and explosions.is_empty() and (stage_index != 5 or elapsed > boss_defeat_time + 1.2):
		game_state = "victory"
		high_score = maxi(high_score, score)
		if stage_index == CHAPTER_COUNT: _begin_ending()
func _update_player(dt: float) -> void:
	var movement := Vector2.ZERO
	var focused := _focus_held()
	var cadence := 0.87 if stage_index >= 4 else 1.0
	var coverage := 1.10 if stage_index >= 4 else 1.0
	movement.x = float(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A))
	movement.y = float(Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W))
	movement = (movement.normalized() + gamepad.movement()).limit_length(1.0)
	player_velocity = movement * (185 if focused else 410)
	player += player_velocity * dt
	_update_horizontal_camera(dt)

	player.x = clampf(player.x, 28 + camera_pan_x, W - 28 + camera_pan_x)
	player.y = clampf(player.y, PLAY_TOP + 40, PLAY_BOTTOM - 20)
	if _is_firing(): player_animation_time += dt
	else: player_animation_time = 0
	if shot_timer <= 0 and _primary_firing():
		sfx.play_cue("shot_%d" % character_index, player, 1.04 if focused else 1.0)
		if character_index == 3:
			shot_timer = (0.12 if focused else 0.14) * cadence
			Stage3Weapons.emit(self, focused)
		elif character_index == 2:
			shot_timer = (0.11 if focused else 0.15) * cadence
			_emit_magic(focused)
		else:
			shot_timer = (0.075 if focused else 0.09) * cadence
			for k in _primary_shot_lanes(focused):
				var spread: float = k * (12 if focused else 33) * coverage
				player_shots.append({"p": player + Vector2(k * 10, -33), "v": Vector2(spread * 3.2, -1120), "age": 0.0, "damage": (5.0 + power_level * 1.2) * 1.15, "upgraded": stage_index >= 4})
	if _power_held() and blast_timer <= 0 and power > 2:
		power -= dt * 27
		if character_index == 3:
			if power_shot_timer <= 0:
				power_shot_timer = 0.19 * cadence
				sfx.play_cue("power_3", player)
				Stage3Weapons.emit(self, true, true)
		elif character_index == 2:
			if power_shot_timer <= 0:
				power_shot_timer = 0.1 * cadence
				sfx.play_cue("power_2", player)
				_emit_magic(true, true)
		else:
			for e in enemies:
				var impact := _power_lane_hit_point(e, 84 * coverage)
				if e.hp > 0 and impact != Vector2.INF:
					var before: float = e.hp
					_damage_enemy(e, dt * 190)
					if e.hp < before and power_shot_timer <= 0: combat_vfx.impact(impact, 1)
			if power_shot_timer <= 0:
				power_shot_timer = 0.08
				sfx.play_cue("power_1", player)
	elif _power_held() and power <= 2:
		sfx.play_cue("energy_empty", player)

func _primary_shot_lanes(focused: bool = false) -> Array[float]:
	var count := clampi(power_level, 1, 5) + 1
	if stage_index >= 4:
		count = 3 if character_index == 2 and focused else clampi(power_level, 1, 5) + 2
	var lanes: Array[float] = []
	for index in range(count): lanes.append(float(index) - float(count - 1) * 0.5)
	return lanes

func _emit_magic(focused: bool, charged: bool = false) -> void:
	var lanes := _primary_shot_lanes(focused)
	if charged: lanes = [-1.0, 0.0, 1.0]
	for lane in lanes:
		var angle := -PI * 0.5 + lane * (0.045 if focused else 0.16) * (1.10 if stage_index >= 4 else 1.0)
		var velocity := Vector2.from_angle(angle) * (850 if focused else 710)
		player_shots.append({"p": player + Vector2(lane * 10, -24), "v": velocity, "age": 0.0, "damage": (28.0 if charged else (11.0 + power_level * 1.7) * 1.15), "kind": "magic", "focused": focused, "radius": 17.0, "phase": lane * 0.8, "upgraded": stage_index >= 4})

func _primary_firing() -> bool:
	return Input.is_physical_key_pressed(KEY_Z) or Input.is_physical_key_pressed(KEY_SPACE) or gamepad.held("fire")

func _focus_held() -> bool:
	return Input.is_physical_key_pressed(KEY_SHIFT) or gamepad.held("focus")

func _power_held() -> bool:
	return Input.is_physical_key_pressed(KEY_C) or gamepad.held("power")

func _is_firing() -> bool:
	return _primary_firing() or (_power_held() and power > 2)

func _spawn(event: Dictionary) -> void:
	var kind: String = event.kind
	var ground: bool = kind in stage_spec.get("ground_kinds", ["tank", "soldier", "turret", "rail_fortress"]) or (stage_index == 3 and kind == "midboss")
	var world_position := Vector2.ZERO
	if ground:
		world_position = _ground_spawn_position(kind, event.p.x)
		if world_position == Vector2.INF:

			if kind == "tank" and stage_index != 5:
				kind = "drone"
				ground = false
			else:
				return
	var stats := {"soldier": [17.0, 135.0, 19.0], "drone": [54.0, 106.0, 39.0], "tank": [190.0, 57.0, 47.0], "midboss": [7600.0, 65.0, 132.0], "boss": [11500.0, 70.0, 65.0]}
	if stage_index >= 2: stats = stage_spec.enemy_stats
	var s: Array = stats[kind]
	var position: Vector2 = _world_to_screen(world_position) - Vector2(0, 35 if _ground_role(kind) == "soldier" else 20) if ground else event.p
	enemies.append({"kind": kind, "ground": ground, "wp": world_position, "route": _ground_route(world_position, kind) if ground else [], "p": position, "origin_x": position.x, "hp": s[0], "max_hp": s[0], "speed": s[1], "radius": s[2], "age": 0.0, "shot": 1.2 + event.variant * 0.16, "pattern": 0, "hit": 0.0, "variant": event.variant})
	enemies.back()["uid"] = spawned_total + 1
	if stage_index == 5: enemy_patterns.prepare_enemy(enemies.back())
	if stage_index == 2 and kind == "boss":
		var fortress: Dictionary = enemies.back()
		fortress.left_alive = true
		fortress.right_alive = true
		fortress.parts = [{"id": "left", "offset": Vector2(-254, 98), "hp": 2600.0, "radius": 98.0}, {"id": "right", "offset": Vector2(254, 98), "hp": 2600.0, "radius": 98.0}]
	spawned_total += 1
	if event.kind == "boss":
		if not boss_warning_played:
			boss_warning_played = true
			sfx.play_cue("boss_warning", Vector2(480, 400))
		boss_spawned = true
		bullets.clear()

func _update_enemies(dt: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		e.age += dt
		e.shot -= dt
		e.hit = maxf(0, e.hit - dt * 6)
		if e.ground:
			var previous_world: Vector2 = e.wp
			_move_ground_enemy(e, dt)
			e["walking"] = e.wp.distance_squared_to(previous_world) > 0.0001
			if e.walking: e["walk_age"] = float(e.get("walk_age", 0.0)) + dt
		match ("chapter_motion" if stage_index >= 3 else e.kind):
			"chapter_motion":
				enemy_patterns.move_enemy(e, dt)
			"drone":
				e.p.y += e.speed * dt
				e.p.x = clampf(e.origin_x + sin(e.age * 1.65) * 83, 55, 905)
			"soldier":
				pass
			"tank":
				pass
			"turret":
				pass
			"esper":
				e.p.y += dt * (e.speed if e.age < 2.8 or e.age > 8 else 12.0)
				e.p.x = e.origin_x + sin(e.age * 1.1 + e.variant) * 52
			"midboss":
				if stage_index == 2:
					e.p.x = clampf(e.origin_x + sin(e.age * 0.65) * 68, 160, 800)
					if e.age < 12: e.p.y = move_toward(e.p.y, 275 + int(e.variant) % 2 * 105, dt * e.speed)
					else: e.p.y += dt * e.speed
				else:

					e.wp = Vector2(500 + sin(e.age * 0.63) * 28, 3380 + sin(e.age * 0.35) * 10)
					e.p = _world_to_screen(e.wp)
			"boss":
				if stage_index == 2:
					var anchor: Array = stage_spec.get("boss_anchor", [512, 340])
					e.wp = Vector2(float(anchor[0]) + sin(e.age * 0.35) * 9, float(anchor[1]))
					e.p = e.p.move_toward(_world_to_screen(e.wp), dt * 150)
				else:
					e.p.y = move_toward(e.p.y, 230 + sin(e.age * 0.53) * 55, dt * 150)
					e.p.x = 480 + sin(e.age * 0.72) * 235
		var allowed_to_fire: bool = not (stage_index == 1 and e.kind == "midboss" and elapsed < 45) and not (stage_index >= 2 and e.kind == "boss" and elapsed < float(stage_spec.get("boss_attack_time", 104)))
		if stage_index == 5: allowed_to_fire = allowed_to_fire and enemy_patterns.can_damage(e)
		if e.shot <= 0 and e.p.y > 50 and e.p.y < 760 and allowed_to_fire:
			_fire_enemy(e)
		if e.hp <= 0:
			if stage_index == 5 and enemy_patterns.handle_defeat(e): continue
			_destroy_enemy(e)
			enemies.remove_at(i)
		elif e.p.y > 1040 and not (stage_index >= 4 and e.kind == "boss" and e.age < 8):
			enemies.remove_at(i)

func _fire_enemy(e: Dictionary) -> void:
	enemy_patterns.fire(e)

func _bullet(origin: Vector2, angle: float, speed: float, kind: int, shape: String = "drop", visual_scale: float = 1.0) -> void:
	if bullets.size() > 1800: return
	bullets.append({"p": origin, "v": Vector2.from_angle(angle) * speed, "kind": kind, "shape": shape, "visual_scale": visual_scale, "phase": bullets.size() * 0.73 + elapsed * 2.1, "age": 0.0, "grazed": false})

func _damage_enemy(enemy: Dictionary, amount: float) -> void:
	if stage_index == 1 and enemy.kind == "midboss" and elapsed < 45: return
	if stage_index >= 2 and enemy.kind == "boss" and elapsed < float(stage_spec.get("boss_attack_time", 104)): return
	if stage_index == 5 and not enemy_patterns.can_damage(enemy): return
	enemy.hp -= amount
	enemy.hit = 0.32
	if stage_index == 3 and enemy.kind == "boss" and not enemy.get("nose_broken", false) and enemy.age >= 35 and float(enemy.hp) / float(enemy.max_hp) < 0.45:
		sfx.play_cue("boss_transform", enemy.p)
		enemy.nose_broken = true
		_explode(enemy.p + Vector2(0, 120), 1.4)
		_spark(enemy.p + Vector2(0, 100), Color("b1ffea"), 30, 180)
	if stage_index == 2 and enemy.kind == "boss":
		for part in enemy.parts:
			var threshold := 0.63 if part.id == "left" else 0.43
			if part.hp <= 0 or float(enemy.hp) / float(enemy.max_hp) < threshold: _break_fortress_part(enemy, part)

func _break_fortress_part(enemy: Dictionary, part: Dictionary) -> void:
	var flag: String = part.id + "_alive"
	if not enemy.get(flag, false): return
	part.hp = 0
	enemy[flag] = false
	_explode(enemy.p + part.offset, 1.65, 0, true)
	_spark(enemy.p + part.offset, GOLD, 32, 260)
	shake = maxf(shake, 7)

func _background_display_width() -> float:
	var source_width := MAP_VIEW_SIZE
	if background_map: source_width = float(background_map.get_width())
	elif not backgrounds.is_empty(): source_width = float(backgrounds[0].get_width())
	return source_width * W / MAP_VIEW_SIZE

func _horizontal_camera_limit() -> float:
	return minf(CAMERA_PAN_MAX, maxf(0.0, (_background_display_width() - W) * 0.5))

func _reset_horizontal_camera() -> void:
	camera_pan_x = 0.0
	position = Vector2.ZERO

func _update_horizontal_camera(dt: float) -> void:
	var limit := _horizontal_camera_limit()
	var visible_x := player.x - camera_pan_x
	var left_edge := W * CAMERA_EDGE_ZONE
	var right_edge := W - left_edge
	var target := 0.0

	if visible_x < left_edge:
		target = -limit * clampf((left_edge - visible_x) / (left_edge - 28), 0.0, 1.0)
	elif visible_x > right_edge:
		target = limit * clampf((visible_x - right_edge) / (W - 28 - right_edge), 0.0, 1.0)
	camera_pan_x = lerpf(camera_pan_x, target, 1.0 - exp(-CAMERA_FOLLOW_SPEED * dt))
	if absf(camera_pan_x - target) < 0.001: camera_pan_x = target

	position = Vector2(-camera_pan_x, 0)

func _camera_y() -> float:
	var checkpoints: Array = stage_spec.get("camera", [])
	for k in range(checkpoints.size() - 1):
		var a := Vector2(float(checkpoints[k][0]), float(checkpoints[k][1]))
		var b := Vector2(float(checkpoints[k + 1][0]), float(checkpoints[k + 1][1]))
		if elapsed >= a.x and elapsed < b.x:
			return lerpf(a.y, b.y, (elapsed - a.x) / (b.x - a.x))
	if checkpoints.is_empty() and background_map:
		return maxf(0, background_map.get_height() - 1024) * (1.0 - clampf(elapsed / float(stage_spec.boss_time), 0, 1))
	return 0.0

func _screen_to_world(point: Vector2) -> Vector2:

	var width := _background_display_width()
	return Vector2((point.x - (W - width) * 0.5) * MAP_VIEW_SIZE / width, point.y * MAP_VIEW_SIZE / W + _camera_y())

func _world_to_screen(point: Vector2) -> Vector2:
	var width := _background_display_width()
	return Vector2(point.x * width / MAP_VIEW_SIZE + (W - width) * 0.5, (point.y - _camera_y()) * W / MAP_VIEW_SIZE)

func _terrain_allows(point: Vector2, kind: String) -> bool:
	if terrain_mask == null: return false
	var role := _ground_role(kind)
	var footprint := Vector2(90, 65) if role == "midboss" else (Vector2(57, 39) if role == "tank" else (Vector2(35, 25) if role == "turret" else Vector2(16, 14)))
	if kind == "rail_fortress": footprint = Vector2(90, 140)
	var configured: Array = stage_spec.get("footprints", {}).get(kind, [])
	if configured.size() == 2: footprint = Vector2(configured[0], configured[1])
	for offset in [Vector2.ZERO, Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]:
		var p: Vector2 = point + offset * footprint
		if p.x < 0 or p.y < 0 or p.x >= terrain_mask.get_width() or p.y >= terrain_mask.get_height(): return false
		var pixel := terrain_mask.get_pixel(int(p.x), int(p.y))
		if (pixel.r if role in ["tank", "midboss", "rail_fortress"] else pixel.g) < 0.75: return false
	return true

func _ground_role(kind: String) -> String:
	return str(stage_spec.get("ground_roles", {}).get(kind, kind))

func _ground_spawn_position(kind: String, preferred_x: float) -> Vector2:
	if kind == "rail_fortress": return enemy_patterns.rail_spawn(preferred_x)
	var role := _ground_role(kind)
	var y := -145.0 if role == "midboss" else (-105.0 if role == "tank" else -58.0)
	var separation := 165.0 if role == "midboss" else (105.0 if role == "tank" else 47.0)
	var spawn_rows: Array[float] = [y]
	if stage_index == 5 and kind == "maid":
		separation *= float(stage_spec.get("maid_scale", 1.0))

		spawn_rows.append_array([y - 20.0, y + 20.0, y - 40.0, y + 40.0])
	for entry_y in spawn_rows:
		var closest := Vector2.INF
		var best := INF
		for x in range(65, 960, 20):
			var world := _screen_to_world(Vector2(x, entry_y))
			if not _terrain_allows(world, kind): continue
			var occupied := false
			for e in enemies:
				if e.ground and e.wp.distance_to(world) < separation:
					occupied = true
					break
			if occupied: continue
			var cost := absf(x - preferred_x)
			if cost < best:
				closest = world
				best = cost
		if closest != Vector2.INF: return closest
	return Vector2.INF

func _move_ground_enemy(e: Dictionary, dt: float) -> void:
	if e.kind == "rail_fortress":
		enemy_patterns.move_rail(e, dt)
		return
	var side := 1.0 if int(e.variant) % 2 == 0 else -1.0
	var role := _ground_role(e.kind)
	var speed := 46.0 if role == "soldier" else (0.0 if role == "turret" else 21.0)
	var choices := [Vector2(0, 1), Vector2(side * 0.5, 0.85), Vector2(-side * 0.5, 0.85), Vector2(side, 0), Vector2(-side, 0)]

	while not e.route.is_empty() and e.wp.distance_to(e.route[0]) < 12:
		e.route.pop_front()
		e["ground_heading"] = Vector2.ZERO
	if not e.route.is_empty():
		var waypoint: Vector2 = e.route[0]
		choices.push_front((waypoint - e.wp).normalized())
	var heading: Vector2 = e.get("ground_heading", Vector2.ZERO)
	for direction in choices:

		if heading != Vector2.ZERO and direction.dot(heading) < -0.05: continue
		var candidate: Vector2 = e.wp + direction * speed * dt

		if _terrain_allows(candidate, e.kind) and _terrain_allows(candidate + direction * 16, e.kind):
			e.wp = candidate
			if speed > 0 and dt > 0: e["ground_heading"] = direction.normalized()
			break
	e.p = _world_to_screen(e.wp) - Vector2(0, 35 if role == "soldier" else 20)

func _ground_route(position: Vector2, kind: String) -> Array:
	var nearest_distance := 95.0
	var route: Array = []
	var role := _ground_role(kind)
	for path in terrain_paths:
		if path.kind != ("tank" if role == "midboss" else role): continue
		var points: Array = path.points
		var forward: bool = float(points.back()[1]) >= float(points.front()[1])
		for i in range(points.size() - 1):
			var a := Vector2(points[i][0], points[i][1])
			var b := Vector2(points[i + 1][0], points[i + 1][1])
			var nearest := Geometry2D.get_closest_point_to_segment(position, a, b)
			var distance := position.distance_to(nearest)
			if distance < nearest_distance:
				nearest_distance = distance
				route.clear()
				route.append(nearest)
				var indices := range(i + 1, points.size()) if forward else range(i, -1, -1)
				for j in indices: route.append(Vector2(points[j][0], points[j][1]))
	return route

func _update_projectiles(dt: float) -> void:
	for i in range(player_shots.size() - 1, -1, -1):
		var b: Dictionary = player_shots[i]
		var previous: Vector2 = b.p
		b.p += b.v * dt
		b.age += dt
		if character_index == 3: Stage3Weapons.update_shot(b, dt)
		var hit := false
		for e in enemies:
			if e.hp <= 0: continue
			var contact := _projectile_contact(e, previous, b.p, float(b.get("radius", 10)))
			if stage_index == 2 and e.kind == "boss":
				contact = b.p.distance_squared_to(e.p) < pow(170 + float(b.get("radius", 10)), 2)
				for part in e.parts:
					if part.hp > 0 and b.p.distance_squared_to(e.p + part.offset) < pow(part.radius + float(b.get("radius", 10)), 2): contact = true
			if contact:
				if stage_index == 2 and e.kind == "boss":
					for part in e.parts:
						if elapsed >= float(stage_spec.get("boss_attack_time", 104)) and part.hp > 0 and b.p.distance_squared_to(e.p + part.offset) < pow(part.radius + float(b.get("radius", 10)), 2): part.hp -= b.damage
				var before: float = e.hp
				_damage_enemy(e, b.damage)
				if e.hp < before:
					var point := _hit_point(e, b.p)
					combat_vfx.impact(point, character_index)
					if b.get("kind", "") == "spirit_orb": Stage3Weapons.impact(self, point)
				hit = true
				break
		if hit or b.p.y < -50 or b.p.x < -50 or b.p.x > 1010: player_shots.remove_at(i)
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b.p += b.v * dt
		b.age += dt
		var distance: float = b.p.distance_squared_to(player + Vector2(0, -4))
		if distance < 24 * 24 and not b.grazed:
			b.grazed = true
			score += 20
			power = minf(100, power + 0.2)
		if distance < 8 * 8 and invulnerable <= 0:
			_hit_player()
			bullets.remove_at(i)
		elif b.p.x < -80 or b.p.x > 1040 or b.p.y < -80 or b.p.y > 1020 or b.age > 12:
			bullets.remove_at(i)

func _hit_point(enemy: Dictionary, shot_position: Vector2) -> Vector2:
	if stage_index == 5 and enemy.kind == "gate_keeper":
		return enemy_patterns.gate_hit_point(enemy, shot_position)
	if enemy.has("hit_ellipse"):
		var relative: Vector2 = (shot_position - enemy.p) / enemy.hit_ellipse
		return enemy.p + relative.limit_length(0.94) * enemy.hit_ellipse
	return enemy.p + (shot_position - enemy.p).limit_length(float(enemy.radius) * 0.65)

func _projectile_contact(enemy: Dictionary, previous: Vector2, current: Vector2, radius: float) -> bool:
	if stage_index == 5 and enemy.kind == "gate_keeper":
		return enemy_patterns.gate_hit_test(enemy, previous, current, radius)
	if enemy.has("hit_ellipse"):
		var bounds: Vector2 = enemy.hit_ellipse + Vector2.ONE * radius
		return Geometry2D.get_closest_point_to_segment(Vector2.ZERO, (previous - enemy.p) / bounds, (current - enemy.p) / bounds).length_squared() <= 1.0
	return Geometry2D.get_closest_point_to_segment(enemy.p, previous, current).distance_squared_to(enemy.p) <= pow(float(enemy.radius) + radius, 2)

func _enemy_target_position(enemy: Dictionary, origin: Vector2) -> Vector2:
	if stage_index == 5 and enemy.kind == "gate_keeper":
		return enemy_patterns.gate_target_position(enemy, origin)
	return enemy.p

func _enemy_in_power_lane(enemy: Dictionary, half_width: float) -> bool:
	return _power_lane_hit_point(enemy, half_width) != Vector2.INF

func _power_lane_hit_point(enemy: Dictionary, half_width: float) -> Vector2:
	if stage_index == 5 and enemy.kind == "gate_keeper":
		var nearest := Vector2.INF
		var distance := INF
		for body in enemy_patterns.gate_bodies(enemy):
			if absf(body.p.x - player.x) >= half_width or body.p.y >= player.y: continue
			var relative: Vector2 = (player - body.p) / body.hit_ellipse
			var point: Vector2 = body.p + relative.limit_length(0.94) * body.hit_ellipse
			var candidate := point.distance_squared_to(player)
			if candidate < distance:
				distance = candidate
				nearest = point
		return nearest
	if absf(enemy.p.x - player.x) < half_width and enemy.p.y < player.y: return _hit_point(enemy, player)
	return Vector2.INF

func _hit_player() -> void:
	gamepad.pulse("hit")
	lives -= 1
	if lives <= 0: sfx.reset_world()
	sfx.play_cue("player_down" if lives <= 0 else "player_hurt", player)
	voice.play_hurt(character_index)
	invulnerable = 3
	screen_flash = 0.6
	shake = 10
	_explode(player, 0.7)
	power_level = maxi(1, power_level - 1)
	if lives <= 0: game_state = "gameover"

func _bomb() -> void:
	if power < 35:
		sfx.play_cue("energy_empty", player)
		return
	sfx.play_cue("bomb", player)
	gamepad.pulse("bomb")
	power -= 35
	blast_timer = 1.3
	invulnerable = 2
	screen_flash = 0.8
	shake = 15
	for b in bullets:
		if randf() < 0.3: _spark(b.p, GOLD, 1, 60)
		score += 10
	bullets.clear()
	enemy_patterns.clear()
	for e in enemies:
		_damage_enemy(e, 650)
	if character_index == 3:
		Stage3Weapons.impact(self, player)
		_spark(player, Color("b0ffde"), 42, 320)
	else:
		_explode(player, 2.8)

func _destroy_enemy(e: Dictionary) -> void:
	if stage_index == 5 and e.kind == "maid":
		voice.play_maid_death()
		var foot := _world_to_screen(e.wp)
		var pose_count := maxi(1, int(art.get("maid_defeated", {}).get("frames", 4)))
		maid_remains.append({"wp": e.wp, "pose": maid_remains_rng.randi_range(0, pose_count - 1), "age": 0.0, "fall_height": maxf(0, foot.y - e.p.y)})
	if stage_index == 1 and e.kind == "boss" and not e.get("death_voiced", false):
		e["death_voiced"] = true
		voice.play_narrative("boss_1_death")
	destroyed_total += 1
	var large: bool = e.kind in stage_spec.get("large_enemy_kinds", ["boss", "midboss"])
	gamepad.pulse("large_enemy" if large else ("heavy_enemy" if _ground_role(e.kind) == "tank" else "enemy"))
	multiplier = mini(16, 1 + int(player_shots.size() / 13))
	var value := (25000 if large else (600 if e.kind == "tank" else 150)) * multiplier
	score += value
	popups.append({"p": e.p, "text": "×%d" % multiplier, "life": 0.9})
	if e.get("energy_defeat", false):
		sfx.play_cue("enemy_down", e.p, 0.65)
		_spark(e.p, Color("f13670"), 65, 330)
		_spark(e.p, Color("ffd7ed"), 36, 230)
	elif _ground_role(e.kind) == "soldier":
		sfx.play_cue("enemy_down", e.p)
		_spark(e.p, Color("b7243f"), 12, 125)
		_spark(e.p, Color("e96362"), 6, 85)
	else:
		_explode(e.p, 2.2 if large else (1.0 if e.kind == "tank" else 0.65), 0.0, e.ground)
	if large:
		if not e.get("energy_defeat", false):
			for j in range(10): _explode(e.p + Vector2(randf_range(-100, 100), randf_range(-90, 90)), randf_range(0.5, 1.5), j * 0.08)
		shake = 13
		screen_flash = 0.42
		for b in bullets: score += 20
		bullets.clear()
		enemy_patterns.clear()
	if e.kind == "boss":
		boss_defeated = true
		boss_defeat_time = elapsed
	if randf() < 0.48 or large:
		pickups.append({"p": e.p, "age": 0.0, "kind": 0 if randf() < 0.3 else 1})
	if _ground_role(e.kind) != "soldier" and not e.get("energy_defeat", false):
		var radius := 63.0 if large else (33.0 if e.kind == "tank" else 22.0)
		var shape := PackedVector2Array()
		var inner := PackedVector2Array()
		var embers := PackedVector2Array()
		for j in range(19):
			var direction := Vector2.from_angle(j * TAU / 19)
			shape.append(direction * radius * randf_range(0.68, 1.35))
			inner.append(direction * radius * randf_range(0.24, 0.77))
			if j % 3 == 0: embers.append(direction * radius * randf_range(0.45, 0.9))
		decals.append({"wp": e.wp if e.ground else _screen_to_world(e.p), "shape": shape, "inner": inner, "embers": embers, "life": 3.2, "max_life": 3.2})

func _collect_power_item() -> bool:
	if power_level >= 5:
		power_pickup_count = 0
		return false
	if stage_index <= 3:
		power_pickup_count += 1
		if power_pickup_count < 3: return false
		power_pickup_count = 0
	power_level = mini(5, power_level + 1)
	return true

func _update_pickups(dt: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var p: Dictionary = pickups[i]
		p.age += dt
		p.p.y += dt * 65
		if player.distance_to(p.p) < 140:
			p.p = p.p.move_toward(player, dt * 450)
		if player.distance_to(p.p) < 35:
			power = minf(100, power + 8)
			var upgraded := _collect_power_item() if p.kind == 0 else false
			sfx.play_cue("pickup", p.p)
			if upgraded:
				if stage_index <= 3:
					sfx.play_cue("powerup_early", p.p)
					powerup_burst.trigger()
				else:
					sfx.play_cue("powerup", p.p)
			score += 1000
			_spark(p.p, GOLD, 12, 130)
			pickups.remove_at(i)
		elif p.p.y > 1000: pickups.remove_at(i)

func _spark(p: Vector2, color: Color, count: int, speed: float) -> void:
	for j in range(count):
		particles.append({"p": p, "v": Vector2.from_angle(randf() * TAU) * randf_range(speed * 0.2, speed), "c": color, "life": randf_range(0.12, 0.5), "max_life": 0.5, "r": randf_range(1.5, 4)})

func _explode(p: Vector2, scale_value: float, delay: float = 0.0, grounded: bool = false) -> void:
	var effect := {"p": p, "wp": _screen_to_world(p), "grounded": grounded, "scale": scale_value, "age": -delay, "rotation": randf() * TAU, "started": false}

	var variant := explosion_rng.randi_range(0, explosion_variants.size() - 1) if not explosion_variants.is_empty() else -1
	effect["variant"] = variant
	effect["style"] = explosion_variants[variant].id if variant >= 0 else "fallback"
	effect["duration"] = explosion_variants[variant].duration if variant >= 0 else explosion_duration
	explosions.append(effect)
	if delay <= 0: _activate_explosion(effect)

func _activate_explosion(effect: Dictionary) -> void:
	effect.started = true
	sfx.explosion(effect.scale, effect.p)
	_spark(effect.p, GOLD, int(22 * effect.scale), 260 * effect.scale)
	_spark(effect.p, Color("ff703b"), int(10 * effect.scale), 160 * effect.scale)
	shake = maxf(shake, 3.5 * effect.scale)
	gamepad.explosion(effect.scale)

func _update_effects(dt: float) -> void:
	combat_vfx.advance(dt)
	powerup_burst.advance(dt)
	for remains in maid_remains:

		remains.age += dt
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p.life -= dt
		p.p += p.v * dt
		p.v *= pow(0.12, dt)
		if p.life <= 0: particles.remove_at(i)
	for i in range(explosions.size() - 1, -1, -1):
		explosions[i].age += dt
		if explosions[i].grounded: explosions[i].p = _world_to_screen(explosions[i].wp)
		if not explosions[i].get("started", true) and explosions[i].age >= 0: _activate_explosion(explosions[i])
		if explosions[i].age > float(explosions[i].get("duration", explosion_duration)): explosions.remove_at(i)
	for i in range(popups.size() - 1, -1, -1):
		popups[i].life -= dt
		popups[i].p.y -= dt * 35
		if popups[i].life <= 0: popups.remove_at(i)
	for i in range(decals.size() - 1, -1, -1):
		decals[i].life -= dt
		if decals[i].life <= 0: decals.remove_at(i)

func _draw() -> void:
	lighting.begin_frame()
	if game_state == "character_select":
		CharacterSelect.draw(self)
		lighting.end_frame()
		return
	if game_state in ["intro", "ending"]:
		draw_rect(Rect2(0, 0, W, H), Color("02050c"))
		lighting.end_frame()
		return
	var offset := Vector2(sin(visual_time * 97), cos(visual_time * 113)) * shake
	draw_set_transform(offset)
	if not lighting.active:
		_draw_background()
		_draw_ground_details(self, offset)
	_draw_maid_remains()
	for e in enemies: _draw_enemy(e)
	if enemy_patterns: enemy_patterns.draw_cues(self)
	for p in pickups: _draw_pickup(p)
	_draw_shots()
	upgraded_attacks.draw(self)
	_draw_player()
	_draw_effects()
	for b in bullets: _draw_bullet(b)
	for p in popups: _text(p.text, p.p, 27, Color(1, 0.78, 0.94, minf(1, p.life * 2)), true)
	if blast_timer > 0:
		var r := (1.3 - blast_timer) * 850
		if character_index == 3:
			draw_circle(player, minf(r, 135), Color(0.18, 0.88, 0.7, blast_timer * 0.08))
			for ring in range(3):
				draw_arc(player, minf(r, 88 + ring * 20), visual_time * (ring + 1), visual_time * (ring + 1) + PI * 1.8, 64, Color(0.55, 1, 0.88, blast_timer * 0.5), 2.5, true)
		draw_arc(player, r, 0, TAU, 128, Color(0.3, 1, 0.82, blast_timer * 0.65), 14, true)
		draw_arc(player, r * 0.85, 0, TAU, 128, Color(1, 1, 0.8, blast_timer * 0.5), 5, true)

	draw_set_transform(-position)
	if screen_flash > 0: draw_rect(Rect2(0, 0, W, H), Color(0.9, 1, 0.86, screen_flash * 0.35))
	_draw_hud()
	if game_state == "title": _draw_title()
	elif game_state == "gameover": _draw_end(false)
	elif game_state == "victory": _draw_end(true)
	elif paused: _draw_pause()
	elif elapsed < 3:
		var alpha := minf(1, minf(elapsed * 2, 3 - elapsed))
		_text("STAGE %02d" % stage_index, Vector2(480, 380), 45, Color(1, 1, 1, alpha), true)
		_text(str(stage_spec.name), Vector2(480, 416), 19, Color(0.65, 1, 0.94, alpha), true)
	if elapsed > float(stage_spec.boss_time) - 3 and elapsed < float(stage_spec.boss_time) + 1 and game_state == "playing":
		if int(elapsed * 5) % 2 == 0: _text("WARNING  /  " + str(stage_spec.get("boss_label", "HOSTILE ESPER" if stage_index == 1 else "MOBILE FORTRESS")), Vector2(480, 420), 28, Color("ff6b83"), true)
	lighting.end_frame()

func _draw_ground_details(canvas: CanvasItem, offset: Vector2) -> void:
	for d in decals:
		canvas.draw_set_transform(_world_to_screen(d.wp) + offset)
		var opacity: float = 0.46 * pow(clampf(d.life / d.max_life, 0, 1), 1.65)
		canvas.draw_colored_polygon(d.shape, Color(0.14, 0.12, 0.12, opacity))
		canvas.draw_colored_polygon(d.inner, Color(0.025, 0.03, 0.04, opacity * 1.3))
		for ember in d.embers:
			canvas.draw_line(ember * 0.35, ember, Color(0.07, 0.08, 0.1, opacity), 2, true)
			if d.life > 2:
				canvas.draw_line(ember, ember + Vector2(3, -4), Color(1, 0.24, 0.06, (d.life - 2) * 0.35), 2, true)
	canvas.draw_set_transform(offset)

func _draw_background() -> void:
	var width := _background_display_width()
	var left := (W - width) * 0.5
	var bounds := Rect2(left, 0, width, H)
	draw_rect(bounds, Color("515d54"))
	if background_map == null and backgrounds.is_empty(): return
	if stage_index == 5 and elapsed >= float(stage_spec.get("night_start", 315)) and not backgrounds.is_empty():
		var city: Texture2D = backgrounds[0]
		var height := city.get_height() * W / MAP_VIEW_SIZE
		var drift := (elapsed - float(stage_spec.get("night_start", 315))) * float(stage_spec.get("night_scroll_speed", 21)) * W / 1024.0
		var top := fposmod(drift, height) - height
		draw_texture_rect(city, Rect2(left, top, width, height), false)
		draw_texture_rect(city, Rect2(left, top + height, width, height), false)
	elif background_map:
		draw_texture_rect_region(background_map, bounds, Rect2(0, _camera_y(), background_map.get_width(), MAP_VIEW_SIZE))
	draw_rect(bounds, Color(0.02, 0.03, 0.055, 0.24 if boss_spawned else 0.06))

func _draw_actor(kind: String, p: Vector2, height: float, age: float, tint: Color = Color.WHITE) -> void:
	if not art.has(kind): return
	var a: Dictionary = art[kind]
	var tex: Texture2D = a.texture
	var columns := maxi(1, a.hframes)
	var rows := maxi(1, a.vframes)
	var frame := int(age * a.get("fps", 9)) % maxi(1, a.frames)
	if not a.get("loop", true): frame = mini(int(age * a.get("fps", 9)), maxi(1, a.frames) - 1)
	var cell := Vector2(tex.get_width() / float(columns), tex.get_height() / float(rows))
	var size := Vector2(height * cell.x / cell.y, height)
	var region := Rect2(Vector2(frame % columns, int(frame / columns)) * cell, cell)
	var destination := Rect2(p - size * 0.5, size)
	if lighting.has_actor(tex):
		lighting.draw_actor(tex, region, destination, tint)
	else:
		draw_texture_rect_region(tex, destination, region, tint)

func _draw_maid_remains() -> void:
	if stage_index != 5 or not art.has("maid_defeated"): return
	var entry: Dictionary = art.maid_defeated
	for remains in maid_remains:
		var foot := _world_to_screen(remains.wp)
		if foot.y < -100 or foot.y > H + 100: continue
		var perspective := lerpf(0.85, 1.15, clampf(foot.y / PLAY_BOTTOM, 0, 1))
		var height := float(entry.get("display_height", 100)) * float(stage_spec.get("maid_scale", 1.0)) * perspective
		var fall := clampf(float(remains.age) / 0.28, 0, 1)
		var point := foot - Vector2(0, float(remains.fall_height) * (1.0 - fall * fall))
		var pose_time := (int(remains.pose) + 0.01) / maxf(1, float(entry.fps))
		_draw_actor("maid_defeated", point, height, pose_time)

func _draw_enemy(e: Dictionary) -> void:
	if stage_index == 5 and e.kind == "gate_keeper":
		var duo_tint := Color(1 + e.hit, 1 + e.hit, 1 + e.hit, 1)
		for body in enemy_patterns.gate_bodies(e):
			_draw_actor(body.actor, body.p, float(body.height), float(body.age), duo_tint)
		return
	var size := {"soldier": 80.0, "drone": 175.0, "tank": 190.0, "midboss": 600.0, "boss": 300.0}
	if stage_index == 2: size = {"soldier": 80.0, "esper": 140.0, "drone": 120.0, "tank": 180.0, "turret": 140.0, "midboss": 300.0, "boss": 700.0}
	var height: float = size.get(e.kind, 120.0)
	if art.has(e.kind) and float(art[e.kind].get("display_height", 0)) > 0: height = float(art[e.kind].display_height)
	var tint := Color(1 + e.hit, 1 + e.hit, 1 + e.hit, 1)
	if stage_index == 2 and e.kind == "boss" and art.has("boss_core"):
		_draw_actor("boss_core", e.p, height, enemy_patterns.animation_time(e, "boss_core"), tint)
		if e.left_alive: _draw_actor("boss_left_pod", e.p, height, 0.0, tint)
		if e.right_alive: _draw_actor("boss_right_pod", e.p, height, 0.0, tint)
	else:
		var actor_id: String = "boss_damaged" if stage_index == 3 and e.kind == "boss" and e.get("nose_broken", false) and art.has("boss_damaged") else e.kind
		if stage_index >= 4 and e.kind == "boss" and e.get("arms_open", false) and art.has("boss_open"): actor_id = "boss_open"
		if stage_index == 5: actor_id = str(e.get("actor", actor_id))
		if art.has(actor_id) and float(art[actor_id].get("display_height", 0)) > 0: height = float(art[actor_id].display_height)
		height *= float(e.get("draw_scale", 1.0))
		_draw_actor(actor_id, e.p, height, enemy_patterns.animation_time(e, actor_id), tint)
	if e.kind == "drone":
		draw_circle(e.p + Vector2(-27, 37), 5 + sin(visual_time * 30) * 2, Color(0.5, 0.7, 1, 0.7))
		draw_circle(e.p + Vector2(27, 37), 5 + sin(visual_time * 30) * 2, Color(0.5, 0.7, 1, 0.7))
	if e.kind == "boss" and stage_index == 1:
		draw_arc(e.p, 88, 0, TAU, 64, Color(0.7, 0.5, 1, 0.24 + sin(visual_time * 4) * 0.1), 2, true)

func _player_sprite() -> String:
	if character_index == 1: return "player"
	if not _is_firing(): return "player_idle"
	if player_velocity.x < -20 and art.has("player_fire_left"): return "player_fire_left"
	if player_velocity.x > 20 and art.has("player_fire_right"): return "player_fire_right"
	if (_focus_held() or _power_held()) and art.has("player_focus"): return "player_focus"
	return "player_fire" if art.has("player_fire") else "player_idle"

func _player_visual_position() -> Vector2:

	var phase := float(character_index - 1) * 0.8
	var bob := 0.78 * sin(visual_time * 2.0 + phase) + 0.22 * sin(visual_time * 3.1 + phase * 0.7)
	return player + Vector2(0, bob * PLAYER_HOVER_AMPLITUDE)

func _draw_player() -> void:
	if invulnerable > 0 and int(visual_time * 16) % 2 == 0 and game_state != "title": return
	var p := _player_visual_position()
	var actor_id := _player_sprite()
	var actor_height := 94.0 if character_index == 1 else 104.0
	if character_index >= 2 and art.has(actor_id) and float(art[actor_id].get("display_height", 0)) > 0: actor_height = float(art[actor_id].display_height)
	if game_state == "playing" and player_velocity.length() > 70:
		for k in range(3, 0, -1):
			var trail := Color(0.08, 0.23, 1, 0.12 * (4 - k)) if character_index == 1 else Color(0.65, 0.08, 1, 0.12 * (4 - k))
			if character_index == 3: trail = Color(0.1, 1, 0.7, 0.10 * (4 - k))
			_draw_actor(actor_id, p - player_velocity * k * 0.018, actor_height, player_animation_time, trail)
	_draw_actor(actor_id, p, actor_height, player_animation_time)
	if _focus_held():
		draw_circle(player + Vector2(0, -4), 5, Color("fff9e8"))
		draw_arc(player + Vector2(0, -4), 8, 0, TAU, 24, Color("ff557c"), 1.5, true)
func _draw_shots() -> void:
	for b in player_shots:
		if b.get("kind", "bolt") in ["spirit_lance", "spirit_orb"]:
			Stage3Weapons.draw_shot(self, b)
			continue
		if b.get("kind", "bolt") == "magic":
			_draw_magic_shot(b)
			continue
		if _draw_yusuke_shot(b): continue
		var tail: Vector2 = b.p - b.v.normalized() * (33 if b.get("upgraded", false) else 24)
		draw_line(tail, b.p, Color(1, 0.68, 0.1, 0.20), 18, true)
		draw_line(tail, b.p, Color(1, 0.86, 0.23, 0.92), 8, true)
		draw_line(tail.lerp(b.p, 0.2), b.p, Color("ffffeb"), 3, true)
		draw_circle(b.p, 6, Color(1, 0.92, 0.35, 0.45))
		draw_circle(b.p, 3.8, Color("ffffd6"))
		draw_circle(tail, 3, Color(1, 0.9, 0.3, 0.65))
	if character_index == 1 and game_state == "playing" and _primary_firing():
		for side in [-1, 1]:
			var muzzle := _player_visual_position() + Vector2(side * 24, -36)
			var r := 12 + sin(visual_time * 55) * 5
			if stage_index >= 4: r *= 1.10
			draw_colored_polygon(PackedVector2Array([muzzle + Vector2(-r, 0), muzzle + Vector2(-3, -3), muzzle + Vector2(0, -r * 1.5), muzzle + Vector2(3, -3), muzzle + Vector2(r, 0), muzzle + Vector2(3, 3), muzzle + Vector2(0, r), muzzle + Vector2(-3, 3)]), Color("fffaba"))
	if character_index == 2 and game_state == "playing" and _is_firing():
		var palm := _player_visual_position() + Vector2(-18 if player_velocity.x < -20 else 18, -28)
		var radius := 11.0 + sin(visual_time * 41) * 3.0
		draw_circle(palm, radius * 1.7, Color(0.65, 0.08, 1, 0.13))
		draw_arc(palm, radius, visual_time * 8, visual_time * 8 + PI * 1.7, 24, Color("cf72ff"), 2.5, true)
		draw_circle(palm, 3.5, Color("fff0ff"))
	if character_index == 3 and game_state == "playing" and _is_firing():
		Stage3Weapons.draw_cast(self)
	if character_index == 1 and _power_held() and power > 2 and game_state == "playing":
		for j in range(12):
			var y := player.y - 65 - fmod(j * 58 + visual_time * 580, maxf(100, player.y - 100))
			var orb := Vector2(player.x + sin(j * 0.5 + visual_time * 5) * 18, y)
			draw_circle(orb, 30, Color(1, 0.3, 0.025, 0.65))
			draw_circle(orb, 23, Color("ffca34"))
			draw_circle(orb, 14, Color("ffffc9"))

func _draw_yusuke_shot(shot: Dictionary) -> bool:
	if not texture_cache.has("yusuke_shot"): return false
	var texture: Texture2D = texture_cache.yusuke_shot
	var columns := maxi(1, int(yusuke_shot_spec.get("hframes", 6)))
	var rows := maxi(1, int(yusuke_shot_spec.get("vframes", 1)))
	var frames := maxi(1, int(yusuke_shot_spec.get("frames", 6)))
	var fps := float(yusuke_shot_spec.get("fps", 18))
	var frame := int(float(shot.age) * fps) % frames
	var cell := Vector2(texture.get_width() / float(columns), texture.get_height() / float(rows))
	var dimensions: Array = yusuke_shot_spec.get("display_size", [24, 52])
	var size := Vector2(float(dimensions[0]), float(dimensions[1])) * (1.12 if shot.get("upgraded", false) else 1.0)
	var anchor: Array = yusuke_shot_spec.get("anchor_px", [cell.x * 0.5, 8])
	var origin := Vector2(float(anchor[0]), float(anchor[1])) / cell * size
	var offset := Vector2(sin(visual_time * 97), cos(visual_time * 113)) * shake
	draw_set_transform(shot.p + offset, shot.v.angle() + PI * 0.5)
	draw_texture_rect_region(texture, Rect2(-origin, size), Rect2(Vector2(frame % columns, int(frame / columns)) * cell, cell))
	draw_set_transform(offset)
	return true

func _draw_magic_shot(shot: Dictionary) -> void:
	var actor_id := "magic_focus" if shot.focused and art.has("magic_focus") else "magic_fire"
	if not art.has(actor_id): return
	var a: Dictionary = art[actor_id]
	var texture: Texture2D = a.texture
	var columns: int = maxi(1, a.hframes)
	var rows: int = maxi(1, a.vframes)
	var frame: int = posmod(int(shot.age * a.get("fps", 16) + shot.phase * 2), maxi(1, a.frames))
	var cell := Vector2(texture.get_width() / float(columns), texture.get_height() / float(rows))
	var dimensions := Vector2(56, 62) if shot.focused else Vector2(66, 66)
	var offset := Vector2(sin(visual_time * 97), cos(visual_time * 113)) * shake
	draw_set_transform(shot.p + offset, shot.age * 1.2 + shot.phase * 0.1)
	if shot.get("upgraded", false):
		draw_texture_rect_region(texture, Rect2(-dimensions * 0.45 + Vector2(0, 19), dimensions * 0.9), Rect2(Vector2(frame % columns, int(frame / columns)) * cell, cell), Color(0.85, 0.55, 1, 0.20))
	draw_texture_rect_region(texture, Rect2(-dimensions * 0.5, dimensions), Rect2(Vector2(frame % columns, int(frame / columns)) * cell, cell))
	draw_set_transform(offset)

func _draw_bullet(b: Dictionary) -> void:
	var offset := Vector2(sin(visual_time * 97), cos(visual_time * 113)) * shake
	var phase: float = b.age * 19 + b.get("phase", 0.0)
	var pulse := 0.87 + sin(phase) * 0.13
	var size: float = b.get("visual_scale", 1.0)
	var shape: String = b.get("shape", "drop")
	var light_frame := int(b.age * 12.0 + b.get("phase", 0.0)) % 4
	draw_set_transform(b.p + offset, b.v.angle() + PI / 2, Vector2.ONE * size)
	if shape == "ring":
		draw_arc(Vector2.ZERO, 9, 0, TAU, 24, Color("073e2f"), 4, true)
		draw_arc(Vector2.ZERO, 7.8, phase * 0.3, phase * 0.3 + TAU, 24, Color(0.2, 1, 0.59, pulse), 2.4, true)
		draw_arc(Vector2.ZERO, 6.5, phase, phase + PI * 0.7, 12, Color("e4fff1"), 1.3, true)
	elif shape == "palm":
		var hand := PackedVector2Array([Vector2(-5,6),Vector2(-9,0),Vector2(-9,-3),Vector2(-7,-4),Vector2(-4,-1),Vector2(-4,-7),Vector2(-2,-9),Vector2(-1,-3),Vector2(0,-11),Vector2(2,-11),Vector2(2,-3),Vector2(4,-9),Vector2(6,-8),Vector2(5,-2),Vector2(7,-6),Vector2(9,-4),Vector2(7,3),Vector2(3,7),Vector2(-2,7)])
		draw_colored_polygon(hand, Color("237eff") if b.kind == 0 else Color("f144c1"))
		var closed := hand.duplicate()
		closed.append(hand[0])
		draw_polyline(closed, Color("b5faff") if b.kind == 0 else Color("ffc5f4"), 0.9, true)
		draw_line(Vector2(0, 4), Vector2(1, -6), Color("f7ffff"), 2.1, true)
		draw_line(Vector2(-2, 1), Vector2(-3, -5), Color("f5ffff"), 1.2, true)
		draw_line(Vector2(2, 1), Vector2(5, -4), Color("f5ffff"), 1.2, true)
	elif shape == "star":
		draw_colored_polygon(PackedVector2Array([Vector2(0,-10),Vector2(3,-3),Vector2(9,0),Vector2(3,3),Vector2(0,10),Vector2(-3,3),Vector2(-9,0),Vector2(-3,-3)]), Color("ff57cb"))
		draw_line(Vector2(0, -6), Vector2(0, 6), Color("fff0ff"), 2, true)
		draw_line(Vector2(-5, 0), Vector2(5, 0), Color("ffe8ff"), 1.6, true)
	elif shape == "needle":
		draw_colored_polygon(PackedVector2Array([Vector2(0, -19), Vector2(5, -7), Vector2(4, 10), Vector2(0, 17), Vector2(-4, 10), Vector2(-5, -7)]), Color("68125d"))
		draw_line(Vector2(0, 12), Vector2(0, -13), Color(1, 0.2 + pulse * 0.25, 0.8, 1), 5, true)
		draw_line(Vector2(0, 7), Vector2(0, -12), Color("fff0ff"), 1.7, true)
	elif shape == "bead":
		draw_circle(Vector2.ZERO, 8.5, Color("102c80") if b.kind == 0 else Color("621158"))
		draw_circle(Vector2.ZERO, 6.7, Color(0.18, 0.66 * pulse, 1, 1) if b.kind == 0 else Color(1, 0.3, 0.75 * pulse, 1))
		var core := Color("e2ffff") if b.kind == 0 else Color("fff1ff")
		if light_frame == 1:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(2, -2), Vector2(7, 0), Vector2(2, 2), Vector2(0, 7), Vector2(-2, 2), Vector2(-7, 0), Vector2(-2, -2)]), core)
		elif light_frame == 2:
			draw_line(Vector2(0, -5), Vector2(0, 3), core, 3.5, true)
		elif light_frame == 3:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -6), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)]), core)
		else:
			draw_circle(Vector2(0, -1), 3.9 + pulse * 0.5, core)
		draw_circle(Vector2(-2.0, -3.2), 1.4, Color.WHITE)
	else:
		var texture_id := "bullet_blue" if b.kind == 0 else "bullet_pink"
		if texture_cache.has(texture_id):
			var dimensions := Vector2(17, 27) if b.kind == 0 else Vector2(19, 21)
			draw_texture_rect(texture_cache[texture_id], Rect2(-dimensions * 0.5, dimensions), false, Color(pulse, 0.92 + pulse * 0.08, 1, 1))
		draw_circle(Vector2(-1.5, -3), 1.5 + pulse, Color(0.9, 1, 1, pulse * 0.7))
		if light_frame == 1:
			draw_line(Vector2(-4, -3), Vector2(4, -3), Color("edffff"), 1.2, true)
	draw_set_transform(offset)

func _draw_pickup(p: Dictionary) -> void:
	var phase: float = p.age + p.p.x * 0.009
	var bob := Vector2(sin(phase * 2.5) * 3.0, sin(phase * 4.2) * 4.5)
	var dims := Vector2(44 + sin(phase * 3.1) * 3, 38 + sin(phase * 5.4) * 1.5)
	var hue := Color("ffb335") if p.kind == 0 else Color("42e8ff")
	NeonUI.sign(self, fonts, Rect2(p.p + bob - dims * 0.5, dims), "P" if p.kind == 0 else "E", hue, phase, 27)

func _draw_effects() -> void:
	for ex in explosions:
		if ex.age < 0: continue
		var t := clampf(float(ex.age) / float(ex.get("duration", explosion_duration)), 0, 1)
		var variant: Dictionary = {}
		if not explosion_variants.is_empty(): variant = explosion_variants[clampi(int(ex.get("variant", 0)), 0, explosion_variants.size() - 1)]
		var texture_key: String = variant.get("texture_key", "explosion_sheet")
		if texture_cache.has(texture_key):
			var texture: Texture2D = texture_cache[texture_key]
			var count := int(variant.get("frames", explosion_frames))
			var columns := int(variant.get("columns", explosion_columns))
			var rows := int(variant.get("rows", explosion_rows))
			var frame := mini(count - 1, int(t * count))
			var cell := Vector2(texture.get_width() / float(columns), texture.get_height() / float(rows))
			var region := Rect2(Vector2(frame % columns, int(frame / columns)) * cell, cell)
			var dimension: float = 280 * ex.scale
			draw_texture_rect_region(texture, Rect2(ex.p - Vector2.ONE * dimension * 0.5, Vector2.ONE * dimension), region)
			if t < 0.35:
				draw_arc(ex.p, (18 + t * 190) * ex.scale, 0, TAU, 48, Color(1, 0.8, 0.47, (0.35 - t) * 0.65), 1.5, true)
			continue
		var r: float = (16 + 83 * sqrt(t)) * ex.scale
		var alpha: float = pow(1 - t, 1.4)
		draw_circle(ex.p, r * 1.14, Color(0.45, 0.1, 0.035, alpha * 0.25))
		draw_arc(ex.p, r * 1.2, 0, TAU, 48, Color(1, 0.53, 0.1, alpha * 0.6), maxf(1, 9 * (1 - t)), true)
		for j in range(7):
			var a: float = j * TAU / 7 + ex.rotation
			var p: Vector2 = ex.p + Vector2.from_angle(a) * r * 0.35
			var lobe: float = r * (0.35 + 0.08 * sin(j * 4.3 + t * 3))
			draw_circle(p, lobe * 1.2, Color(0.92, 0.16, 0.04, alpha))
			draw_circle(p, lobe * 0.91, Color(1, 0.62, 0.06, alpha))
			draw_circle(p + Vector2(-lobe * 0.1, -lobe * 0.1), lobe * 0.62, Color(1, 0.97, 0.64, alpha))
		if t < 0.25: draw_circle(ex.p, (1 - t * 4) * r * 0.75, Color(1, 1, 0.95, alpha))
	for p in particles:
		var c: Color = p.c
		c.a = clampf(p.life / 0.25, 0, 1)
		if p.get("kind", "") == "seal":
			var radius: float = p.r * (1.0 - p.life / p.max_life * 0.65)
			if art.has("magic_impact"): _draw_actor("magic_impact", p.p, radius * 2, p.max_life - p.life, Color(1, 1, 1, c.a))
			draw_circle(p.p, radius, Color(0.12, 0.95, 0.93, c.a * 0.16))
			draw_arc(p.p, radius * 0.8, visual_time * 9, visual_time * 9 + TAU * 0.85, 32, Color(0.6, 1, 1, c.a * 0.6), 2, true)
			continue
		draw_line(p.p, p.p - p.v * 0.035, c, p.r, true)

func _text(s: String, p: Vector2, size: int, color: Color = WHITE, centered: bool = false) -> void:
	if centered: p.x -= fonts.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	draw_string_outline(fonts, p + Vector2(1, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.02, 0.025, 0.04, color.a * 0.9))
	draw_string(fonts, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_hud() -> void:

	_text("%08d" % score, Vector2(142, 33), 31)
	_text("%08d" % high_score, Vector2(480, 33), 31, WHITE, true)
	_text("0", Vector2(922, 33), 30)
	var boss_health := -1.0
	for e in enemies:
		if e.kind == "boss" or e.get("hud_boss", false) or (stage_index == 1 and e.kind == "midboss"):
			boss_health = clampf(e.hp / e.max_hp, 0, 1)
			break
	var hud_offset := 44.0 if boss_health >= 0 else 0.0
	if boss_health >= 0:
		for segment in range(3):
			var r := Rect2(14 + segment * 203, 46, 192, 28)
			var fill := clampf(boss_health * 3 - segment, 0, 1)
			NeonUI.meter(self, r, fill, Color("31edb7"), visual_time + segment * 0.5)
	for j in range(mini(3, lives)):
		var r := Rect2(16 + j * 57, 44 + hud_offset, 49, 37)
		NeonUI.sign(self, fonts, r, "♥", Color("ed8bff"), visual_time + j * 0.32, 27)
	_text("P", Vector2(20, 116 + hud_offset), 31, GOLD)
	_text("%02d" % power_level, Vector2(75, 116 + hud_offset), 31)
	if stage_index <= 3:
		_text("MAX" if power_level >= 5 else "%d/3" % power_pickup_count, Vector2(121, 114 + hud_offset), 15, Color("a9e6ee"))
	draw_rect(Rect2(0, 916, W, 44), Color("141821"))
	draw_rect(Rect2(0, 916, W, 4), Color("d1d9d8"))
	draw_rect(Rect2(4, 924, 145, 30), Color("5d172b"))
	_text("POWER", Vector2(12, 947), 21, Color("ee355a"))
	_text("%d" % int(power / 10), Vector2(121, 947), 21, Color("ff5572"))
	NeonUI.meter(self, Rect2(156, 925, 322, 27), power / 100.0, Color("18ecc1"), visual_time)
	_text("STAGE %02d" % stage_index, Vector2(664, 948), 23, Color("c5eee6"), true)
	_text("%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60], Vector2(845, 948), 22, Color("a5d5d4"), true)
func _panel(fill: Color, border: Color, radius: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	return box

func _draw_title() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("040a18"))
	if title_cover: draw_texture_rect(title_cover, Rect2(0, 0, W, H), false)

	for y in range(0, 220, 4):
		draw_rect(Rect2(0, y, W, 4), Color(0.01, 0.02, 0.05, 0.4 * (1.0 - y / 220.0)))
	for y in range(704, 960, 4):
		draw_rect(Rect2(0, y, W, 4), Color(0.01, 0.02, 0.05, clampf((y - 704) / 180.0, 0, 0.8)))
	NeonUI.label(self, fonts, "ESP Ra.De.", Vector2(480, 134), 84, Color("a7f6ff"), 0.91 + sin(visual_time * 3.1) * 0.09)
	_text("STAGE %02d  /  %s" % [stage_index, "SELECT YOUR ESPER" if stage_index >= 4 else HERO_NAMES[character_index - 1]], Vector2(480, 180), 20, Color("91e6d9"), true)
	draw_line(Vector2(327, 202), Vector2(633, 202), Color(0.35, 0.9, 0.85, 0.45), 1)
	_text("<  1 SCHOOL  /  2 CASINO  /  3 SEASIDE  /  4 SUBWAY  /  5 CITADEL  >", Vector2(480, 235), 14, Color("d5e6ed"), true)
	if int(visual_time * 1.5) % 2 == 0:
		NeonUI.label(self, fonts, "PRESS A TO START" if gamepad.using_gamepad else "ENTER / CLICK TO START", Vector2(480, 795), 31, Color("c9ffff"))
	_text("LEFT STICK / D-PAD   MOVE / SELECT     LB / LT   FOCUS" if gamepad.using_gamepad else "WASD / ARROWS   MOVE       SHIFT   FOCUS", Vector2(480, 846), 17, Color("d4dcd9"), true)
	_text("HOLD A   SHOT     B   FULL-SCREEN ATTACK     X / RT   POWER" if gamepad.using_gamepad else "HOLD Z / SPACE   SHOT     X   BARRIER     C   POWER SHOT", Vector2(480, 875), 16, Color("d4dcd9"), true)
	_text("MENU   PAUSE       VIBRATION   AUTO" if gamepad.using_gamepad else "ESC   PAUSE       R   RESTART       F11   FULLSCREEN", Vector2(480, 908), 15, Color("b3c3c3"), true)

func _draw_pause() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.02, 0.04, 0.72))
	_text("PAUSED", Vector2(480, 365), 54, WHITE, true)
	_text("MENU / A / B  RESUME      Y  RESTART" if gamepad.using_gamepad else "ESC  RESUME      R  RESTART", Vector2(480, 443), 22, Color("c9ded9"), true)
	_text("LEFT STICK / D-PAD  MOVE    LB / LT  FOCUS" if gamepad.using_gamepad else "WASD / ARROWS  MOVE      SHIFT  FOCUS", Vector2(480, 491), 18, Color("b0c5c1"), true)
	_text("HOLD A  SHOT    B  FULL-SCREEN    X / RT  POWER" if gamepad.using_gamepad else "F11  FULLSCREEN", Vector2(480, 537), 18, Color("b0c5c1"), true)

func _draw_end(win: bool) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.02, 0.04, 0.7))
	_text(("ALL STAGES CLEAR" if stage_index == CHAPTER_COUNT else "STAGE CLEAR") if win else "GAME OVER", Vector2(480, 370), 52 if win and stage_index == CHAPTER_COUNT else 58, GOLD if win else WHITE, true)
	_text("%08d" % score, Vector2(480, 447), 43, WHITE, true)
	_text("%d HOSTILES DESTROYED" % destroyed_total, Vector2(480, 506), 20, Color("bbd5ce"), true)
	var accept := "A" if gamepad.using_gamepad else "ENTER"
	_text("%s  STAGE %02d" % [accept, stage_index + 1] if win and stage_index < CHAPTER_COUNT else "%s  PLAY AGAIN" % accept, Vector2(480, 605), 27, WHITE, true)
	_text("MENU  CONFIRM" if gamepad.using_gamepad else "ENTER  CONFIRM", Vector2(480, 648), 19, Color("a7beb9"), true)
