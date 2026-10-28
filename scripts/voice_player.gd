extends Node

const DIRECTORY := "res://assets/audio/voice/"
const NARRATIVES := ["boss_1_death", "queen_invite", "queen_death"]
const DUCK_DB := -5.0
const PAIN_DB := -2.5
const NARRATIVE_DB := 0.0
const MAID_VARIANTS := 4
const MAID_DB := -6.0
const MAID_INTERVAL := 0.18

var asset_directory := DIRECTORY
var enabled := true
var rng := RandomNumberGenerator.new()
var cache: Dictionary = {}
var pain_player: AudioStreamPlayer
var narrative_player: AudioStreamPlayer
var enemy_players: Array[AudioStreamPlayer] = []
var enemy_keys: Array[String] = []
var enemy_finished: Array[Callable] = []
var maid_cooldown := 0.0
var last_maid := -1
var pain_key := ""
var narrative_key := ""
var narrative_busy := false
var paused := false
var epoch := 0
var pain_serial := 0
var narrative_serial := 0
var seen_narratives: Dictionary = {}
var last_hurt := {1: -1, 2: -1, 3: -1}
var missing_reported: Dictionary = {}
var _pain_finished: Callable
var _narrative_finished: Callable
var _duck_owned := false
var _bgm_base_db := 0.0
var duck_db := 0.0
var _duck_target := 0.0

func _ready() -> void:
	rng.randomize()
	pain_player = AudioStreamPlayer.new()
	pain_player.name = "PainVoice"
	pain_player.bus = &"Voice"
	pain_player.volume_db = PAIN_DB
	add_child(pain_player)
	narrative_player = AudioStreamPlayer.new()
	narrative_player.name = "NarrativeVoice"
	narrative_player.bus = &"Voice"
	narrative_player.volume_db = NARRATIVE_DB
	add_child(narrative_player)
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "EnemyVoice%d" % index
		player.bus = &"Voice"
		player.volume_db = MAID_DB
		add_child(player)
		enemy_players.append(player)
		enemy_keys.append("")
		enemy_finished.append(Callable())
	for hero in range(1, 4):
		for variant in range(1, 4): _load_voice("hero_%d_hurt_%02d" % [hero, variant], false)
	for key in NARRATIVES: _load_voice(key, false)
	for variant in range(1, MAID_VARIANTS + 1): _load_voice("maid_death_%02d" % variant, false)

func _load_voice(key: String, report_missing: bool = true) -> AudioStreamOggVorbis:
	if cache.has(key): return cache[key]
	var path := asset_directory + key + ".ogg"
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStreamOggVorbis
		if stream and stream.get_length() > 0:
			stream.loop = false
			cache[key] = stream
			return stream
	if report_missing and not missing_reported.has(key):
		missing_reported[key] = true
		push_warning("Missing voice: " + path)
	return null

func play_hurt(character: int) -> bool:
	var hero := clampi(character, 1, 3)
	if not enabled or paused:
		return false
	var index := rng.randi_range(0, 2)
	if index == int(last_hurt[hero]): index = (index + rng.randi_range(1, 2)) % 3
	var key := "hero_%d_hurt_%02d" % [hero, index + 1]
	var stream := _load_voice(key)
	if stream == null:
		return false
	pain_serial += 1
	if _pain_finished.is_valid() and pain_player.finished.is_connected(_pain_finished): pain_player.finished.disconnect(_pain_finished)
	pain_player.stop()
	pain_player.stream = stream
	pain_player.pitch_scale = 1.0
	pain_player.stream_paused = false
	pain_key = key
	last_hurt[hero] = index
	_pain_finished = _finish_pain.bind(epoch, pain_serial, key)
	pain_player.finished.connect(_pain_finished, CONNECT_ONE_SHOT)
	pain_player.play()
	return true

func play_narrative(key: String) -> bool:
	var reason := ""
	if not enabled: reason = "disabled"
	elif not key in NARRATIVES: reason = "unknown"
	elif paused: reason = "paused"
	elif narrative_busy: reason = "busy"
	elif seen_narratives.has(key): reason = "already_played"
	if not reason.is_empty():
		return false
	var stream := _load_voice(key)
	if stream == null:
		return false
	_stop_enemy_voices()
	narrative_serial += 1
	if _narrative_finished.is_valid() and narrative_player.finished.is_connected(_narrative_finished): narrative_player.finished.disconnect(_narrative_finished)
	narrative_key = key
	narrative_busy = true
	seen_narratives[key] = true
	narrative_player.stream = stream
	narrative_player.pitch_scale = 1.0
	narrative_player.stream_paused = false
	_narrative_finished = _finish_narrative.bind(epoch, narrative_serial, key)
	narrative_player.finished.connect(_narrative_finished, CONNECT_ONE_SHOT)
	_set_duck(true)
	narrative_player.play()
	return true

func is_narrative_busy(key: String = "") -> bool:
	return narrative_busy and (key.is_empty() or narrative_key == key)

func has_active_voice() -> bool:
	return narrative_busy or not pain_key.is_empty() or enemy_keys.any(func(key): return not key.is_empty())

func play_maid_death() -> bool:
	var reason := ""
	if not enabled: reason = "disabled"
	elif paused: reason = "paused"
	elif narrative_busy: reason = "narrative"
	elif maid_cooldown > 0: reason = "cooldown"
	var slot := enemy_keys.find("")
	if reason.is_empty() and slot < 0: reason = "voice_limit"
	if not reason.is_empty():
		return false
	var index := rng.randi_range(0, MAID_VARIANTS - 1)
	if index == last_maid: index = (index + rng.randi_range(1, MAID_VARIANTS - 1)) % MAID_VARIANTS
	var key := "maid_death_%02d" % (index + 1)
	var stream := _load_voice(key)
	if stream == null:
		return false
	var player := enemy_players[slot]
	if enemy_finished[slot].is_valid() and player.finished.is_connected(enemy_finished[slot]): player.finished.disconnect(enemy_finished[slot])
	player.stream = stream
	player.pitch_scale = 1.0
	player.stream_paused = false
	enemy_keys[slot] = key
	enemy_finished[slot] = _finish_enemy.bind(epoch, slot, key)
	player.finished.connect(enemy_finished[slot], CONNECT_ONE_SHOT)
	player.play()
	maid_cooldown = MAID_INTERVAL
	last_maid = index
	return true

func _finish_enemy(expected_epoch: int, slot: int, key: String) -> void:
	if expected_epoch != epoch or enemy_keys[slot] != key: return
	enemy_keys[slot] = ""

func _stop_enemy_voices() -> void:
	for index in range(enemy_players.size()):
		var player := enemy_players[index]
		if enemy_finished[index].is_valid() and player.finished.is_connected(enemy_finished[index]): player.finished.disconnect(enemy_finished[index])
		player.stop()
		player.stream_paused = false
		enemy_keys[index] = ""
	maid_cooldown = 0.0

func _finish_pain(expected_epoch: int, expected_serial: int, key: String) -> void:
	if expected_epoch != epoch or expected_serial != pain_serial or key != pain_key: return
	pain_key = ""

func _finish_narrative(expected_epoch: int, expected_serial: int, key: String) -> void:
	if expected_epoch != epoch or expected_serial != narrative_serial or key != narrative_key: return
	narrative_busy = false
	narrative_key = ""
	_set_duck(false)

func set_paused(value: bool) -> void:
	if value == paused: return
	paused = value
	pain_player.stream_paused = value
	narrative_player.stream_paused = value
	for player in enemy_players: player.stream_paused = value

func _set_duck(active: bool) -> void:
	var bus := AudioServer.get_bus_index("BGM")
	if bus < 0: return
	if active and not _duck_owned:
		_bgm_base_db = AudioServer.get_bus_volume_db(bus)
		_duck_owned = true
	_duck_target = DUCK_DB if active else 0.0

func _process(dt: float) -> void:
	if paused: return
	maid_cooldown = maxf(0.0, maid_cooldown - dt)
	if not _duck_owned: return
	var speed := absf(DUCK_DB) / (0.12 if _duck_target < duck_db else 0.25)
	duck_db = move_toward(duck_db, _duck_target, maxf(0, dt) * speed)
	var bus := AudioServer.get_bus_index("BGM")
	if bus >= 0: AudioServer.set_bus_volume_db(bus, _bgm_base_db + duck_db)
	if is_zero_approx(duck_db) and is_zero_approx(_duck_target): _duck_owned = false

func reset() -> void:
	epoch += 1
	pain_serial += 1
	narrative_serial += 1
	_stop_enemy_voices()
	if is_instance_valid(pain_player):
		if _pain_finished.is_valid() and pain_player.finished.is_connected(_pain_finished): pain_player.finished.disconnect(_pain_finished)
		pain_player.stop()
		pain_player.stream_paused = false
	if is_instance_valid(narrative_player):
		if _narrative_finished.is_valid() and narrative_player.finished.is_connected(_narrative_finished): narrative_player.finished.disconnect(_narrative_finished)
		narrative_player.stop()
		narrative_player.stream_paused = false
	pain_key = ""
	narrative_key = ""
	narrative_busy = false
	paused = false
	seen_narratives.clear()
	if _duck_owned:
		var bus := AudioServer.get_bus_index("BGM")
		if bus >= 0: AudioServer.set_bus_volume_db(bus, _bgm_base_db)
	_duck_owned = false
	duck_db = 0.0
	_duck_target = 0.0

func _exit_tree() -> void:
	reset()
	cache.clear()
