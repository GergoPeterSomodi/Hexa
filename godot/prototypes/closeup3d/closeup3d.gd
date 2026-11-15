## 3D test mockup of the strategy map around Genoa (Savona to Chiavari, the Giovi pass, the Apennines, some Po plain),
## for comparison with the 2D code-drawn close-up. Everything is built in code from one derived height file: the ground
## mesh, the sea, trees, towns, the harbour, roads, streams, the hex grid and the name plates. No imported assets.
##
## Run (from the repository root, with GODOT set; the height file is made by tools/worldmap/closeup_3d/extract_area.py):
##   "$GODOT" --path godot res://prototypes/closeup3d/closeup3d.tscn -- --heights=<absolute path of the json>
##   add --shots=<folder> to save the three views as PNG, print the frame times and quit;
##   --view=close, wide or low picks the first view; --cam=lon,lat,yaw,pitch,dist,fov,haze replaces the views with one.
## Keys: 1 close, 2 wide, 3 low; drag with the right mouse button to turn, wheel to zoom, WASD or arrows to move.
extends Node3D

const Land := preload("res://prototypes/closeup3d/closeup_land.gd")
const Parts := preload("res://prototypes/closeup3d/closeup_parts.gd")
const TERRAIN_SHADER := preload("res://prototypes/closeup3d/closeup_terrain.gdshader")
const WATER_SHADER := preload("res://prototypes/closeup3d/closeup_water.gdshader")
const TREE_SHADER := preload("res://prototypes/closeup3d/closeup_object.gdshader")

const HEX_W := 28.0
const BASE_Y := -1.6
const SHOT_SIZE := Vector2i(1280, 720)
const HOUSE_SIZE := 1.35
const TREE_SIZE := 1.1
const TREE_SPACING := 1.3

## The towns. port: 0 none, 1 a mole and a ship, 2 the great harbour. plate: 0 below the town, 1 above it.
const TOWNS: Array[Dictionary] = [
	{"name": "Genoa", "lon": 8.93, "lat": 44.41, "houses": 40, "radius": 7.0, "towers": 3, "church": true, "port": 2, "rank": 2, "plate": 1},
	{"name": "Savona", "lon": 8.48, "lat": 44.31, "houses": 10, "radius": 3.6, "towers": 1, "church": false, "port": 1, "rank": 1, "plate": 0},
	{"name": "Chiavari", "lon": 9.32, "lat": 44.32, "houses": 8, "radius": 3.3, "towers": 1, "church": false, "port": 1, "rank": 1, "plate": 0},
	{"name": "Serravalle", "lon": 8.86, "lat": 44.72, "houses": 6, "radius": 2.3, "towers": 1, "church": false, "port": 0, "rank": 0, "plate": 0},
	{"name": "Alessandria", "lon": 8.61, "lat": 44.91, "houses": 14, "radius": 3.6, "towers": 2, "church": true, "port": 0, "rank": 1, "plate": 0},
]
## Roads as [lon, lat] points: the Giovi road from Genoa to the plain, and the coast road.
const ROADS: Array[Array] = [
	[[8.93, 44.415], [8.905, 44.46], [8.90, 44.50], [8.935, 44.55], [8.955, 44.58], [8.95, 44.62], [8.90, 44.67], [8.86, 44.72],
		[8.80, 44.76], [8.72, 44.83], [8.61, 44.91], [8.60, 45.01]],
	[[8.48, 44.315], [8.58, 44.365], [8.68, 44.405], [8.76, 44.43], [8.85, 44.425], [8.93, 44.415], [9.03, 44.39], [9.14, 44.365],
		[9.23, 44.355], [9.32, 44.325]],
]
const PASS_LON := 8.94
const PASS_LAT := 44.55

## The views. yaw 0 looks north; pitch is the angle below the horizon; plates scales the name plates.
const VIEWS: Dictionary = {
	"close": {"lon": 8.90, "lat": 44.435, "yaw": 0.0, "pitch": 50.0, "dist": 90.0, "fov": 30.0, "plates": 1.0, "haze": 0.0008},
	"wide": {"lon": 8.90, "lat": 44.43, "yaw": 0.0, "pitch": 70.0, "dist": 265.0, "fov": 21.0, "plates": 0.62, "haze": 0.0004},
	"low": {"lon": 9.02, "lat": 44.47, "yaw": 60.0, "pitch": 9.0, "dist": 34.0, "fov": 48.0, "plates": 0.8, "haze": 0.002},
}

var _land: Land
var _rng := RandomNumberGenerator.new()
var _camera: Camera3D
var _plates: Array[Dictionary] = []
var _plate_layer: Control
var _plate_scale := 1.0
var _target := Vector3.ZERO
var _yaw := 0.0
var _pitch := 50.0
var _dist := 80.0
var _house_xf: Array[Transform3D] = []
var _house_col: Array[Color] = []
var _tower_xf: Array[Transform3D] = []
var _church_xf: Array[Transform3D] = []
var _ship_xf: Array[Transform3D] = []
var _stone := Parts.begin()
var _town_uniform: Array[Vector4] = []
var _material: StandardMaterial3D
var _env: Environment
var _views: Dictionary = VIEWS
var _sun: DirectionalLight3D


func _ready() -> void:
	var args := _arguments()
	var path := str(args.get("heights", OS.get_environment("HEXA_CLOSEUP_HEIGHTS")))
	_land = Land.new()
	var problem := "no height file given (--heights=PATH after -- , or HEXA_CLOSEUP_HEIGHTS)" if path == "" else _land.load_file(path)
	if problem != "":
		printerr("closeup3d: " + problem)
		get_tree().quit(1)
		return
	_rng.seed = 1480
	var started := Time.get_ticks_msec()
	_land.build_field()
	for t in TOWNS:
		var c := Land.world_of(float(t["lon"]), float(t["lat"]))
		_land.level_town(c, float(t["radius"]) * 0.85, 0.7)
	_material = _vertex_material(1.0)
	_build_light()
	_build_ground()
	_build_water()
	_build_roads_and_streams()
	_build_towns()
	_build_trees()
	_build_plates()
	_camera = Camera3D.new()
	_camera.near = 0.5
	_camera.far = 1500.0
	add_child(_camera)
	_camera.make_current()
	_use_view(str(args.get("view", "close")))
	print("closeup3d: built in %d ms; heights: %s" % [Time.get_ticks_msec() - started, _land.credit])
	if args.has("cam"):
		# A view of one's own for a shot: --cam=lon,lat,yaw,pitch,dist,fov,haze
		var n := str(args["cam"]).split_floats(",")
		if n.size() == 7:
			_views = {"custom": {"lon": n[0], "lat": n[1], "yaw": n[2], "pitch": n[3], "dist": n[4], "fov": n[5], "plates": 0.8, "haze": n[6]}}
			_use_view("custom")
	if args.has("shots"):
		_take_shots.call_deferred(str(args["shots"]))


func _arguments() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.trim_prefix("--").split("=", true, 1)
			out[parts[0]] = parts[1] if parts.size() > 1 else ""
	return out


# ----- light, sky, haze -------------------------------------------------------------------------------------------


func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	# From the left of the map and a little from the viewer's side, so the slopes and walls that face the usual
	# camera (which looks north) are lit and the shadows fall to the right.
	sun.look_at_from_position(Vector3(-1.0, 0.78, 0.3), Vector3.ZERO)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 420.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.6
	sun.shadow_opacity = 0.85
	add_child(sun)
	_sun = sun
	# A weak cool light from the other side, so the faces in shade keep their colour.
	var fill := DirectionalLight3D.new()
	fill.look_at_from_position(Vector3(1.0, 0.6, 0.2), Vector3.ZERO)
	fill.light_color = Color(0.72, 0.84, 1.0)
	fill.light_energy = 0.22
	fill.light_specular = 0.0
	add_child(fill)
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	get_viewport().msaa_3d = Viewport.MSAA_4X

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.36, 0.56, 0.84)
	sky_material.sky_horizon_color = Color(0.80, 0.87, 0.93)
	sky_material.ground_bottom_color = Color(0.62, 0.70, 0.78)
	sky_material.ground_horizon_color = Color(0.80, 0.87, 0.93)
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.80, 0.95)
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(0.80, 0.87, 0.93)
	env.fog_density = 0.0007
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_env = env
	add_child(world_env)


func _vertex_material(roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	m.metallic_specular = 0.2
	return m


# ----- ground and sea ---------------------------------------------------------------------------------------------


func _build_ground() -> void:
	var nx := _land.nx
	var nz := _land.nz
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.resize(nx * nz)
	normals.resize(nx * nz)
	var step := Land.STEP
	for j in nz:
		for i in nx:
			var k := j * nx + i
			verts[k] = Vector3(_land.x0 + float(i) * step, _land.field[k], _land.z0 + float(j) * step)
			var l := _land.field[j * nx + maxi(i - 1, 0)]
			var r := _land.field[j * nx + mini(i + 1, nx - 1)]
			var u := _land.field[maxi(j - 1, 0) * nx + i]
			var d := _land.field[mini(j + 1, nz - 1) * nx + i]
			normals[k] = Vector3(l - r, 2.0 * step, u - d).normalized()
	indices.resize((nx - 1) * (nz - 1) * 6)
	var w := 0
	for j in nz - 1:
		for i in nx - 1:
			var k := j * nx + i
			indices[w] = k
			indices[w + 1] = k + 1
			indices[w + 2] = k + nx + 1
			indices[w + 3] = k
			indices[w + 4] = k + nx + 1
			indices[w + 5] = k + nx
			w += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter("exaggeration", Land.EXAGGERATION)
	material.set_shader_parameter("grid_origin_km", Land.origin_km())
	material.set_shader_parameter("hex_w", HEX_W)
	for t in TOWNS:
		var c := Land.world_of(float(t["lon"]), float(t["lat"]))
		_town_uniform.append(Vector4(c.x, c.y, float(t["radius"]) * 0.8, 0.0))
	var padded := _town_uniform.duplicate()
	while padded.size() < 8:
		padded.append(Vector4.ZERO)
	material.set_shader_parameter("towns", padded)
	material.set_shader_parameter("town_count", _town_uniform.size())
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = mesh
	ground.material_override = material
	add_child(ground)

	# The board: sides down to a table, so the map reads as a model.
	var st := Parts.begin()
	var middle := Vector3(_land.x0 + _land.width() * 0.5, BASE_Y, _land.z0 + _land.depth() * 0.5)
	var earth := Color(0.33, 0.25, 0.19)
	var deep := Color(0.09, 0.20, 0.38)
	var ring: Array[Vector2i] = []
	for i in nx - 1:
		ring.append(Vector2i(i, 0))
	for j in nz - 1:
		ring.append(Vector2i(nx - 1, j))
	for i in range(nx - 1, 0, -1):
		ring.append(Vector2i(i, nz - 1))
	for j in range(nz - 1, 0, -1):
		ring.append(Vector2i(0, j))
	for k in ring.size():
		var a := verts[ring[k].y * nx + ring[k].x]
		var b := verts[ring[(k + 1) % ring.size()].y * nx + ring[(k + 1) % ring.size()].x]
		var sea := a.y < 0.0 and b.y < 0.0
		var ta := Vector3(a.x, maxf(a.y, 0.0), a.z)
		var tb := Vector3(b.x, maxf(b.y, 0.0), b.z)
		Parts.quad(st, ta, tb, Vector3(b.x, BASE_Y, b.z), Vector3(a.x, BASE_Y, a.z), deep if sea else earth, middle)
	var board := MeshInstance3D.new()
	board.name = "Board"
	board.mesh = st.commit()
	board.material_override = _material
	add_child(board)

	var table_mesh := PlaneMesh.new()
	table_mesh.size = Vector2(6000.0, 6000.0)
	var table_material := StandardMaterial3D.new()
	table_material.albedo_color = Color(0.24, 0.27, 0.33)
	table_material.roughness = 1.0
	var table := MeshInstance3D.new()
	table.name = "Table"
	table.mesh = table_mesh
	table.material_override = table_material
	table.position = Vector3(middle.x, BASE_Y, middle.z)
	table.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(table)


func _build_water() -> void:
	var nx := _land.nx
	var nz := _land.nz
	var image := Image.create(nx, nz, false, Image.FORMAT_RGH)
	for j in nz:
		for i in nx:
			image.set_pixel(i, j, Color(_land.field[j * nx + i], minf(_land.shore[j * nx + i], 60.0), 0.0))
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("field_tex", ImageTexture.create_from_image(image))
	material.set_shader_parameter("field_origin", Vector2(_land.x0, _land.z0))
	material.set_shader_parameter("field_step", Land.STEP)
	material.set_shader_parameter("field_size", Vector2(float(nx), float(nz)))
	material.set_shader_parameter("grid_origin_km", Land.origin_km())
	material.set_shader_parameter("hex_w", HEX_W)
	var plane := PlaneMesh.new()
	plane.size = Vector2(_land.width(), _land.depth())
	var water := MeshInstance3D.new()
	water.name = "Sea"
	water.mesh = plane
	water.material_override = material
	water.position = Vector3(_land.x0 + _land.width() * 0.5, 0.0, _land.z0 + _land.depth() * 0.5)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


# ----- roads and streams ------------------------------------------------------------------------------------------


func _build_roads_and_streams() -> void:
	var flat := _vertex_material(1.0)
	flat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wet := _vertex_material(0.25)
	wet.cull_mode = BaseMaterial3D.CULL_DISABLED
	wet.metallic_specular = 0.6
	for road in ROADS:
		var points := PackedVector2Array()
		for p: Array in road:
			points.append(_on_land(Land.world_of(float(p[0]), float(p[1]))))
		var path := Land.curve_through(points, 0.25)
		var widths := PackedFloat32Array()
		var heights := PackedFloat32Array()
		for k in path.size():
			var a := path[maxi(k - 1, 0)]
			var b := path[mini(k + 1, path.size() - 1)]
			var along := (b - a).normalized()
			var side := Vector2(-along.y, along.x) * 0.26
			widths.append(0.26)
			for s in 3:
				var q := path[k] + side * float(s - 1)
				heights.append(maxf(_land.height_at(q.x, q.y), 0.02) + 0.07)
		_land.mark_keep_off(path, 0.45)
		_add_mesh("Road", Parts.ribbon(path, widths, heights, Color(0.93, 0.84, 0.62), Color(0.78, 0.66, 0.44)), flat, false)

	for line in _land.streams:
		var smooth := Land.densify(Land.smooth(line, 2), 0.25)
		var path := PackedVector2Array()
		var widths := PackedFloat32Array()
		var heights := PackedFloat32Array()
		for k in smooth.size():
			var p := smooth[k]
			var y := _land.height_at(p.x, p.y)
			if y < -0.05 and k > 0:
				break
			path.append(Vector2(p.x, p.y))
			# Narrow at the head of the stream, wider with the area it drains.
			var grow := clampf(float(k) / 12.0, 0.25, 1.0)
			widths.append((0.16 + 0.011 * minf(sqrt(p.z), 45.0)) * grow)
			var level := maxf(y, 0.0) + 0.04
			for s in 3:
				heights.append(level)
		if path.size() < 2:
			continue
		_land.mark_keep_off(path, 0.4)
		_add_mesh("Stream", Parts.ribbon(path, widths, heights, Color(0.34, 0.62, 0.90), Color(0.24, 0.50, 0.82)), wet, false)


## A road point that fell into the sea of the 60 arc-second grid is moved to the nearest ground.
func _on_land(p: Vector2) -> Vector2:
	if _land.height_at(p.x, p.y) >= 0.1:
		return p
	for ring in range(1, 16):
		for k in 16:
			var q := p + Vector2.from_angle(TAU * float(k) / 16.0) * (0.5 * float(ring))
			if _land.height_at(q.x, q.y) >= 0.12:
				return q
	return p


func _add_mesh(mesh_name: String, mesh: Mesh, material: Material, shadows: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = mesh_name
	node.mesh = mesh
	node.material_override = material
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


# ----- towns ------------------------------------------------------------------------------------------------------


func _build_towns() -> void:
	for t in TOWNS:
		_build_town(t)
	_add_instances("Houses", Parts.house_mesh(), _house_xf, _house_col)
	_add_instances("Towers", Parts.tower_mesh(), _tower_xf, [])
	_add_instances("Churches", Parts.church_mesh(), _church_xf, [])
	_add_instances("Ships", Parts.ship_mesh(), _ship_xf, [])
	_add_mesh("Moles", _stone.commit(), _material, true)

	var pass_at := Land.world_of(PASS_LON, PASS_LAT) + Vector2(0.9, 0.0)
	var cairn := _add_mesh("Cairn", Parts.cairn_mesh(), _material, true)
	cairn.position = Vector3(pass_at.x, _land.height_at(pass_at.x, pass_at.y), pass_at.y)
	cairn.scale = Vector3.ONE * 1.1


func _build_town(t: Dictionary) -> void:
	var centre := _on_land(Land.world_of(float(t["lon"]), float(t["lat"])))
	var radius := float(t["radius"])
	var base_y := _land.height_at(centre.x, centre.y)
	var turn := _rng.randf_range(-0.3, 0.3)
	var taken: Array[Vector3] = []  # x, z, clearance

	if int(t["port"]) > 0:
		_build_port(centre, int(t["port"]), taken)

	var specials := int(t["towers"]) + (1 if bool(t["church"]) else 0)
	var wanted := specials + int(t["houses"])
	var tries := 0
	var placed := 0
	while placed < wanted and tries < wanted * 250:
		tries += 1
		var special := placed < specials
		var reach := radius * (0.45 if special else 1.0)
		var p := centre + Vector2.from_angle(_rng.randf() * TAU) * reach * pow(_rng.randf(), 0.75)
		var y := _land.height_at(p.x, p.y)
		if y < 0.07 or y > base_y + 2.6 or _land.normal_at(p.x, p.y).y < 0.55 or _land.is_keep_off(p.x, p.y):
			continue
		var is_church := special and bool(t["church"]) and placed == 0
		var size := HOUSE_SIZE * (0.9 if special else _rng.randf_range(0.85, 1.12))
		var clearance := size * (1.2 if is_church else 0.47)
		var free := true
		for other in taken:
			if Vector2(other.x - p.x, other.y - p.y).length() < clearance + other.z:
				free = false
				break
		if not free:
			continue
		taken.append(Vector3(p.x, p.y, clearance))
		placed += 1
		var quarter := float(_rng.randi_range(0, 1)) * PI * 0.5
		var basis := Basis(Vector3.UP, turn + quarter + _rng.randf_range(-0.12, 0.12)).scaled(Vector3.ONE * size)
		var xf := Transform3D(basis, Vector3(p.x, y, p.y))
		if is_church:
			_church_xf.append(xf)
		elif special:
			_tower_xf.append(xf)
		else:
			_house_xf.append(xf)
			var tints: Array[Color] = [Color(1, 1, 1), Color(1.0, 0.94, 0.84), Color(0.99, 0.88, 0.80), Color(1.0, 0.90, 0.72),
				Color(0.93, 0.93, 0.90)]
			_house_col.append(tints[_rng.randi_range(0, tints.size() - 1)])
	for other in taken:
		_land.mark_keep_off(PackedVector2Array([Vector2(other.x, other.y)]), other.z + 0.35)


## The harbour: finds the nearest sea, then lays moles out from the shore, the lighthouse and the ships.
func _build_port(centre: Vector2, kind: int, taken: Array[Vector3]) -> void:
	var best := 1.0e6
	var seaward := Vector2(0, 1)
	for k in 32:
		var dir := Vector2.from_angle(TAU * float(k) / 32.0)
		for s in range(1, 40):
			var q := centre + dir * (0.25 * float(s))
			if _land.height_at(q.x, q.y) < -0.02:
				if 0.25 * float(s) < best:
					best = 0.25 * float(s)
					seaward = dir
				break
	var shore := centre + seaward * (best - 0.3)
	var along := Vector2(-seaward.y, seaward.x)
	if kind == 2:
		_mole(shore - along * 2.6, seaward, 3.4)
		_mole(shore - along * 2.6 + seaward * 3.4, (along + seaward * 0.25).normalized(), 2.6)
		_mole(shore + along * 3.0, (seaward - along * 0.35).normalized(), 2.2)
		var at := shore - along * 3.6 - seaward * 0.2
		var light_xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.25), Vector3(at.x, maxf(_land.height_at(at.x, at.y), 0.05), at.y))
		_add_mesh("Lanterna", Parts.lighthouse_mesh(), _material, true).transform = light_xf
		var glow := StandardMaterial3D.new()
		glow.vertex_color_use_as_albedo = true
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_add_mesh("LanternaLight", Parts.lighthouse_light_mesh(), glow, false).transform = light_xf
		taken.append(Vector3(at.x, at.y, 1.0))
		_ship(shore + along * 0.3 + seaward * 2.0, 0.5)
		_ship(shore - along * 0.6 + seaward * 5.4, 2.6)
		_ship(shore + along * 5.5 + seaward * 4.0, -0.4)
	else:
		_mole(shore - along * 1.0, (seaward + along * 0.2).normalized(), 1.9)
		_ship(shore + along * 1.0 + seaward * 2.2, _rng.randf_range(-0.6, 0.6))


func _mole(from: Vector2, dir: Vector2, length: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, -dir.angle()), Vector3(from.x, 0.0, from.y))
	Parts.box(_stone, xf, Vector3(-0.5, -0.5, -0.22), Vector3(length, 0.17, 0.22), Parts.STONE_DARK, Parts.STONE)
	Parts.box(_stone, xf, Vector3(length - 0.3, -0.5, -0.32), Vector3(length + 0.3, 0.24, 0.32), Parts.STONE_DARK, Parts.STONE)


func _ship(at: Vector2, heading: float) -> void:
	if _land.height_at(at.x, at.y) > -0.03:
		return
	_ship_xf.append(Transform3D(Basis(Vector3.UP, heading).scaled(Vector3.ONE * 1.3), Vector3(at.x, 0.0, at.y)))


func _add_instances(node_name: String, mesh: Mesh, xfs: Array[Transform3D], colours: Array[Color]) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	add_child(node)
	if xfs.is_empty():
		return node
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colours.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for k in xfs.size():
		mm.set_instance_transform(k, xfs[k])
		if not colours.is_empty():
			mm.set_instance_color(k, colours[k])
	node.multimesh = mm
	node.material_override = _material
	return node


# ----- trees ------------------------------------------------------------------------------------------------------


func _build_trees() -> void:
	var patches := FastNoiseLite.new()
	patches.noise_type = FastNoiseLite.TYPE_SIMPLEX
	patches.seed = 7
	patches.frequency = 0.045
	var round_xf: Array[Transform3D] = []
	var round_col: Array[Color] = []
	var conifer_xf: Array[Transform3D] = []
	var conifer_col: Array[Color] = []
	var count_x := int(_land.width() / TREE_SPACING)
	var count_z := int(_land.depth() / TREE_SPACING)
	for j in count_z:
		for i in count_x:
			var x := _land.x0 + (float(i) + 0.5 + _rng.randf_range(-0.42, 0.42)) * TREE_SPACING
			var z := _land.z0 + (float(j) + 0.5 + _rng.randf_range(-0.42, 0.42)) * TREE_SPACING
			var roll := _rng.randf()
			var kind_roll := _rng.randf()
			var y := _land.height_at(x, z)
			if y < 0.08 or _land.is_keep_off(x, z):
				continue
			var metres := y / Land.EXAGGERATION * 1000.0
			var slope := 1.0 - _land.normal_at(x, z).y
			var patch := patches.get_noise_2d(x, z) * 0.5 + 0.5
			var chance := 0.0
			if slope > 0.42:
				chance = 0.0
			elif metres < 220.0 and slope < 0.03:
				chance = 0.07 + (0.5 if patch > 0.66 else 0.0)
			elif metres > 1450.0:
				chance = 0.25
			else:
				chance = clampf(0.15 + 1.1 * patch - slope * 0.6, 0.12, 0.92)
			if roll > chance:
				continue
			var size := TREE_SIZE * _rng.randf_range(0.8, 1.2)
			var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size, size * _rng.randf_range(0.9, 1.15), size)),
				Vector3(x, y, z))
			var light := _rng.randf_range(0.84, 1.08)
			var tint := Color(light * _rng.randf_range(0.92, 1.05), light, light * _rng.randf_range(0.85, 1.0))
			if metres + (patch - 0.5) * 500.0 > 820.0 or kind_roll < 0.08:
				conifer_xf.append(xf)
				conifer_col.append(tint)
			else:
				round_xf.append(xf)
				round_col.append(tint)
	var tree_material := ShaderMaterial.new()
	tree_material.shader = TREE_SHADER
	tree_material.set_shader_parameter("grid_origin_km", Land.origin_km())
	tree_material.set_shader_parameter("hex_w", HEX_W)
	_add_instances("RoundTrees", Parts.round_tree_mesh(), round_xf, round_col).material_override = tree_material
	_add_instances("Conifers", Parts.conifer_mesh(), conifer_xf, conifer_col).material_override = tree_material
	print("closeup3d: %d round trees, %d conifers, %d houses" % [round_xf.size(), conifer_xf.size(), _house_xf.size()])


# ----- name plates ------------------------------------------------------------------------------------------------


func _build_plates() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_plate_layer = Control.new()
	_plate_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_plate_layer)
	for t in TOWNS:
		var c := _on_land(Land.world_of(float(t["lon"]), float(t["lat"])))
		var above := int(t["plate"]) == 1
		var anchor := Vector3(c.x, _land.height_at(c.x, c.y), c.y) + (Vector3(0, 3.5, -4.0) if above else Vector3(0, 0, 3.6))
		_add_plate(str(t["name"]), anchor, int(t["rank"]), above)
	var pass_at := Land.world_of(PASS_LON, PASS_LAT)
	_add_plate("Giovi", Vector3(pass_at.x + 3.6, _land.height_at(pass_at.x, pass_at.y) + 1.6, pass_at.y), -1, true)


## rank 2 the great city, 1 a city, 0 a town, -1 a pass (italic, no plate).
func _add_plate(text: String, anchor: Vector3, rank: int, above: bool) -> void:
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	var label := Label.new()
	label.text = text
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_color = Color(0.98, 0.95, 0.88)
	label.label_settings = settings
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	if rank < 0:
		font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.22, 1.0), Vector2.ZERO)
		font.variation_embolden = 0.3
		settings.outline_color = Color(0.13, 0.15, 0.20, 0.9)
		style.bg_color = Color(0, 0, 0, 0)
	else:
		font.variation_embolden = 0.75
		style.bg_color = Color(0.12, 0.14, 0.21, 0.94)
		style.border_color = Color(1, 1, 1, 0.10)
		style.set_border_width_all(1)
		style.shadow_color = Color(0, 0, 0, 0.25)
		style.shadow_offset = Vector2(0, 2)
	box.add_theme_stylebox_override("panel", style)
	box.add_child(label)
	_plate_layer.add_child(box)
	_plates.append({"box": box, "style": style, "settings": settings, "anchor": anchor, "rank": rank, "above": above})


func _lay_out_plates() -> void:
	var screen := get_viewport().get_visible_rect()
	var shown: Array[Rect2] = []
	# The great city is laid first, so on a clash the lesser name gives way.
	var order := _plates.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["rank"]) > int(b["rank"]))
	for plate: Dictionary in order:
		var box: PanelContainer = plate["box"]
		var style: StyleBoxFlat = plate["style"]
		var settings: LabelSettings = plate["settings"]
		var anchor: Vector3 = plate["anchor"]
		var rank: int = plate["rank"]
		var sizes: Array[float] = [34.0, 26.0, 40.0, 58.0]
		var size := maxf(sizes[rank + 1] * _plate_scale, 12.0)
		settings.font_size = int(round(size))
		if rank < 0:
			settings.outline_size = int(round(size * 0.22))
		else:
			style.set_corner_radius_all(int(round(size * 0.55)))
			style.shadow_size = int(round(size * 0.12))
		var pad := 0.0 if rank < 0 else size
		style.content_margin_left = pad * 0.5
		style.content_margin_right = pad * 0.5
		style.content_margin_top = pad * 0.10
		style.content_margin_bottom = pad * 0.16
		box.reset_size()
		var at := _camera.unproject_position(anchor)
		var above: bool = plate["above"]
		var corner := at - Vector2(box.size.x * 0.5, box.size.y if above else 0.0)
		var room := screen.size - box.size - Vector2(10, 10)
		box.position = corner.clamp(Vector2(10, 10), room).round()
		var rect := Rect2(box.position, box.size)
		var seen := not _camera.is_position_behind(anchor) and screen.grow(60.0).has_point(at) and not _is_hidden(anchor)
		for other in shown:
			if other.grow(4.0).intersects(rect):
				seen = false
		box.visible = seen
		if seen:
			shown.append(rect)


## True when the ground stands between the camera and the point (a plate behind a mountain is not shown).
func _is_hidden(anchor: Vector3) -> bool:
	var eye := _camera.global_position
	for k in range(1, 96):
		var p := eye.lerp(anchor, float(k) / 96.0)
		if _land.inside(p.x, p.z) and _land.height_at(p.x, p.z) > p.y + 0.25:
			return true
	return false


# ----- views, input, shots ----------------------------------------------------------------------------------------


func _use_view(view_name: String) -> void:
	var v: Dictionary = _views.get(view_name, VIEWS["close"])
	var c := Land.world_of(float(v["lon"]), float(v["lat"]))
	_target = Vector3(c.x, 0.0, c.y)
	_yaw = float(v["yaw"])
	_pitch = float(v["pitch"])
	_dist = float(v["dist"])
	_camera.fov = float(v["fov"])
	_plate_scale = float(v["plates"])
	_env.fog_density = float(v["haze"])
	_place_camera()


func _place_camera() -> void:
	var pitch := deg_to_rad(_pitch)
	var yaw := deg_to_rad(_yaw)
	var back := Vector3(-sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var at := _target + back * _dist
	at.y = maxf(at.y, _land.height_at(at.x, at.z) + 1.0)
	_camera.look_at_from_position(at, _target)
	_fit_shadows()


## The shadow map only has to reach the farthest ground in view. Seen from above that is one tight sheet (one split
## gives it the whole map); a low camera sees far, so it takes four splits.
func _fit_shadows() -> void:
	var below := deg_to_rad(_pitch - _camera.fov * 0.5)
	var height := _camera.global_position.y
	if _pitch > 35.0:
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		_sun.directional_shadow_max_distance = height / sin(below) * 1.08
	else:
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		_sun.directional_shadow_max_distance = clampf(height / sin(maxf(below, 0.05)), 60.0, 170.0)


func _process(delta: float) -> void:
	if _camera == null:
		return
	var move := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0
	if Input.is_key_pressed(KEY_W):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		move.y += 1.0
	if move != Vector2.ZERO:
		var turned := move.rotated(-deg_to_rad(_yaw)) * _dist * 0.6 * delta
		_target += Vector3(turned.x, 0.0, turned.y)
		_place_camera()
	_lay_out_plates()


func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_1:
					_use_view("close")
				KEY_2:
					_use_view("wide")
				KEY_3:
					_use_view("low")
				KEY_ESCAPE:
					get_tree().quit()
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_yaw -= motion.relative.x * 0.25
			_pitch = clampf(_pitch + motion.relative.y * 0.2, 6.0, 88.0)
			_place_camera()
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, 8.0)
			_place_camera()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.1, 400.0)
			_place_camera()


func _take_shots(folder: String) -> void:
	get_window().size = SHOT_SIZE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var viewport_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	DirAccess.make_dir_recursive_absolute(folder)
	for view_name: String in _views:
		_use_view(view_name)
		for _n in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if image.get_size() != SHOT_SIZE:
			image.resize(SHOT_SIZE.x, SHOT_SIZE.y, Image.INTERPOLATE_LANCZOS)
		image.save_png(folder.path_join("3d_genoa_%s.png" % view_name))
		var frames := 200
		var cpu := 0.0
		var gpu := 0.0
		var started := Time.get_ticks_usec()
		for _n in frames:
			await get_tree().process_frame
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu()
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
		var per_frame := float(Time.get_ticks_usec() - started) / 1000.0 / float(frames)
		print("closeup3d: view %s: %.2f ms per frame unthrottled (%.0f fps), render cpu %.2f ms, gpu %.2f ms, %d draw calls, %d triangles" % [
			view_name, per_frame, 1000.0 / per_frame, cpu / float(frames), gpu / float(frames),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	print("closeup3d: renderer %s on %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	get_tree().quit()
