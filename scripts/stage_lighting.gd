extends Node

const MANIFEST := "res://assets/lighting/manifest.json"
const LIT_STATES := ["playing", "victory", "gameover"]
const WORLD_LIGHT_MASK := 2

var stage: Node2D
var enabled := true
var active := false
var profile := "disabled"
var indoor_weight := 0.0
var canvas_layer: CanvasLayer
var world: Node2D
var ambient: CanvasModulate
var sun: DirectionalLight2D
var lamps: Array[PointLight2D] = []
var background_sprite: Sprite2D
var ground_details: Node2D
var actor_sprites: Array[Sprite2D] = []
var actor_count := 0
var manifest: Dictionary = {}
var textures: Dictionary = {}
var loaded_chapter := 0

func _ready() -> void:
	if FileAccess.file_exists(MANIFEST):
		var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if data is Dictionary: manifest = data.get("textures", {})
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "LitWorldCanvas"
	canvas_layer.layer = -1
	add_child(canvas_layer)
	world = Node2D.new()
	world.name = "LitWorld"
	canvas_layer.add_child(world)
	ambient = CanvasModulate.new()
	ambient.name = "SceneAmbient"
	world.add_child(ambient)
	background_sprite = Sprite2D.new()
	background_sprite.name = "LitScenery"
	background_sprite.centered = false
	background_sprite.region_enabled = true
	background_sprite.region_filter_clip_enabled = true
	background_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background_sprite.light_mask = WORLD_LIGHT_MASK
	world.add_child(background_sprite)
	ground_details = Node2D.new()
	ground_details.name = "GroundScorchMarks"
	ground_details.light_mask = WORLD_LIGHT_MASK
	world.add_child(ground_details)
	ground_details.draw.connect(_draw_ground_details)
	sun = DirectionalLight2D.new()
	sun.name = "DiagonalDaylight"
	sun.rotation_degrees = -38.0
	sun.height = 0.65
	sun.range_layer_min = -1
	sun.range_layer_max = -1
	sun.range_item_cull_mask = WORLD_LIGHT_MASK
	sun.shadow_enabled = false
	world.add_child(sun)
	var falloff := GradientTexture2D.new()
	falloff.width = 512
	falloff.height = 512
	falloff.fill = GradientTexture2D.FILL_RADIAL
	falloff.fill_from = Vector2(0.5, 0.5)
	falloff.fill_to = Vector2(0.5, 0.0)
	falloff.gradient = Gradient.new()
	falloff.gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
	falloff.gradient.colors = PackedColorArray([Color.WHITE, Color(0.86, 0.86, 0.86), Color(0.32, 0.32, 0.32), Color.BLACK])
	for index in range(3):
		var lamp := PointLight2D.new()
		lamp.name = "CeilingLight%d" % (index + 1)
		lamp.texture = falloff
		lamp.texture_scale = 4.4 if index < 2 else 3.8
		lamp.height = 260.0
		lamp.range_layer_min = -1
		lamp.range_layer_max = -1
		lamp.range_item_cull_mask = WORLD_LIGHT_MASK
		lamp.shadow_enabled = false
		world.add_child(lamp)
		lamps.append(lamp)
	canvas_layer.visible = false

func _draw_ground_details() -> void:
	if active: stage._draw_ground_details(ground_details, Vector2.ZERO)

func _mode() -> String:
	indoor_weight = 0.0
	if not enabled or stage.game_state not in LIT_STATES: return "disabled"
	if stage.stage_index == 5:

		if stage.elapsed >= float(stage.stage_spec.get("boss_time", 295.0)): return "disabled"
		var entry_start: float = stage.stage_spec.get("lighting_indoor_camera_start", 5800.0)
		var entry_end: float = stage.stage_spec.get("lighting_indoor_camera_end", 4900.0)
		indoor_weight = smoothstep(0.0, 1.0, clampf((entry_start - stage._camera_y()) / (entry_start - entry_end), 0.0, 1.0))
	elif stage.stage_index == 2:
		indoor_weight = 1.0
	if indoor_weight <= 0.001: return "directional"
	if indoor_weight >= 0.999: return "point"
	return "transition"

func begin_frame() -> void:
	actor_count = 0
	profile = _mode()
	active = profile != "disabled"
	canvas_layer.visible = active
	sun.enabled = active and indoor_weight < 0.999
	for lamp in lamps: lamp.enabled = active and indoor_weight > 0.001
	if not active: return
	if loaded_chapter != stage.stage_index:

		textures.clear()
		for sprite in actor_sprites: sprite.texture = null
		loaded_chapter = stage.stage_index
	var shake_offset: Vector2 = Vector2(sin(stage.visual_time * 97), cos(stage.visual_time * 113)) * stage.shake
	world.transform = stage.global_transform.translated_local(shake_offset)
	var outside := Color(0.70, 0.73, 0.79)
	var inside := Color(0.57, 0.55, 0.64)
	if stage.stage_index == 4: outside = Color(0.65, 0.70, 0.77)
	ambient.color = outside.lerp(inside, indoor_weight)
	sun.color = Color("fff0d6") if stage.stage_index != 4 else Color("dbeaff")
	sun.energy = 0.44 * (1.0 - indoor_weight)
	lamps[0].position = Vector2(240, 100)
	lamps[1].position = Vector2(760, 370)
	lamps[2].position = Vector2(300, 890)
	for index in range(lamps.size()):
		lamps[index].color = Color("ffe0af") if index < 2 else Color("b8caff")
		lamps[index].energy = (0.48 if index < 2 else 0.30) * indoor_weight
	var width: float = stage._background_display_width()
	if stage.background_map:
		background_sprite.visible = true
		background_sprite.texture = _texture(stage.background_map)
		background_sprite.position = Vector2((stage.W - width) * 0.5, 0)
		background_sprite.region_rect = Rect2(0, stage._camera_y(), stage.background_map.get_width(), stage.MAP_VIEW_SIZE)
		background_sprite.scale = Vector2(width / stage.background_map.get_width(), stage.H / stage.MAP_VIEW_SIZE)

		var shade := 0.24 if stage.boss_spawned else 0.06
		background_sprite.self_modulate = Color.WHITE.lerp(Color(0.02, 0.03, 0.055), shade)
	else:
		background_sprite.visible = false
	ground_details.queue_redraw()

func has_actor(texture: Texture2D) -> bool:
	return active and manifest.get(texture.resource_path, {}).get("kind", "") == "actor"

func _texture(diffuse: Texture2D) -> Texture2D:
	var path := diffuse.resource_path
	if textures.has(path): return textures[path]
	var spec: Dictionary = manifest.get(path, {})
	if spec.is_empty(): return diffuse
	var canvas := CanvasTexture.new()
	canvas.diffuse_texture = load(spec.diffuse) if spec.has("diffuse") else diffuse
	if ResourceLoader.exists(str(spec.get("normal", ""))): canvas.normal_texture = load(spec.normal)
	canvas.specular_color = Color(0, 0, 0, 1)
	textures[path] = canvas
	return canvas

func draw_actor(texture: Texture2D, region: Rect2, destination: Rect2, tint: Color) -> void:
	if actor_count == actor_sprites.size():
		var sprite := Sprite2D.new()
		sprite.name = "LitActor%d" % actor_count
		sprite.centered = false
		sprite.region_enabled = true
		sprite.region_filter_clip_enabled = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.light_mask = WORLD_LIGHT_MASK
		world.add_child(sprite)
		actor_sprites.append(sprite)
	var actor := actor_sprites[actor_count]
	actor.visible = true
	actor.texture = _texture(texture)
	actor.region_rect = region
	actor.position = destination.position
	actor.scale = destination.size / region.size
	actor.self_modulate = tint
	actor_count += 1

func end_frame() -> void:
	for index in range(actor_count, actor_sprites.size()): actor_sprites[index].visible = false
