extends Control

const GAME_SIZE := Vector2i(960, 960)
const ART_DIRECTORY := "res://assets/ui/side_panels/"
const Stage = preload("res://scripts/stage.gd")

var stage: Node2D
var game_viewport: SubViewport
var game_container: SubViewportContainer
var left_panel: TextureRect
var right_panel: TextureRect
var textures: Dictionary = {}
var hero_art := ""
var boss_art := ""
var game_rect := Rect2()

func _ready() -> void:

	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel = _make_panel("HeroArtwork")
	right_panel = _make_panel("BossArtwork")
	game_container = SubViewportContainer.new()
	game_container.name = "GameContainer"
	game_container.stretch = false
	game_container.mouse_filter = Control.MOUSE_FILTER_STOP
	game_container.size = Vector2(GAME_SIZE)
	add_child(game_container)
	game_viewport = SubViewport.new()
	game_viewport.name = "GameViewport"
	game_viewport.size = GAME_SIZE
	game_viewport.audio_listener_enable_2d = true
	game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game_container.add_child(game_viewport)
	stage = Stage.new()
	stage.name = "StageOne"
	game_viewport.add_child(stage)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_update_art()

func _make_panel(node_name: String) -> TextureRect:
	var panel := TextureRect.new()
	panel.name = node_name
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel

func _texture(filename: String) -> Texture2D:
	if not textures.has(filename):
		var path := ART_DIRECTORY + filename
		if ResourceLoader.exists(path): textures[filename] = load(path)
	return textures.get(filename)

func _update_art() -> void:
	var hero_name := "hero_%s_%02d.png" % ["full" if stage.stage_index >= 4 else "half", stage.character_index]
	var boss_name := "boss_%02d.png" % stage.stage_index
	if hero_name != hero_art:
		hero_art = hero_name
		left_panel.texture = _texture(hero_name)
	if boss_name != boss_art:
		boss_art = boss_name
		right_panel.texture = _texture(boss_name)

func _layout() -> void:
	if game_container == null: return
	var window_size := get_viewport_rect().size
	var side := minf(window_size.x, window_size.y)
	var origin := (window_size - Vector2.ONE * side) * 0.5
	game_rect = Rect2(origin, Vector2.ONE * side)
	game_container.position = origin
	game_container.scale = Vector2.ONE * side / float(GAME_SIZE.x)
	left_panel.position = Vector2.ZERO
	left_panel.size = Vector2(origin.x, window_size.y)
	right_panel.position = Vector2(origin.x + side, 0)
	right_panel.size = Vector2(origin.x, window_size.y)
	left_panel.visible = origin.x > 0
	right_panel.visible = origin.x > 0

func _process(_dt: float) -> void:
	if stage != null: _update_art()
