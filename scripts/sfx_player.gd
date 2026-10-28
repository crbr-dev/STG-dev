extends Node

const WORLD_VOICES := 16
const UI_VOICES := 4
const DIRECTORY := "res://assets/audio/sfx/"

const CUES := {
	"coin": [-3.0, 0.2, 100, 1],
	"ui_move": [-9.0, 0.065, 40, 2],
	"ui_confirm": [-5.0, 0.18, 90, 1],
	"ui_cancel": [-7.0, 0.15, 80, 1],
	"pause": [-9.0, 0.15, 60, 1],
	"resume": [-9.0, 0.15, 60, 1],
	"shot_1": [-7.0, 0.07, 10, 3],
	"shot_2": [-6.0, 0.08, 10, 3],
	"shot_3": [-6.0, 0.09, 10, 3],
	"impact_1": [1.0, 0.075, 75, 2],
	"impact_2": [1.0, 0.075, 75, 2],
	"impact_3": [1.0, 0.075, 75, 2],
	"power_1": [-7.0, 0.16, 25, 2],
	"power_2": [-7.0, 0.16, 25, 2],
	"power_3": [-7.0, 0.17, 25, 2],
	"upgrade_orb": [-6.0, 0.3, 45, 2],
	"upgrade_lightning": [-6.0, 0.3, 45, 2],
	"upgrade_bird": [-6.0, 0.3, 45, 2],
	"bomb": [-3.0, 0.35, 100, 1],
	"explosion_small_01": [0.0, 0.045, 80, 4],
	"explosion_small_02": [0.0, 0.045, 80, 4],
	"explosion_small_03": [0.0, 0.045, 80, 4],
	"explosion_large_01": [2.0, 0.055, 90, 3],
	"explosion_large_02": [2.0, 0.055, 90, 3],
	"explosion_large_03": [2.0, 0.055, 90, 3],
	"player_hurt": [-5.0, 0.3, 95, 1],
	"player_down": [-4.0, 0.5, 100, 1],
	"enemy_down": [-15.0, 0.09, 25, 2],
	"pickup": [3.0, 0.08, 92, 2],
	"powerup": [-7.0, 0.15, 75, 1],
	"powerup_early": [-7.0, 0.15, 93, 1],
	"energy_empty": [-12.0, 0.65, 50, 1],
	"boss_warning": [-8.0, 2.0, 80, 1],
	"boss_transform": [-8.0, 0.5, 85, 1],
	"enemy_shot": [-22.0, 0.14, 5, 2],
}
const UI_KEYS := ["coin", "ui_move", "ui_confirm", "ui_cancel", "pause", "resume"]

var rng := RandomNumberGenerator.new()
var cache: Dictionary = {}
var world_players: Array[AudioStreamPlayer2D] = []
var ui_players: Array[AudioStreamPlayer] = []
var cooldowns: Dictionary = {}
var last_variant := {"explosion_small": -1, "explosion_large": -1}
var world_paused := false
var enabled := true
var missing_reported: Dictionary = {}

func _ready() -> void:
	rng.randomize()
	for key in CUES:
		var path := DIRECTORY + str(key) + ".ogg"
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStreamOggVorbis
			if stream:
				stream.loop = false
				cache[key] = stream
	for index in WORLD_VOICES:
		var player := AudioStreamPlayer2D.new()
		player.name = "WorldSFX%d" % index
		player.bus = &"SFX"
		player.max_distance = 2500.0
		player.attenuation = 0.0
		player.panning_strength = 0.35
		add_child(player)
		world_players.append(player)
	for index in UI_VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "UISFX%d" % index
		player.bus = &"UI"
		add_child(player)
		ui_players.append(player)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _busy(player: Node, now: float) -> bool:

	return player.playing or now < float(player.get_meta("reserved_until", -1.0))

func play_ui(key: String) -> bool:
	if not key in UI_KEYS: return false
	return _play(key, Vector2.ZERO, 1.0, key, true)

func play_cue(key: String, position: Vector2 = Vector2(480, 480), pitch: float = 1.0) -> bool:
	return _play(key, position, pitch, key, key in UI_KEYS)

func explosion(scale_value: float, position: Vector2) -> bool:
	var family := "explosion_large" if scale_value >= 1.35 else "explosion_small"
	var index := rng.randi_range(0, 2)
	if index == int(last_variant[family]): index = (index + rng.randi_range(1, 2)) % 3
	var key := family + "_%02d" % (index + 1)
	var accepted := _play(key, position, clampf(1.07 - scale_value * 0.045, 0.88, 1.08), family, false)
	if accepted: last_variant[family] = index
	return accepted

func _play(key: String, position: Vector2, pitch: float, family: String, ui: bool) -> bool:
	if not enabled or not CUES.has(key):
		return false
	if not ui and world_paused:
		return false
	if not ui and (position.x < -120 or position.x > 1080 or position.y < -180 or position.y > 1100):
		return false
	var parameters: Array = CUES[key]
	var now := _now()
	if now < float(cooldowns.get(family, -1.0)):
		return false
	if not cache.has(key):
		if not missing_reported.has(key):
			missing_reported[key] = true
			push_warning("Missing SFX: " + DIRECTORY + key + ".ogg")
		return false
	var pool: Array = ui_players if ui else world_players
	var matching := 0
	var selected: Variant = null
	var lowest_priority := int(parameters[2])
	var oldest := INF
	for player in pool:
		if not _busy(player, now):
			if selected == null: selected = player
			continue
		if player.get_meta("family", "") == family: matching += 1
	if matching >= int(parameters[3]):
		return false
	if selected == null:
		for player in pool:
			var priority := int(player.get_meta("priority", 0))
			var started := float(player.get_meta("started", 0.0))
			if priority < lowest_priority or (priority == lowest_priority and priority < int(parameters[2]) and started < oldest):
				selected = player
				lowest_priority = priority
				oldest = started
	if selected == null:
		return false
	selected.stop()
	selected.stream = cache[key]
	selected.volume_db = float(parameters[0]) + rng.randf_range(-0.6, 0.0)
	selected.pitch_scale = pitch * (rng.randf_range(0.98, 1.02) if not ui else 1.0)
	if not ui: selected.position = position
	selected.set_meta("family", family)
	selected.set_meta("priority", int(parameters[2]))
	selected.set_meta("started", now)
	selected.set_meta("reserved_until", now + 0.05)
	selected.play()
	cooldowns[family] = now + float(parameters[1])
	return true

func set_world_paused(value: bool) -> void:
	if value == world_paused: return
	world_paused = value
	for player in world_players: player.stream_paused = value

func reset_world() -> void:
	for player in world_players:
		player.stop()
		player.stream_paused = false
		player.set_meta("reserved_until", -1.0)
	world_paused = false
	for key in cooldowns.keys():
		if not key in UI_KEYS: cooldowns.erase(key)

func _exit_tree() -> void:
	reset_world()
	for player in ui_players: player.stop()
	cache.clear()
