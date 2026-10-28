extends Node

const TRACKS := {
	"title": "res://assets/audio/bgm/title.ogg",
	"intro": "res://assets/audio/bgm/intro.ogg",
	"character_select": "res://assets/audio/bgm/character_select.ogg",
	"route": "res://assets/audio/bgm/route.ogg",
	"boss": "res://assets/audio/bgm/boss.ogg",
	"final_route": "res://assets/audio/bgm/final_route.ogg",
	"final_boss": "res://assets/audio/bgm/final_boss.ogg",
	"victory": "res://assets/audio/bgm/victory.ogg",
	"ending": "res://assets/audio/bgm/ending.ogg",
}
const FADE_SECONDS := 0.35
const LEVEL_DB := -5.0

var current_key := ""
var players: Array[AudioStreamPlayer] = []
var active := 0
var transition: Tween
var cache: Dictionary = {}
var suspended := false

func _ready() -> void:
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "BGM%d" % i
		player.bus = &"BGM"
		add_child(player)
		players.append(player)

static func cue_for(state: String, chapter: int, boss_started: bool, boss_done: bool) -> String:
	match state:
		"title": return "title"
		"character_select": return "character_select"
		"intro": return "intro"
		"ending": return "ending"
		"victory": return "ending" if chapter == 5 else "victory"
		"playing", "gameover":
			if boss_done and chapter <= 4: return "victory"
			if boss_started: return "final_boss" if chapter == 5 else "boss"
			return "final_route" if chapter == 5 else "route"
	return ""

func sync(state: String, chapter: int, boss_started: bool, boss_done: bool, paused: bool) -> void:
	play_cue(cue_for(state, chapter, boss_started, boss_done))
	if suspended != paused:
		suspended = paused
		for player in players: player.stream_paused = paused
		if transition and transition.is_valid():
			if paused: transition.pause()
			else: transition.play()

func play_cue(key: String) -> void:
	if key == current_key: return
	if not TRACKS.has(key):
		reset()
		return
	if not cache.has(key):
		var stream := load(TRACKS[key]) as AudioStreamOggVorbis
		if stream == null:
			push_error("Missing BGM: " + str(TRACKS[key]))
			return
		stream.loop = true
		stream.loop_offset = 0.0
		cache[key] = stream
	if transition and transition.is_valid(): transition.kill()
	var previous := players[active]
	active = 1 - active
	var next := players[active]
	next.stop()
	next.stream = cache[key]
	next.volume_linear = 0.0 if previous.playing else db_to_linear(LEVEL_DB)
	next.play()
	next.stream_paused = suspended
	current_key = key
	transition = create_tween().set_parallel(true)
	transition.tween_property(next, "volume_linear", db_to_linear(LEVEL_DB), FADE_SECONDS)
	transition.tween_property(previous, "volume_linear", 0.0, FADE_SECONDS)
	transition.chain().tween_callback(previous.stop)
	if suspended: transition.pause()

func reset() -> void:
	if transition and transition.is_valid(): transition.kill()
	transition = null
	for player in players:
		player.stop()
		player.stream_paused = false
	current_key = ""
	suspended = false

func _exit_tree() -> void:
	reset()
	cache.clear()
